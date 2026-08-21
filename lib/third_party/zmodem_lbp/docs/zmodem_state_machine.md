# ZModem Protocol State Machine

This document describes the two-layer state machine used in `zmodem_lbp`.

- **Layer 1: `ZModemParser`** — Parse state machine. Consumes raw bytes, yields `ZFrame` objects.
- **Layer 2: `ZModemCore`** — Session state machine. Consumes `ZFrame` objects, yields `ZModemEvent` objects.

---

## Layer 1: Parser State Machine

Source: `lib/src/zmodem_parser.dart`

### States

| State | Description |
|-------|-------------|
| `_ParseState.expectHeader` | Looking for ZPAD+ZPAD+ZDLE+ZHEX (hex header) or ZPAD+ZDLE+ZBIN (binary header) |
| `_ParseState.expectData` | After ZFILE/ZSINIT/ZDATA header — reading data subpacket bytes until ZCRCE/ZCRCG/ZCRCQ/ZCRCW terminator |

### State Transition Diagram

```
                    ┌──────────────────────────────────────┐
                    │                                      │
                    ▼                                      │
    ┌──────────────┐          hex/bin header          ┌────┴───────────┐
    │              │ ──────────────────────────────►  │                │
    │ expectHeader │  (ZFILE/ZSINIT/ZDATA only ◄───) │  expectData    │
    │              │ ◄──────────────────────────────  │                │
    └──────────────┘   ZCRCE or ZCRCW terminator      └────────────────┘
           ▲
           │
           │  Other headers (ZRINIT, ZRQINIT, ZFIN, etc.)
           └──────────── return to expectHeader ────────────────────────
```

### Transition Triggers

| Current State | Input | Next State | Action |
|---------------|-------|------------|--------|
| expectHeader | `ZPAD ZPAD ZDLE ZHEX` + hex header + CRC + `CR LF` | depends on header type | Parse hex header, yield `ZFrame(hexHeader)` |
| expectHeader | `ZPAD ZDLE ZBIN` + binary bytes + CRC | depends on header type | Parse binary header, yield `ZFrame(binaryHeader)` |
| expectHeader | byte ≠ ZPAD (dirty char) | expectHeader | Route to `onPlainText` callback or count CAN bytes |
| expectHeader | ZFILE/ZSINIT/ZDATA parsed | **expectData** | Frame introduces a data subpacket |
| expectHeader | Other header parsed | expectHeader | No data expected |
| expectData | Escaped data bytes | expectData | Accumulate in data buffer |
| expectData | ZCRCE/ZCRCG/ZCRCQ/ZCRCW terminator | expectData | Compute CRC, yield `ZFrame(dataSubpacket)` |
| expectData | ZCRCE/ZCRCW terminator | **expectHeader** | End of subpacket chain (next frame expected) |
| expectData | ZCRCG/ZCRCQ terminator | expectData | More subpackets to follow |

### Cancel Detection

Any state: 5 consecutive CAN bytes → clear buffer, fire `onCancel`, reset to expectHeader.

### Fragment Safety

- Parser uses a `ChunkBuffer` that can accept data incrementally (`addData`).
- `moveNext()` is a generator — yields `null` when more data is needed, `ZFrame` when complete.
- Data subpackets have a `_maxDataSubpacketSize` of 64 KB. Exceeding throws `StateError`.

---

## Layer 2: Core State Machine

Source: `lib/core.dart`

### States

| State | Type | Description | Timeout |
|-------|------|-------------|---------|
| `init` | Idle | No session active | None |
| `rqInit` | Wait | Sent ZRQINIT, waiting for ZRINIT | None |
| `rInit` | Wait | Sent/received ZRINIT, waiting for ZSINIT or ZFILE | None |
| `sInit` | Wait | Received ZSINIT, waiting for attn subpacket | None |
| `receivedFileProposal` | Data | ZFILE header received, waiting for file info subpacket | None |
| `waitingContent` | Block | Accepted file, waiting for ZDATA header | **30s** |
| `receivingContent` | Active | Receiving file data subpackets | **30s** |
| `readyToSend` | Idle | Core ready to send a file | None |
| `sentFileProposal` | Wait | ZFILE + file info sent, waiting for ZRPOS/ZSKIP | None |
| `sendingContent` | Active | Sending file data subpackets | **60s** |
| `closed` | Terminal | Sent ZFIN, waiting for complete close | **10s** |
| `fin` | Terminal | Session fully closed | None |

### State Transition Matrix

The core handles frames via `_handleFrame(ZFrame)` which uses a `switch` on `(_state, frame.type)`:

#### From `init` (Idle, waiting for remote to initiate)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZRINIT` (0x01) | `readyToSend` | `ZReadyToSendEvent` | — |
| `ZRQINIT` (0x00) | `rInit` | — | Enqueue ZRINIT |

#### From `rqInit` (Sent ZRQINIT)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZRINIT` (0x01) | `readyToSend` | `ZReadyToSendEvent` | — |

#### From `rInit` (Received ZRINIT)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZSINIT` (0x02) | `sInit` | — | Enqueue ZACK |
| `ZFILE` (0x04) | `receivedFileProposal` | — | Wait for file info subpacket |
| `ZFIN` (0x08) | `fin` | `ZSessionFinishedEvent` | Enqueue ZFIN |

#### From `sInit` (Received ZSINIT)

| Frame Type | Format | New State | Events Yielded | Action |
|------------|--------|-----------|----------------|--------|
| Any data subpacket (attn) | dataSubpacket | `rInit` | — | Extract attn sequence |

#### From `receivedFileProposal` (ZFILE processed)

| Frame Type | Format | New State | Events Yielded | Action |
|------------|--------|-----------|----------------|--------|
| File info subpacket | dataSubpacket | `receivedFileProposal` | `ZFileOfferedEvent` | Parse file info |

#### From `waitingContent` (Accepted file)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZDATA` (0x0a) | `receivingContent` | — | — |

**Timeout: 30s** → ZTimeoutEvent + enqueue ZFIN + transition to `closed`

#### From `receivingContent` (Receiving file data)

| Frame Type | Format | New State | Events Yielded | Action |
|------------|--------|-----------|----------------|--------|
| `ZEOF` (0x0b) | any | `rInit` | `ZFileEndEvent` | Enqueue ZRINIT |
| Any data subpacket | dataSubpacket | `receivingContent` | `ZFileDataEvent` | Yield data |

**Timeout: 30s** → ZTimeoutEvent + enqueue ZFIN + transition to `closed`

#### From `readyToSend` (Ready to offer a file)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZRINIT` (0x01) | `readyToSend` | — | Ignore duplicate |

#### From `sentFileProposal` (Offered a file)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZRINIT` (0x01) | `sentFileProposal` | — | Ignore duplicate |
| `ZRPOS` (0x09, with offset) | **sendingContent** | `ZFileAcceptedEvent` offset | Enqueue ZDATA(offset) |
| `ZSKIP` (0x05) | `readyToSend` | `ZFileSkippedEvent` | — |

#### From `sendingContent` (Sending file data)

| Frame Type | New State | Events Yielded | Action |
|------------|-----------|----------------|--------|
| `ZRPOS` (0x09, with offset) | `sendingContent` | `ZFileAcceptedEvent` offset | (reposition / resend) |
| `ZSKIP` (0x05) | `readyToSend` | `ZFileSkippedEvent` | — |

**Timeout: 60s** → ZTimeoutEvent + enqueue ZFIN + transition to `closed`

#### From any state

| Frame Type | Format | New State | Events Yielded | Action |
|------------|--------|-----------|----------------|--------|
| `ZFIN` (0x08) | hexHeader or binaryHeader | `fin` | `ZSessionFinishedEvent` | Enqueue ZFIN |

### Undefined Transitions

Any `(state, frame_type)` pair not listed above → frame is silently ignored (returns `null`).
Undefined transitions are **traps for bugs** — they may indicate protocol violations.

### Cancel Handling

Any state: `onCancel` callback fires (from parser detecting 5 CAN bytes) → state reset to `init`, `_cancelled = true`. Next call to `receive()` yields `ZSessionCancelledEvent`.

### CRC Error Handling

When `frame.crcValid == false` and frame is a `dataSubpacket`:
→ `ZCrcErrorEvent` is yielded instead of the normal event.
→ Core still processes the frame's type for state transitions.

---

## Data Flow

```
Raw Bytes ──► ZModemParser ──► ZFrame ──► ZModemCore ──► ZModemEvent
                   │                          │
            onPlainText                  onTrace
            onCancel                     dataToSend / hasDataToSend
                                          checkTimeout
```

- `ZModemCore.receive(Uint8List)` → calls `parser.addData()` → iterates `parser` → calls `_handleFrame()` → yields events.
- `ZModemCore.dataToSend()` → drains send queue, encodes packets to bytes.
- `ZModemCore.checkTimeout()` → checks if current blocking state has exceeded its duration.

---

## File Transfer Lifecycle (Receive)

```
Sender                      Receiver
  │                           │
  │──── ZRQINIT ────────────► │
  │◄──── ZRINIT ─────────────│
  │──── ZSINIT + attn ──────►│
  │◄──── ZACK ───────────────│
  │──── ZFILE + file info ──►│──► ZFileOfferedEvent
  │◄──── ZRPOS(0) ───────────│── call acceptFile(0)
  │──── ZDATA(0) ───────────►│
  │──── subpackets ─────────►│──► ZFileDataEvent
  │──── ZCRCE + ZEOF ───────►│──► ZFileEndEvent
  │◄──── ZRINIT ─────────────│
```

## File Transfer Lifecycle (Send)

```
Receiver                      Sender
  │                           │
  │◄──── ZRINIT ─────────────│
  │──── ZRQINIT ────────────►│── call initiateSend()
  │◄──── ZRINIT ─────────────│──► ZReadyToSendEvent
  │                           │── call offerFile(info)
  │──── ZRPOS(0) ◄───────────│──► ZFileAcceptedEvent
  │                           │── call sendFileData(data)
  │──── ZRPOS(n) ◄───────────│──► ZFileAcceptedEvent (reposition)
  │◄──── ZSKIP ──────────────│──► ZFileSkippedEvent
```

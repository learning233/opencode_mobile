# ZMODEM State Machine Audit

> Date: 2026-05-15
> Scope: ZModemCore + ZModemParser + ZModemMux + EscapeParser
> Method: static analysis, no code modification

---

## 1. Architecture Overview

三层状态机：

```
Parser (zmodem_parser.dart)  →  Core (core.dart)  →  Mux (lib/zmodem.dart)
       字节级                      协议级                     应用级
```

---

## 2. Parser State Machine (Implicit)

No enum. Uses `sync*` generator yield positions + one boolean flag `_expectDataSubpacket`.

### States

| State | Entry Condition | Handler |
|-------|----------------|---------|
| `DRAIN` | buffer first byte != ZPAD | `_handleDirtyChar()` |
| `WAITING_PREAMBLE` | buffer >= 4 bytes | match ZPAD ZPAD ZDLE ZHEX or ZPAD ZDLE ZBIN |
| `HEX_HEADER` | matched ZPAD ZPAD ZDLE ZHEX | `_parseHexHeader()` |
| `BINARY_HEADER` | matched ZPAD ZDLE ZBIN | `_parseBinaryPacket()` |
| `DATA` | `_expectDataSubpacket == true` | `_parseDataSubpacket()` |
| `CANCELLED` | 5 consecutive CAN bytes | `_handleCancel()` → back to DRAIN |

### Transitions

```
DRAIN ──(XON)──→ DRAIN (silent discard)
DRAIN ──(CAN×5)──→ CANCELLED
DRAIN ──(other)──→ DRAIN (onPlainText)
WAITING_PREAMBLE ──(ZPAD ZPAD ZDLE ZHEX)──→ HEX_HEADER
WAITING_PREAMBLE ──(ZPAD ZDLE ZBIN)──→ BINARY_HEADER
WAITING_PREAMBLE ──(no match)──→ DRAIN (1 byte consumed)
HEX_HEADER ──(done)──→ WAITING_PREAMBLE
BINARY_HEADER ──(done)──→ WAITING_PREAMBLE
DATA ──(ZCRCE/ZCRCG/ZCRCQ/ZCRCW)──→ WAITING_PREAMBLE
CANCELLED ──(buffer cleared)──→ DRAIN
```

### DATA Mode Flag Lifecycle

```
_expectDataSubpacket  set by core._expectDataSubpacket()
Consumed at top of _createParser() while(true):

  if (_expectDataSubpacket) {
    _expectDataSubpacket = false;   // consumed
    yield* _parseDataSubpacket();
    continue;
  }

Timeline:
  moveNext() → parser yields data packet → returns true
  → core.receive() dispatches event
  → state handler may call core._expectDataSubpacket()   [set flag]
  → next moveNext() → parser consumes flag → enters DATA
```

Single-flag design (no queue). Two calls before consumption = second lost.

---

## 3. Core State Machine (12 States)

```
_ZInitState (initial)
    │
    ├── ZRINIT from remote → _ZReadyToSendState
    ├── ZRQINIT from remote → _ZRinitState
    ├── initiateSend()     → _ZRqinitState
    ├── initiateReceive()   → _ZRinitState
    └── ZFIN (via base)    → _ZFinState

_ZRqinitState (send requested, waiting for ZRINIT)
    │
    ├── ZRINIT → _ZReadyToSendState
    └── ZFIN   → _ZFinState

_ZRinitState (receive ready / waiting for file)
    │
    ├── ZSINIT → _ZSinitState + expectData
    ├── ZFILE  → _ZReceivedFileProposalState + expectData
    ├── ZFIN   → _ZFinState
    └── else   → ZModemException

_ZSinitState (waiting for attn sequence data)
    │
    └── data subpacket → _ZRinitState

_ZReceivedFileProposalState (got file info, awaiting decision)
    │
    ├── data subpacket  → stays, yield ZFileOfferedEvent
    ├── acceptFile()    → _ZWaitingContentState
    ├── skipFile()      → _ZRinitState
    └── ZFIN (via base) → _ZFinState

_ZWaitingContentState (accepted, waiting for ZDATA)
    │
    ├── ZDATA          → _ZReceivingContentState + expectData
    └── ZFIN (via base)→ _ZFinState

_ZReceivingContentState (receiving file data)
    │
    ├── data subpacket (ZCRCG/ZCRCQ) → stays + expectData
    ├── data subpacket (ZCRCE/ZCRCW) → stays (last)
    ├── ZEOF           → _ZRinitState + ZFileEndEvent
    └── ZFIN (via base)→ _ZFinState

_ZReadyToSendState (remote ready, waiting for user offerFile())
    │
    ├── ZRINIT (retry) → stays (ignored)
    ├── offerFile()    → ZSentFileProposalState
    └── ZFIN (via base)→ _ZFinState

ZSentFileProposalState (file offered, awaiting response)
    │
    ├── ZRPOS          → _ZSendingContentState + ZFileAcceptedEvent
    ├── ZSKIP          → _ZReadyToSendState + ZFileSkippedEvent
    ├── ZRINIT (retry) → stays (ignored)
    └── ZFIN (via base)→ _ZFinState

_ZSendingContentState (sending file data)
    │
    ├── ZRPOS           → _ZReadyToSendState (retransmit)
    ├── ZSKIP           → _ZReadyToSendState (skip)
    ├── finishSending() → _ZRqinitState
    └── ZFIN (via base) → _ZFinState

_ZClosedState (ZFIN sent, waiting for ack)
    │
    └── ZFIN → _ZFinState + enqueue OO

_ZFinState (terminal)
    │
    └── ANY → stays (silently ignored)
```

---

## 4. Mux Implicit States (lib/zmodem.dart)

```
terminal mode ──(detect ZMODEM init seq)──→ zmodem mode
zmodem mode  ──(ZSessionFinishedEvent)──→ terminal mode

Sub-states tracked by:
  _session        = null | ZModemCore
  _fileOffers     = null | Iterator<ZModemOffer>
  _receiveSink    = null | StreamController<Uint8List>
```

---

## 5. Findings

### 5.1 Unreachable States

**None.** All 12 states reachable from `_ZInitState`.

### 5.2 Stuck States

| ID | State | Trigger | Category |
|----|-------|---------|----------|
| S1 | `_ZSinitState` | ZSINIT header received, attn data subpacket never arrives | **Protocol — Confirmed Risk** |
| S2 | `_ZReceivedFileProposalState` | `acceptFile()`/`skipFile()` never called | API (user-controlled) |
| S3 | `_ZWaitingContentState` | ZDATA never arrives | **Protocol — Confirmed Risk** |
| S4 | `_ZReceivingContentState` | ZEOF never arrives | **Protocol — Confirmed Risk** |
| S5 | `_ZReadyToSendState` | `offerFile()` never called | API (user-controlled) |
| S6 | `_ZSendingContentState` | `finishSending()` never called | API (user-controlled) |
| S7 | `_ZClosedState` | Remote never responds with ZFIN | **Protocol — Confirmed Risk** |

S1/S3/S4/S7: **No timeout mechanism.** Remote disconnection → permanent hang.

### 5.3 Illegal Transitions

| ID | Path | Analysis | Verdict |
|----|------|----------|---------|
| **T1** | `DATA` mode + header frame arrives | `_expectDataSubpacket=true` → parser absorbs header bytes as data. Header never reaches state machine. See 5.3.1 for repro. | **Confirmed Bug** |
| T2 | `_ZSendingContentState`→`_ZRqinitState` via `finishSending()` | Skips `_ZReadyToSendState`. But this is normal multi-file ZMODEM path. | Normal |
| T3 | `_ZReceivingContentState`→`_ZRinitState` via ZEOF | Next ZFILE handled correctly by `_ZRinitState`. | Normal |
| **T4** | ZSINIT header then ZFILE instead of attn data | Parser in DATA mode, ZFILE header consumed as data bytes. ZFILE event never fires. | **Confirmed Bug** (same root cause as T1) |

#### 5.3.1 T1 Minimal Reproduction

```
Setup: _ZReceivingContentState, _expectDataSubpacket = true
Remote sends ZEOF hex header:

  0x2A 0x2A 0x18 0x42   // ZPAD ZPAD ZDLE ZHEX
  0x30 0x42 ...          // "0B..." ZEOF type=0x0B hex-encoded

Parser in DATA mode, readEscaped() decodes:
  0x2A         → data byte (not ZDLE)
  0x2A         → data byte
  0x18 0x42    → ZDLE then 0x42: default case → 0x42 ^ 0x40 = 0x02
  ...remaining hex ASCII chars consumed as raw data bytes

Result: ZEOF header silently absorbed as data. State machine never sees ZEOF.
Protocol deadlock: _ZReceivingContentState waits for ZEOF forever.
```

### 5.4 CRC / Offset Issues

| ID | Location | Description | Verdict |
|----|----------|-------------|---------|
| **C1** | `_parseHexHeader()`:154-155 | 2 CRC bytes read, silently discarded | **Confirmed Bug** |
| **C2** | `_parseBinaryPacket()`:197-201 | 2 CRC bytes read, silently discarded | **Confirmed Bug** |
| **C3** | `_parseDataSubpacket()`:222-226 | 2 CRC bytes read, silently discarded | **Confirmed Bug** |
| C4 | `zmodem_frame.dart` encode | Sender calculates CRC (3 locations); receiver never validates | Summary of C1-C3 |
| C5 | `ZSentFileProposalState`:363-366 | ZRPOS offset uses 32-bit LE; overflows at 4GB | Theoretical |

#### 5.4.1 C1 Minimal Reproduction

```dart
// Bad CRC ZRQINIT hex header — should be rejected, accepted silently
const badCrcZRQINIT = [
  0x2A, 0x2A, 0x18, 0x42,           // ZPAD ZPAD ZDLE ZHEX
  0x30, 0x30, 0x30, 0x30,           // "0000" type=0x00
  0x30, 0x30, 0x30, 0x30,           // "0000" p0
  0x30, 0x30, 0x30, 0x30,           // "0000" p1
  0x30, 0x30, 0x30, 0x30,           // "0000" p2
  0x30, 0x30, 0x30, 0x30,           // "0000" p3
  0x46, 0x46, 0x46, 0x46,           // "FFFF" CRC (expected: 0x0000)
  0x0D, 0x0A, 0x11,                 // CR LF XON
];

// Expected: ZModemException (CRC mismatch)
// Actual:   ZModemHeader(0, 0, 0, 0, 0) // silently created with wrong CRC
```

### 5.5 Mux Layer Issues

| ID | Location | Description | Verdict |
|----|----------|-------------|---------|
| **M1** | `lib/zmodem.dart`:141 | `_handleZModem` is `async void`; exceptions from `await` become unhandled | **Confirmed Bug** |
| **M2** | `lib/zmodem.dart`:78-79,266-270 | pause/resume commented out; no backpressure → ChunkBuffer grows unbounded | **Confirmed Bug** |
| **M3** | `zmodem_parser.dart`:207 | `BytesBuilder()` in `_parseDataSubpacket` has no size limit | Confirmed Risk |
| **M4** | `lib/zmodem.dart`:121-136 | ZMODEM init seq `**\x18B0{6}` may appear in terminal output → false positive | Theoretical |
| **M5** | `lib/zmodem.dart`:199-201 | `onFileRequest` returns null → `_fileOffers` stays null → no ZFIN sent → session stays open | **Confirmed Risk** |

#### 5.5.1 M5 Minimal Reproduction

```
1. Remote sends ZRQINIT → _ZInitState → _ZRinitState → enqueue ZRINIT
2. ZModemMux receives ZReadyToSendEvent
3. _handleFileRequestEvent calls onFileRequest
4. onFileRequest returns null (or not set)
5. _fileOffers = null, _moveToNextOffer() returns early
6. Session stays open, no file offered, remote waiting
7. If remote sends ZFIN → handled → OK
8. If remote doesn't send ZFIN → session never closes
```

### 5.6 Escape Parser Issues

| ID | Location | Description | Verdict |
|----|----------|-------------|---------|
| **P1** | `parser.dart`:1067 | `10061000` dead code — concatenation typo, never matched | **Confirmed Bug (dead code)** |
| **P2** | `parser.dart`:550-569 | SGR 38/48/58 malformed color: `break` exits inner switch but `i` not incremented; subsequent params misparsed | **Confirmed Bug** |
| P3 | `parser.dart`:268-306 | CSI params list has no size limit → OOM from `\e[1;2;...;999999h` | Confirmed Risk |

#### 5.6.1 P2 Minimal Reproduction

```
Input: ESC [ 38 : 5 m   (\e[38:5m)
CSI params: [38, 5]

i=0: param=38
  mode = params[1] = 5
  switch(5): i+2(2) >= params.length(2) → break (inner switch)
  continue
i=1: param=5
  case 5 → handler.setCursorBlink()  ← WRONG, "5" was color mode, not SGR style
```

---

## 6. Summary

```
Confirmed Bug (6):
  C1-C3: CRC silently discarded (3 locations in parser)
  M1:    async void fire-and-forget
  M2:    Backpressure commented out
  T1:    DATA mode absorbs headers → protocol deadlock
  P1:    10061000 dead code
  P2:    SGR 38/48/58 malformed color recovery

Confirmed Risk (5):
  S1/S3/S4/S7: No timeout → 4 stuck states
  M5:    onFileRequest returns null → session never closes
  P3:    CSI params unbounded

Theoretical Risk (3):
  C5:    ZRPOS offset >4GB
  M4:    ZMODEM false positive detection
  T4:    DATA mode + corrupt ZDLE → parse offset drift
```

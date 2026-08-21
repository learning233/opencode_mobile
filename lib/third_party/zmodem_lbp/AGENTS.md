# AGENTS.md — AI Agent Rules

Current Phase: **Protocol Stability**

## Mandatory Rules (phase-locked)

1. **API Frozen** — `parser.dart`, `core.dart`, `frame.dart` public signatures must not change.
2. **Replay First** — Protocol behavior changes MUST add a `.bin` corpus file to `test/fuzz/corpus/`, verify replay passes, THEN modify implementation.
3. **No gratuitous cleanup** — No "while we're here" architecture cleanup.
4. **No parser rewrite** — `ZModemParser` state machine logic must not be rewritten.
5. **No state machine redesign** — The `expectHeader`/`expectHexHeader`/`expectData`/`expectDataSubpacket` transitions must not be refactored.

## Stability Definition

Given identical byte sequence input, the parser always produces identical `ZModemFrame` output — **deterministic behavior** + **replay verifiable**.

## Status

- All 365 tests pass (incl. 27 corpus replay tests).
- Parser coverage: ZBIN, ZBIN32, ZHEX, data subpackets (ZCRCW, ZCRCQ, ZCRCE), CAN×5 cancel.
- CI: GitHub Actions (dart test/flutter analyze) + daily fuzz CI.

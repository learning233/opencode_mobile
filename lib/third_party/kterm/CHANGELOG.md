## [1.1.11] - 2026-05-18

### Bug Fixes
- Fix SGR 38/48/58 malformed color recovery: incomplete color spec no longer causes subsequent params to be misparsed
- Add CSI params size limit (256) to prevent OOM from malformed sequences
- Remove dead code `case 10061000` in DECSET handler

## [1.1.10] - 2026-05-18

### Bug Fixes
- Fix `Future.delayed` zombie callback in graphics manager test: replace with `tester.pump`
- Fix `gesture_detector.dart` double-tap timer disposal on widget dispose

### Code Quality
- Fix test isolation: eliminate async callback leaks across test files
- Add `run_test.sh` unified test runner with smoke/full/golden/fuzz modes
- Add `Makefile` with convenient targets: `make test`, `make smoke`, `make golden`, `make fuzz`
- Add gesture detector timer cleanup verification (already had `dispose`, confirmed correct)

## [1.1.9] - 2026-05-15

### Bug Fixes
- Fix example imports: replace removed `xterm.dart` with `kterm.dart` across 6 files
- Fix `withOpacity` deprecation: migrate to `withValues(alpha:)` (Flutter 3.27+)

### Code Quality
- Add `publish_to: 'none'` to suppress invalid_dependency warning (zmodem_lbp git dep)
- Add ZModem protocol decoding tests: ZMPHDR frame type parsing, file info header (29 new assertions across 7 tests)
- Clean up `AGENTS.md` with accurate test commands

## [1.1.8] - 2026-05-13

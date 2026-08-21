## 0.0.8

- ZFrame unified frame type replaces ZModemHeader/ZModemDataPacket in parser output
- Parser rewritten with autonomous mini state machine (no more _expectDataSubpacket)
- CRC validation on all frames
- Core rewritten with ZModemState enum + centralized transition table
- Timeout detection in blocking states
- Fuzz + soak test suite (1000 file transfers, 100K random iterations)

## 0.0.6

- Correct escape

## 0.0.5

- Remove unused deps

## 0.0.4

- Dep version

## 0.0.3

- Update to handle quirks.

## 0.0.2

- Add skipFile.


## 0.0.1

- Initial version.
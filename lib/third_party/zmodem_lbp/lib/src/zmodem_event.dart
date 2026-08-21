import 'package:zmodem_lbp/src/util/debug.dart';
import 'package:zmodem_lbp/src/zmodem_fileinfo.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';

abstract class ZModemEvent {}

/// The other side has offered a file for transfer.
class ZFileOfferedEvent implements ZModemEvent {
  final ZModemFileInfo fileInfo;

  ZFileOfferedEvent(this.fileInfo);

  @override
  String toString() {
    return DebugStringBuilder(
      'ZFileOfferedEvent',
    ).withField('fileInfo', fileInfo).toString();
  }
}

/// A chunk of data of the file currently being received.
class ZFileDataEvent implements ZModemEvent {
  final List<int> data;

  ZFileDataEvent(this.data);

  @override
  String toString() {
    return DebugStringBuilder(
      'ZFileDataEvent',
    ).withField('data', data.length).toString();
  }
}

/// The file we're currently receiving has been completely transferred.
class ZFileEndEvent implements ZModemEvent {
  @override
  String toString() {
    return 'ZFileEndEvent()';
  }
}

/// The remote side has sent a cancel sequence (5 × CAN). The session is reset.
class ZSessionCancelledEvent implements ZModemEvent {
  @override
  String toString() {
    return 'ZSessionCancelledEvent()';
  }
}

/// The event fired when the ZModem session is fully closed.
class ZSessionFinishedEvent implements ZModemEvent {
  @override
  String toString() {
    return 'ZSessionFinishedEvent()';
  }
}

/// The other side is ready to receive a file.
class ZReadyToSendEvent implements ZModemEvent {
  @override
  String toString() {
    return 'ZReadyToSendEvent()';
  }
}

/// The other side has accepted a file we just offered.
class ZFileAcceptedEvent implements ZModemEvent {
  const ZFileAcceptedEvent(this.offset);

  final int offset;

  @override
  String toString() {
    return 'ZFileAcceptedEvent(offset: $offset)';
  }
}

/// The other side has rejected a file we just offered.
class ZFileSkippedEvent implements ZModemEvent {
  @override
  String toString() {
    return 'ZFileSkippedEvent()';
  }
}

/// A data subpacket with an invalid CRC was received.
class ZCrcErrorEvent implements ZModemEvent {
  final ZFrame frame;

  ZCrcErrorEvent(this.frame);

  @override
  String toString() {
    return 'ZCrcErrorEvent(type: ${frame.type})';
  }
}

/// A blocking state timed out (e.g., waiting for content).
class ZTimeoutEvent implements ZModemEvent {
  final String stateName;

  ZTimeoutEvent(this.stateName);

  @override
  String toString() {
    return 'ZTimeoutEvent(state: $stateName)';
  }
}

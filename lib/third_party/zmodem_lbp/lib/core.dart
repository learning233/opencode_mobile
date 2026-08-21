import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:zmodem_lbp/src/metrics.dart';
import 'package:zmodem_lbp/src/util/string.dart';
import 'package:zmodem_lbp/src/zmodem_event.dart';
import 'package:zmodem_lbp/src/zmodem_fileinfo.dart';
import 'package:zmodem_lbp/src/zmodem_frame.dart';
import 'package:zmodem_lbp/src/zmodem_frame_types.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;

typedef ZModemTraceHandler = void Function(String message);

typedef ZModemTextHandler = void Function(int char);

enum ZModemState {
  init,
  rqInit,
  rInit,
  sInit,
  receivedFileProposal,
  waitingContent,
  receivingContent,
  readyToSend,
  sentFileProposal,
  sendingContent,
  closed,
  fin,
}

/// Contains the state of a ZModem session.
class ZModemCore {
  ZModemCore({this.onTrace, this.onPlainText});

  /// Optional metrics collector for diagnostics and fuzz testing.
  ZModemMetrics? metrics;

  late final _parser = ZModemParser()
    ..onPlainText = onPlainText
    ..onCancel = () {
      _state = ZModemState.init;
      _cancelled = true;
      metrics?.sessionCancellations++;
      metrics?.cancelCount++;
    };

  var _cancelled = false;

  final _sendQueue = Queue<ZModemPacket>();

  ZModemState _state = ZModemState.init;
  DateTime? _stateEnteredAt;

  static const _maxDataSubpacketSize = 8192;

  static const _stateTimeouts = <ZModemState, Duration>{
    ZModemState.waitingContent: Duration(seconds: 30),
    ZModemState.receivingContent: Duration(seconds: 30),
    ZModemState.closed: Duration(seconds: 10),
    ZModemState.sendingContent: Duration(seconds: 60),
  };

  final ZModemTraceHandler? onTrace;

  final ZModemTextHandler? onPlainText;

  bool get isFinished => _state == ZModemState.fin;

  Iterable<ZModemEvent> receive(Uint8List data) sync* {
    _parser.addData(data);
    _parser.metrics = metrics; // share metrics reference

    while (_parser.moveNext()) {
      final frame = _parser.current;
      onTrace?.call('<- $frame');
      final m = metrics;
      if (m != null) {
        m.stateTransitions++;
      }

      if (!frame.crcValid && frame.format == ZFrameFormat.dataSubpacket) {
        yield ZCrcErrorEvent(frame);
        continue;
      }

      final event = _handleFrame(frame);
      if (event != null) {
        if (event is ZFileDataEvent) {
          metrics?.totalDataBytesReceived += event.data.length;
        }
        if (event is ZFileOfferedEvent) {
          metrics?.fileTransfers++;
        }
        if (event is ZTimeoutEvent) {
          metrics?.timeoutsFired++;
        }
        yield event;
      }
    }

    if (_cancelled) {
      _cancelled = false;
      yield ZSessionCancelledEvent();
    }
  }

  ZModemEvent? _handleFrame(ZFrame frame) {
    switch ((_state, frame.type)) {
      case (ZModemState.init, consts.ZRINIT):
        return _emitEvent(ZModemState.readyToSend, ZReadyToSendEvent());

      case (ZModemState.init, consts.ZRQINIT):
        _enqueue(ZModemHeader.rinit());
        _enterState(ZModemState.rInit);
        return null;

      case (ZModemState.rInit, consts.ZSINIT):
        _enqueue(ZModemHeader.ack());
        _enterState(ZModemState.sInit);
        return null;

      case (ZModemState.rInit, consts.ZFILE):
        _enterState(ZModemState.receivedFileProposal);
        return null;

      case (ZModemState.rInit, consts.ZFIN):
        _enqueue(ZModemHeader.fin());
        return _emitEvent(ZModemState.fin, ZSessionFinishedEvent());

      case (ZModemState.rqInit, consts.ZRINIT):
        return _emitEvent(ZModemState.readyToSend, ZReadyToSendEvent());

      case (ZModemState.sInit, _):
        if (frame.format != ZFrameFormat.dataSubpacket) break;
        _enterState(ZModemState.rInit);
        return null;

      case (ZModemState.receivedFileProposal, _):
        if (frame.format != ZFrameFormat.dataSubpacket) break;
        final fileInfo = _parseFileInfo(frame.data);
        return ZFileOfferedEvent(fileInfo);

      case (ZModemState.waitingContent, consts.ZDATA):
        _enterState(ZModemState.receivingContent);
        return null;

      case (ZModemState.receivingContent, consts.ZEOF):
        _enqueue(ZModemHeader.rinit());
        return _emitEvent(ZModemState.rInit, ZFileEndEvent());

      case (ZModemState.receivingContent, _):
        if (frame.format == ZFrameFormat.dataSubpacket) {
          return ZFileDataEvent(frame.data);
        }
        break;

      case (ZModemState.readyToSend, consts.ZRINIT):
        return null;

      case (ZModemState.sentFileProposal, consts.ZRINIT):
        return null;

      case (ZModemState.sentFileProposal, consts.ZRPOS):
        final offset = _readLE32(frame);
        _enqueue(ZModemHeader.data(offset));
        return _emitEvent(
          ZModemState.sendingContent,
          ZFileAcceptedEvent(offset),
        );

      case (ZModemState.sentFileProposal, consts.ZSKIP):
        return _emitEvent(ZModemState.readyToSend, ZFileSkippedEvent());

      case (ZModemState.sendingContent, consts.ZRPOS):
        return ZFileAcceptedEvent(_readLE32(frame));

      case (ZModemState.sendingContent, consts.ZSKIP):
        return _emitEvent(ZModemState.readyToSend, ZFileSkippedEvent());

      case (_, consts.ZFIN):
        if (frame.format == ZFrameFormat.dataSubpacket) break;
        _enqueue(ZModemHeader.fin());
        return _emitEvent(ZModemState.fin, ZSessionFinishedEvent());
    }
    return null;
  }

  void _enterState(ZModemState newState) {
    _state = newState;
    _stateEnteredAt = clock.now();
  }

  /// Convenience: transition + return event.
  ZModemEvent _emitEvent(ZModemState newState, ZModemEvent event) {
    _enterState(newState);
    return event;
  }

  /// Check if the current state has timed out.
  ZModemEvent? checkTimeout() {
    final timeout = _stateTimeouts[_state];
    if (timeout == null) return null;
    if (_stateEnteredAt == null) return null;
    if (clock.now().difference(_stateEnteredAt!) > timeout) {
      _enqueue(ZModemHeader.fin());
      _state = ZModemState.closed;
      _stateEnteredAt = clock.now();
      return ZTimeoutEvent(_state.name);
    }
    return null;
  }

  int _readLE32(ZFrame frame) {
    return frame.params[0] |
        (frame.params[1] << 8) |
        (frame.params[2] << 16) |
        (frame.params[3] << 24);
  }

  ZModemFileInfo _parseFileInfo(Uint8List data) {
    final pathname = readCString(data, 0);
    final propertyString = readCString(data, pathname.length + 1);
    final properties = propertyString.split(' ');

    return ZModemFileInfo(
      pathname: pathname,
      length: properties.isNotEmpty ? int.parse(properties[0]) : null,
      modificationTime: properties.length > 1 ? int.parse(properties[1]) : null,
      mode: properties.length > 2 ? properties[2] : null,
      filesRemaining: properties.length > 4 ? int.parse(properties[4]) : null,
      bytesRemaining: properties.length > 5 ? int.parse(properties[5]) : null,
    );
  }

  void _enqueue(ZModemPacket packet) {
    _sendQueue.add(packet);
  }

  void _requireState(ZModemState expected) {
    if (_state != expected) {
      throw ZModemException('Invalid state: $_state, expected: $expected');
    }
  }

  bool get hasDataToSend => _sendQueue.isNotEmpty;

  Uint8List dataToSend() {
    final builder = BytesBuilder();

    while (_sendQueue.isNotEmpty) {
      onTrace?.call('-> ${_sendQueue.first}');
      final packet = _sendQueue.removeFirst();
      if (packet is ZModemDataPacket) {
        metrics?.totalDataBytesSent += packet.data.length;
      }
      builder.add(packet.encode());
    }

    return builder.toBytes();
  }

  void initiateSend() {
    _requireState(ZModemState.init);
    _enqueue(ZModemHeader.rqinit());
    _enterState(ZModemState.rqInit);
  }

  void initiateReceive() {
    _requireState(ZModemState.init);
    _enqueue(ZModemHeader.rinit());
    _enterState(ZModemState.rInit);
  }

  void acceptFile([int offset = 0]) {
    _requireState(ZModemState.receivedFileProposal);
    _enqueue(ZModemHeader.rpos(offset));
    _enterState(ZModemState.waitingContent);
  }

  void skipFile() {
    _requireState(ZModemState.receivedFileProposal);
    _enqueue(ZModemHeader.skip());
    _enterState(ZModemState.rInit);
  }

  void offerFile(ZModemFileInfo fileInfo) {
    _requireState(ZModemState.readyToSend);
    _enqueue(ZModemHeader.file());
    _enqueue(ZModemDataPacket.fileInfo(fileInfo));
    _enterState(ZModemState.sentFileProposal);
  }

  void sendFileData(Uint8List data) {
    _requireState(ZModemState.sendingContent);

    for (var i = 0; i < data.length; i += _maxDataSubpacketSize) {
      final end = min(i + _maxDataSubpacketSize, data.length);
      _enqueue(ZModemDataPacket.fileData(Uint8List.sublistView(data, i, end)));
    }
  }

  void finishSending(int offset) {
    _requireState(ZModemState.sendingContent);
    _enqueue(ZModemDataPacket.fileData(Uint8List(0), eof: true));
    _enqueue(ZModemHeader.eof(offset));
    _enterState(ZModemState.rqInit);
  }

  void finishSession() {
    if (_state == ZModemState.closed || _state == ZModemState.fin) return;

    _enqueue(ZModemHeader.fin());
    _enterState(ZModemState.closed);
  }
}

class ZModemException implements Exception {
  ZModemException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Debug metrics for ZModem protocol sessions.
///
/// Attach a [ZModemMetrics] instance to [ZModemCore] or [ZModemParser]
/// to collect runtime statistics for diagnostics and fuzz testing.
class ZModemMetrics {
  /// Total frames parsed by the parser (all formats).
  int framesParsed = 0;

  /// Hex headers parsed.
  int hexHeadersParsed = 0;

  /// Binary headers parsed.
  int binaryHeadersParsed = 0;

  /// Data subpackets parsed.
  int dataSubpacketsParsed = 0;

  /// Subpackets whose CRC did not match the computed value.
  int invalidCrcCount = 0;

  /// Dirty chars routed to onPlainText (non-framing bytes before a frame).
  int dirtyCharCount = 0;

  /// Cancel sequences detected (5 consecutive CAN bytes).
  int cancelCount = 0;

  /// Total state transitions processed in the core.
  int stateTransitions = 0;

  /// Timeout events fired by checkTimeout().
  int timeoutsFired = 0;

  /// Session cancellations (via cancel detection + reset).
  int sessionCancellations = 0;

  /// Total bytes of file data received (sum of all ZFileDataEvent data).
  int totalDataBytesReceived = 0;

  /// Total bytes of file data sent (sum of all sent subpackets).
  int totalDataBytesSent = 0;

  /// Number of ZFile events (file transfers started).
  int fileTransfers = 0;

  /// Number of ZCRCW-attributed data subpackets parsed (ZCRCE=end, ZCRCG=go, ZCRCQ=query, ZCRCW=reply-wait).
  int dataPacketsWithReply = 0;

  /// Number of ZCRCW data subpackets received.
  int dataPacketReplyWait = 0;

  /// Reset all counters to zero.
  void reset() {
    framesParsed = 0;
    hexHeadersParsed = 0;
    binaryHeadersParsed = 0;
    dataSubpacketsParsed = 0;
    invalidCrcCount = 0;
    dirtyCharCount = 0;
    cancelCount = 0;
    stateTransitions = 0;
    timeoutsFired = 0;
    sessionCancellations = 0;
    totalDataBytesReceived = 0;
    totalDataBytesSent = 0;
    fileTransfers = 0;
    dataPacketsWithReply = 0;
    dataPacketReplyWait = 0;
  }

  @override
  String toString() {
    return 'ZModemMetrics('
        'framesParsed: $framesParsed, '
        'hexHeaders: $hexHeadersParsed, '
        'binaryHeaders: $binaryHeadersParsed, '
        'dataSubpackets: $dataSubpacketsParsed, '
        'invalidCrc: $invalidCrcCount, '
        'dirtyChars: $dirtyCharCount, '
        'cancels: $cancelCount, '
        'stateTransitions: $stateTransitions, '
        'timeouts: $timeoutsFired, '
        'cancellations: $sessionCancellations, '
        'dataRx: ${_fmtBytes(totalDataBytesReceived)}, '
        'dataTx: ${_fmtBytes(totalDataBytesSent)}, '
        'transfers: $fileTransfers'
        ')';
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

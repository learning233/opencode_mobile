import 'package:zmodem_lbp/src/util/debug.dart';

class ZModemFileInfo {
  ZModemFileInfo({
    required this.pathname,
    this.length,
    this.modificationTime,
    this.mode,
    this.filesRemaining,
    this.bytesRemaining,
  });

  final String pathname;
  final int? length;
  final int? modificationTime;
  final String? mode;
  final int? filesRemaining;
  final int? bytesRemaining;

  @override
  String toString() {
    return DebugStringBuilder('ZModemFileInfo')
        .withField('pathname', pathname)
        .withField('length', length)
        .withField('modificationTime', modificationTime)
        .withField('mode', mode)
        .withField('filesRemaining', filesRemaining)
        .withField('bytesRemaining', bytesRemaining)
        .toString();
  }
}

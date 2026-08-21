extension IntToHex on int {
  String get hex {
    return '0x${toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}

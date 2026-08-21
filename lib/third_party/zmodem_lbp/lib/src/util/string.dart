import 'dart:typed_data';

/// Reads a '\0'-terminated string from the given [data] starting at [offset].
String readCString(Uint8List data, int offset) {
  final builder = BytesBuilder();
  for (var i = offset; i < data.length; i++) {
    final byte = data[i];
    if (byte == 0) {
      break;
    }
    builder.addByte(byte);
  }
  return String.fromCharCodes(builder.toBytes());
}

void writeCString(BytesBuilder builder, String string) {
  builder.add(string.codeUnits);
  builder.addByte(0);
}

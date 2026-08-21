class DebugStringBuilder {
  final String className;

  DebugStringBuilder(this.className);

  final Map<String, Object?> _fields = {};

  void add(String name, Object? value) {
    _fields[name] = value;
  }

  DebugStringBuilder withField(String name, Object? value) {
    _fields[name] = value;
    return this;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(className);
    buffer.write('(');
    for (var i = 0; i < _fields.length; i++) {
      if (i > 0) {
        buffer.write(', ');
      }
      final name = _fields.keys.elementAt(i);
      final value = _fields.values.elementAt(i);
      buffer.write('$name: $value');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

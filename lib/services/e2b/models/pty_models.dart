import 'dart:async';
import 'dart:typed_data';

class PtySize {
  final int cols;
  final int rows;

  const PtySize({this.cols = 80, this.rows = 24});

  Map<String, dynamic> toJson() => {'cols': cols, 'rows': rows};
}

class PtyOpts {
  final PtySize size;
  final String? cwd;
  final String? user;
  final Map<String, String> envs;
  final void Function(Uint8List data)? onData;

  const PtyOpts({
    this.size = const PtySize(),
    this.cwd,
    this.user,
    this.envs = const {},
    this.onData,
  });
}

class PtyHandle {
  final int pid;
  final Future<void> Function(Uint8List data) _inputSender;
  final Future<void> Function(PtySize size) _resizer;
  final Future<void> Function() _killer;

  PtyHandle({
    required this.pid,
    required Future<void> Function(Uint8List data) inputSender,
    required Future<void> Function(PtySize size) resizer,
    required Future<void> Function() killer,
  })  : _inputSender = inputSender,
        _resizer = resizer,
        _killer = killer;

  Future<void> sendInput(Uint8List data) => _inputSender(data);
  Future<void> resize(PtySize size) => _resizer(size);
  Future<void> kill() => _killer();
}

/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'artifacts_provider.dart';
import 'builder.dart';
import 'environment.dart';
import 'options.dart';
import 'target.dart';

final log = Logger('build_gradle');

class BuildGradle {
  BuildGradle({required this.userOptions});

  final CargokitUserOptions userOptions;

  Future<void> build() async {
    final targets = Environment.targetPlatforms.map((arch) {
      final target = Target.forFlutterName(arch);
      if (target == null) {
        throw Exception(
            "Unknown darwin target or platform: $arch, ${Environment.darwinPlatformName}");
      }
      return target;
    }).toList();

    final environment = BuildEnvironment.fromEnvironment(isAndroid: true);
    final provider =
        ArtifactProvider(environment: environment, userOptions: userOptions);
    final artifacts = await provider.getArtifacts(targets);

    for (final target in targets) {
      final libs = artifacts[target]!;
      final outputDir = path.join(Environment.outputDir, target.android!);
      Directory(outputDir).createSync(recursive: true);

      for (final lib in libs) {
        if (lib.type == AritifactType.dylib) {
          File(lib.path).copySync(path.join(outputDir, lib.finalFileName));
        }
      }
      _copyLibCppShared(target.android!, outputDir);
    }
  }

  static const _abiToNdkLibDir = {
    'armeabi-v7a': 'arm-linux-androideabi',
    'arm64-v8a': 'aarch64-linux-android',
    'x86': 'i686-linux-android',
    'x86_64': 'x86_64-linux-android',
  };

  /// Locates and copies libc++_shared.so from the NDK into [outputDir].
  void _copyLibCppShared(String abi, String outputDir) {
    final ndkLibDir = _abiToNdkLibDir[abi];
    if (ndkLibDir == null) {
      log.warning('Unknown ABI $abi – skipping libc++_shared.so copy');
      return;
    }

    final ndkPath = Environment.sdkPath.isNotEmpty
        ? path.join(Environment.sdkPath, 'ndk', Environment.ndkVersion)
        : null;

    if (ndkPath == null || !Directory(ndkPath).existsSync()) {
      log.warning(
          'NDK not found at "$ndkPath" – skipping libc++_shared.so copy');
      return;
    }

    final hostTag = Platform.isMacOS
        ? 'darwin-x86_64'
        : (Platform.isLinux ? 'linux-x86_64' : 'windows-x86_64');

    final libCppShared = path.joinAll([
      ndkPath,
      'toolchains',
      'llvm',
      'prebuilt',
      hostTag,
      'sysroot',
      'usr',
      'lib',
      ndkLibDir,
      'libc++_shared.so',
    ]);

    if (File(libCppShared).existsSync()) {
      log.info('Copying libc++_shared.so for $abi');
      File(libCppShared).copySync(path.join(outputDir, 'libc++_shared.so'));
    } else {
      log.warning('libc++_shared.so not found at "$libCppShared"');
    }
  }
}

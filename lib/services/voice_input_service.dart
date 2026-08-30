import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../init.dart';
import '../src/rust/api/common.dart';
import '../utils/translations.dart';
import '../src/rust/api/online.dart' as rust_online;
import '../src/rust/api/simple.dart' as rust_simple;

class VoiceInputService {
  static final VoiceInputService instance = VoiceInputService._internal();

  VoiceInputService._internal();

  static const String modelDownloadUrl =
      'https://www.modelscope.cn/models/xiaowangge/sherpa-onnx-sense-voice-small/resolve/master/model_q8.onnx';

  /// Minimum valid model file size (200 MB). Files smaller than this are
  /// considered corrupted or incomplete downloads (full model is ~230 MB).
  static const int _minModelFileSize = 200 * 1024 * 1024;

  bool _isListening = false;
  bool get isListening => _isListening;
  bool _isStarting = false;

  DateTime? _lastAudioReceivedAt;

  /// 录音是否真的还在出数据。`record` 的流即使静音也会持续输出 PCM，
  /// 所以该时间戳能反映录音是否真的活着（而非仅仅标志位）。
  bool get isRecordingActive =>
      _recordSubscription != null &&
      _audioRecorder != null &&
      _lastAudioReceivedAt != null &&
      DateTime.now().difference(_lastAudioReceivedAt!) <
          const Duration(seconds: 2);

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _recordSubscription;
  StreamSubscription<String>? _transcriptionSubscription;

  /// 转写流结束信号。`stopListening` 依赖它在取消订阅前等待 worker 冲刷
  /// 完剩余音频（句尾 final 送达 onResult 后才关闭流）。
  Completer<void>? _transcriptionDone;

  Future<File> getModelFile() async {
    final dir = await getApplicationSupportDirectory();
    final q8File = File('${dir.path}/model_q8.onnx');
    if (await q8File.exists() && (await q8File.length()) >= _minModelFileSize) {
      return q8File;
    }
    final legacyFile = File('${dir.path}/model1_small.onnx');
    if (await legacyFile.exists() &&
        (await legacyFile.length()) >= _minModelFileSize) {
      debugPrint(
        'VoiceInputService: using legacy model file model1_small.onnx',
      );
      return legacyFile;
    }
    return q8File;
  }

  Future<bool> isModelDownloaded() async {
    final modelFile = await getModelFile();
    return await modelFile.exists() &&
        (await modelFile.length()) >= _minModelFileSize;
  }

  Future<bool> downloadModel({
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final modelFile = File('${dir.path}/model_q8.onnx');
    final tmpFile = File('${dir.path}/model_q8.onnx.tmp');

    try {
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 15),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      await dio.download(
        modelDownloadUrl,
        tmpFile.path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );

      if (await tmpFile.exists() &&
          (await tmpFile.length()) >= _minModelFileSize) {
        if (await modelFile.exists()) {
          await modelFile.delete();
        }
        await tmpFile.rename(modelFile.path);
        debugPrint(
          'VoiceInputService: downloaded model_q8.onnx successfully (${await modelFile.length()} bytes)',
        );
        return true;
      }
      // Downloaded file is too small — likely corrupted or incomplete
      debugPrint(
        'VoiceInputService: downloaded file too small '
        '(${await tmpFile.length()} bytes, min $_minModelFileSize), discarding',
      );
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      return false;
    } catch (e) {
      debugPrint('VoiceInputService: downloadModel failed: $e');
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// 确保模型已下载，若缺失则弹出下载进度提示框
  Future<bool> ensureModelDownloaded() async {
    if (await isModelDownloaded()) return true;

    final receivedRx = 0.obs;
    final totalRx = 0.obs;
    final isDownloadingRx = true.obs;
    final errorRx = ''.obs;
    // Use a mutable holder so each retry creates a fresh CancelToken.
    // Dio's CancelToken cannot be reused after cancel().
    CancelToken cancelToken = CancelToken();
    final resultCompleter = Completer<bool>();
    Route<dynamic>? dialogRoute;

    // 精确关闭本对话框：若对话框仍是栈顶则正常 pop（结果经 route 返回），
    // 否则用 removeRoute 精确移除，避免下载期间被压上的其它对话框被误关。
    void closeDialog(bool result) {
      if (resultCompleter.isCompleted) return;
      final route = dialogRoute;
      final navigator = route?.navigator;
      if (route != null && navigator != null) {
        if (route.isCurrent) {
          navigator.pop(result);
        } else {
          navigator.removeRoute(route);
        }
      }
      resultCompleter.complete(result);
    }

    void startDownload() async {
      errorRx.value = '';
      isDownloadingRx.value = true;
      receivedRx.value = 0;
      totalRx.value = 0;
      // Create a fresh token for each attempt
      cancelToken = CancelToken();
      try {
        await downloadModel(
          onProgress: (count, total) {
            receivedRx.value = count;
            totalRx.value = total;
          },
          cancelToken: cancelToken,
        );
        closeDialog(true);
      } catch (e) {
        if (cancelToken.isCancelled) {
          closeDialog(false);
          return;
        }
        isDownloadingRx.value = false;
        errorRx.value = e.toString();
      }
    }

    startDownload();

    unawaited(
      Get.dialog(
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !cancelToken.isCancelled) {
              cancelToken.cancel();
            }
          },
          child: Builder(
            builder: (context) {
              // 记录本对话框的 route，用于精确关闭
              dialogRoute = ModalRoute.of(context);
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.cloud_download, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      LocaleKeys.voiceDownloadModelTitle.tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Obx(() {
                  if (errorRx.isNotEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          LocaleKeys.voiceDownloadFailed.tr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorRx.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }

                  final received = receivedRx.value;
                  final total = totalRx.value;
                  final progress = total > 0
                      ? (received / total).clamp(0.0, 1.0)
                      : null;
                  final receivedMb = (received / (1024 * 1024)).toStringAsFixed(
                    1,
                  );
                  final totalMb = total > 0
                      ? (total / (1024 * 1024)).toStringAsFixed(1)
                      : '?';
                  final percentStr = total > 0
                      ? '${(progress! * 100).toStringAsFixed(0)}%'
                      : LocaleKeys.voicePreparingDownload.tr;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.voiceDownloadPrompt.tr,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$receivedMb MB / $totalMb MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            percentStr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                actions: [
                  Obx(() {
                    if (errorRx.isNotEmpty) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => closeDialog(false),
                            child: Text(LocaleKeys.cancel.tr),
                          ),
                          ElevatedButton(
                            onPressed: startDownload,
                            child: Text(LocaleKeys.retry.tr),
                          ),
                        ],
                      );
                    }
                    return TextButton(
                      onPressed: () {
                        if (!cancelToken.isCancelled) {
                          cancelToken.cancel();
                        }
                        closeDialog(false);
                      },
                      child: Text(LocaleKeys.voiceCancelDownload.tr),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        barrierDismissible: false,
      ),
    );

    // 对话框已用 unawaited 弹出，结果完全由 closeDialog 经 completer 驱动。
    // 若对话框因导航栈整体销毁等原因未走 closeDialog，则超时返回 false 避免挂起。
    return await resultCompleter.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () => false,
    );
  }

  Future<bool> initialize({Function(String error)? onError}) async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isPermanentlyDenied) {
        onError?.call(LocaleKeys.voiceMicPermissionDeniedPermanent.tr);
        await openAppSettings();
        return false;
      }

      if (!status.isGranted) {
        onError?.call(LocaleKeys.voiceMicPermissionDenied.tr);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Failed to request microphone permission: $e');
      onError?.call('${LocaleKeys.voiceMicPermissionRequestFailed.tr}: $e');
      return false;
    }
  }

  /// 从 bundle 拷贝 [assetPath] 到 [targetFile]（若目标不存在或长度与资产
  /// 不一致）。仅判断 exists() 的话，历史拷贝被中途杀死留下的截断文件
  /// （如 libonnxruntime.so）会永驻本地，Rust 侧加载损坏文件持续报错。
  Future<void> _copyAssetIfNeeded(String assetPath, File targetFile) async {
    final byteData = await rootBundle.load(assetPath);
    final expectedLen = byteData.lengthInBytes;
    if (await targetFile.exists()) {
      final actualLen = await targetFile.length();
      if (actualLen == expectedLen) return;
      debugPrint(
        'VoiceInputService: $assetPath copy corrupted '
        '(${actualLen}B != ${expectedLen}B), recopying',
      );
    }
    await targetFile.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
  }

  Future<Map<String, String>> _prepareAssetPaths() async {
    final dir = await getApplicationSupportDirectory();
    final modelFile = await getModelFile();
    final vocabFile = File('${dir.path}/tokens.txt');
    final vadFile = File('${dir.path}/vad_stream.onnx');

    if (!await modelFile.exists() || (await modelFile.length()) == 0) {
      throw StateError('语音识别模型未下载');
    }
    await _copyAssetIfNeeded('assets/sensevoice/tokens.txt', vocabFile);
    await _copyAssetIfNeeded('assets/vad_stream.onnx', vadFile);

    if (Platform.isAndroid) {
      final soFile = File('${dir.path}/libonnxruntime.so');
      debugPrint('VoiceInputService: ensuring libonnxruntime.so asset...');
      await _copyAssetIfNeeded('onnx/libonnxruntime.so', soFile);
      debugPrint('VoiceInputService: libonnxruntime.so ready at ${soFile.path}');
    }

    return {
      'modelPath': modelFile.path,
      'vocabPath': vocabFile.path,
      'vadModelPath': vadFile.path,
    };
  }

  double _calculateSoundLevel(Uint8List bytes) {
    if (bytes.length < 2) return 0.0;
    final buffer = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    double sumSquare = 0;
    final sampleCount = bytes.length ~/ 2;
    for (int i = 0; i < sampleCount; i++) {
      final sample = buffer.getInt16(i * 2, Endian.little);
      sumSquare += sample * sample;
    }
    final rms = sqrt(sumSquare / sampleCount);
    return (rms / 8000.0).clamp(0.0, 1.0);
  }

  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double level)? onSoundLevel,
    Function(String error)? onError,
    String? localeId,
  }) async {
    if (_isStarting) {
      debugPrint('VoiceInputService: startListening already in progress');
      return false;
    }
    _isStarting = true;
    debugPrint('VoiceInputService: startListening initiated');

    try {
      final granted = await initialize(onError: onError);
      if (!granted) {
        debugPrint('VoiceInputService: mic permission denied');
        _isStarting = false;
        return false;
      }
      debugPrint('VoiceInputService: mic permission granted');

      final modelReady = await ensureModelDownloaded();
      if (!modelReady) {
        debugPrint('VoiceInputService: model download cancelled or failed');
        _isStarting = false;
        return false;
      }

      await stopListening();
      await Future.delayed(const Duration(milliseconds: 50));

      final paths = await _prepareAssetPaths();
      debugPrint('VoiceInputService: asset paths prepared: $paths');

      _isListening = true;

      debugPrint(
        'VoiceInputService: calling rust_simple.runOnlineTranscription...',
      );
      final transcriptionDone = Completer<void>();
      _transcriptionDone = transcriptionDone;
      _transcriptionSubscription = rust_simple
          .runOnlineTranscription(
            modelPath: paths['modelPath']!,
            vocabPath: paths['vocabPath']!,
            vadModelPath: paths['vadModelPath']!,
            asrSettings: const AsrSettings(language: 'auto', useItn: true),
            vadSettings: VadSettings(
              threshold: Global.vadThreshold,
              minSilenceDuration: Global.vadMinSilenceDuration,
              minSpeechDuration: Global.vadMinSpeechDuration,
              maxSpeechDuration: Global.vadMaxSpeechDuration,
              speechPadMs: Global.vadSpeechPadMs,
            ),
          )
          .listen(
            (payload) {
              debugPrint('VoiceInputService: rust payload received: $payload');
              if (!_isListening) return;
              try {
                final Map<String, dynamic> json = jsonDecode(payload);
                final kind = json['kind'];
                if (kind == 'final' || kind == 'partial') {
                  final text = (json['text'] as String? ?? '').trim();
                  if (text.isNotEmpty) {
                    onResult(text, kind == 'final');
                  }
                }
              } catch (e) {
                debugPrint('VoiceInputService ignored payload: $payload ($e)');
              }
            },
            onError: (err) {
              debugPrint('Rust transcription error: $err');
              if (!transcriptionDone.isCompleted) {
                transcriptionDone.complete();
              }
              onError?.call('${LocaleKeys.voiceTranscriptionError.tr}: $err');
              stopListening();
            },
            onDone: () {
              debugPrint('VoiceInputService: transcription stream done');
              if (!transcriptionDone.isCompleted) {
                transcriptionDone.complete();
              }
            },
          );
      debugPrint(
        'VoiceInputService: runOnlineTranscription subscription set up',
      );

      _audioRecorder = AudioRecorder();
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        debugPrint('VoiceInputService: AudioRecorder mic permission denied');
        onError?.call(LocaleKeys.voiceRecordPermissionDenied.tr);
        await stopListening();
        return false;
      }
      debugPrint('VoiceInputService: AudioRecorder mic permission OK');

      final audioStream = await _audioRecorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      debugPrint('VoiceInputService: AudioRecorder stream started');

      _recordSubscription = audioStream.listen(
        (Uint8List data) {
          if (!_isListening) return;

          _lastAudioReceivedAt = DateTime.now();

          try {
            rust_online.pushOnlineAudio(
              source: 'mic',
              pcmS16Le: data,
              sampleRate: 16000,
            );
          } catch (e) {
            debugPrint('Failed to push audio to rust: $e');
          }

          if (onSoundLevel != null) {
            final level = _calculateSoundLevel(data);
            onSoundLevel(level);
          }
        },
        onError: (err) {
          debugPrint('Audio recording stream error: $err');
          onError?.call('${LocaleKeys.voiceRecordStreamError.tr}: $err');
          stopListening();
        },
      );
      debugPrint('VoiceInputService: record subscription set up');

      return true;
    } catch (e, stack) {
      debugPrint('Failed to start listening: $e\n$stack');
      onError?.call('${LocaleKeys.voiceStartFailed.tr}: $e');
      await stopListening();
      return false;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopListening() async {
    debugPrint('VoiceInputService: stopListening initiated');
    _lastAudioReceivedAt = null;

    try {
      await _recordSubscription?.cancel();
      _recordSubscription = null;
      debugPrint('VoiceInputService: cancelled _recordSubscription');

      if (_audioRecorder != null) {
        await _audioRecorder!.stop();
        await _audioRecorder!.dispose();
        _audioRecorder = null;
        debugPrint('VoiceInputService: stopped and disposed _audioRecorder');
      }
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }

    try {
      await rust_online.finishOnlineAudioSource(source: 'mic');
      debugPrint('VoiceInputService: finished online audio source');
    } catch (_) {}

    try {
      await rust_online.stopOnlineTranscription();
      debugPrint('VoiceInputService: stopped online transcription');
    } catch (_) {}

    // 等待 worker 处理完 FinishSource/Stop 并把剩余音频冲刷成 final 事件，
    // 期间不取消订阅、不置 _isListening=false，保证句尾文本能通过 onResult
    // 送达后再停。转写流的 onDone 会 complete _transcriptionDone（见
    // startListening 的 onDone）；onError 也会 complete，避免错误路径卡住。
    // 超时兜底防 worker 异常挂起；1s 在低端机/长句的 SenseVoice 冲刷下不够
    // （Stop 前需先完成一次推理），放宽到 5s 避免提前取消订阅丢句尾。
    final done = _transcriptionDone;
    if (done != null) {
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    _isListening = false;
    await _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;
    _transcriptionDone = null;
    debugPrint('VoiceInputService: cancelled _transcriptionSubscription');
  }

  Future<void> cancelListening() async {
    await stopListening();
  }
}

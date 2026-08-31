import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../init.dart';
import '../services/voice_input_service.dart';
import '../utils/snackbar_utils.dart';
import '../utils/translations.dart';

class VoiceInputController extends GetxController with WidgetsBindingObserver {
  final isListening = false.obs;
  final isContinuousMode = false.obs;
  final isLongPressMode = false.obs;
  final isCancelZone = false.obs;
  final isInsertZone = false.obs;
  final recognizedText = ''.obs;
  final soundLevel = 0.0.obs;

  TextEditingController? _targetTextController;
  int _lastVoiceTextLength = 0;
  String _accumulatedLongPressText = '';

  /// 停止冲刷期的写入落点锁定：stopListening 会等 ≤5s 让旧流把句尾 final
  /// 冲刷进 onResult。期间发生的换目标（切会话/停止退出）不得改道冲刷文本，
  /// 否则上一会话的句尾会写进新会话输入框（跨会话文本泄漏）。
  TextEditingController? _flushTarget;
  int _flushLastLen = 0;

  /// 冲刷期锁定的自动发送匹配起点：stopSingleTap 会经 _setTarget(null) 把
  /// [_voiceStartLen] 归零，若冲刷期直接读它，句尾 final 的自动发送匹配会
  /// 退化成从 0 起全文扫描（命中用户手打的"发送"指令误发送）。锁定值与
  /// [_flushLastLen] 同生命周期。
  int _flushStartLen = 0;

  /// 当前语音流接管目标输入框时的文本长度：自动发送指令只在该流新增的
  /// 区间内匹配，避免命中用户手动键入的旧文本（如手打的"，发送。"）误发送。
  int _voiceStartLen = 0;

  DateTime _lastSoundLevelAt = DateTime.fromMillisecondsSinceEpoch(0);

  final VoiceInputService _service = VoiceInputService.instance;

  bool _isProcessingTap = false;

  /// 单点语音模式下，识别到发送指令并命中标点条件时，回调待发送文本。
  void Function(String text)? autoSendHandler;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    isListening.value = false;
    isContinuousMode.value = false;
    isLongPressMode.value = false;
    isCancelZone.value = false;
    isInsertZone.value = false;
    recognizedText.value = '';
    _accumulatedLongPressText = '';
    soundLevel.value = 0.0;
    _isProcessingTap = false;
    _service.stopListening();
  }

  /// 换目标统一入口：记录语音流接管时的文本起点（自动发送匹配区间用）。
  void _setTarget(TextEditingController? controller) {
    _targetTextController = controller;
    _voiceStartLen = controller?.text.length ?? 0;
  }

  void _lockFlushTarget() {
    _flushTarget = _targetTextController;
    _flushLastLen = _lastVoiceTextLength;
    _flushStartLen = _voiceStartLen;
  }

  void _unlockFlushTarget() {
    _flushTarget = null;
    _flushLastLen = 0;
    _flushStartLen = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 仅处理 paused（App 不可见）：Android 后台无前台服务时麦克风会被系统
    // 掐断，录音流静默停止而 UI 仍显示监听中（假监听）。不用 inactive——
    // iOS 权限弹窗/下拉通知栏等瞬态也触发 inactive，会把首次启动语音误停。
    if (state != AppLifecycleState.paused) return;
    if (isLongPressMode.value) {
      unawaited(cancelLongPress());
    } else if (isListening.value) {
      unawaited(stopSingleTap());
    }
  }

  /// 单击模式：启动/暂停转文本直接输入到输入框
  Future<void> toggleSingleTap(TextEditingController textController) async {
    if (_isProcessingTap) return;
    _isProcessingTap = true;

    try {
      if (isListening.value) {
        if (identical(textController, _targetTextController)) {
          // 再次点击同一个麦克风：完全退出语音模式。
          await stopSingleTap();
        } else {
          // 连续模式开启时切换了 session：把目标输入框换到当前 session，继续录音。
          if (_service.isListening && !_service.isRecordingActive) {
            // 流假活（录音已被系统静默掐断）：锁定冲刷落点，重启时内部
            // stopListening 冲刷出的句尾 final 只写回旧目标输入框。
            _lockFlushTarget();
          }
          _setTarget(textController);
          _lastVoiceTextLength = 0;
          recognizedText.value = '';
          if (!_service.isListening || !_service.isRecordingActive) {
            await _startSingleTapListening();
          }
        }
        return;
      }

      isContinuousMode.value = Global.continuousVoiceInput;
      await _startSingleTapListening(textController);
    } finally {
      _isProcessingTap = false;
    }
  }

  Future<void> _startSingleTapListening([
    TextEditingController? textController,
  ]) async {
    if (textController != null) {
      // 旧流仍在（标志位脱同步等边缘场景）时先锁定其冲刷落点再换目标。
      if (_service.isListening) {
        _lockFlushTarget();
      }
      _setTarget(textController);
    }
    _lastVoiceTextLength = 0;
    isLongPressMode.value = false;
    isCancelZone.value = false;
    recognizedText.value = '';

    final success = await _service.startListening(
      onResult: (text, isFinal) {
        recognizedText.value = text;
        // 冲刷期锁定：旧流停止后冲刷的句尾 final 只允许写回锁定目标；
        // 正常监听期写当前目标（连续模式下切换会话即时改道）。
        final flushing = _flushTarget != null;
        final target = _flushTarget ?? _targetTextController;
        final lastLen = flushing ? _flushLastLen : _lastVoiceTextLength;
        if (target != null) {
          final currentText = target.text;
          // Determine the prefix text before we started appending voice segments.
          // If the user modified the text manually, we preserve their changes.
          final baseLen = (currentText.length - lastLen).clamp(
            0,
            currentText.length,
          );
          final baseText = currentText.substring(0, baseLen);
          final prefix = baseText.isNotEmpty && !baseText.endsWith(' ')
              ? '$baseText '
              : baseText;
          final newText = '$prefix$text';

          target.text = newText;
          if (isFinal) {
            if (flushing) {
              _flushLastLen = 0;
            } else {
              _lastVoiceTextLength = 0;
            }
          } else {
            final segLen = newText.length - baseText.length;
            if (flushing) {
              _flushLastLen = segLen;
            } else {
              _lastVoiceTextLength = segLen;
            }
          }

          target.selection = TextSelection.fromPosition(
            TextPosition(offset: target.text.length),
          );
        }

        // 自动发送：仅在单点模式下监听 ASR 结果。识别到发送指令且紧邻前后
        // 均为标点符号时，自动发送指令前的内容。长按模式不会走到这里。
        // 匹配限定在本流新增区间（_voiceStartLen 起），不扫用户手打的旧文本。
        if (isFinal &&
            Global.autoSendVoiceEnabled &&
            autoSendHandler != null &&
            target != null) {
          final sendText = _extractAutoSendText(
            target.text,
            Global.voiceSendCommand,
            // 冲刷期用锁定值：_setTarget(null) 已把 _voiceStartLen 归零，
            // 直接用会从 0 起全文扫描（见 _flushStartLen 注释）。
            flushing ? _flushStartLen : _voiceStartLen,
          );
          if (sendText != null) {
            if (flushing) {
              _flushLastLen = 0;
            } else {
              _lastVoiceTextLength = 0;
            }
            recognizedText.value = '';
            autoSendHandler!(sendText);
          }
        }
      },
      onSoundLevel: null,
      onError: (err) {
        Snack.error(err, title: LocaleKeys.voiceRecognitionErrorTitle.tr);
        isListening.value = false;
        isContinuousMode.value = false;
        soundLevel.value = 0.0;
      },
    );

    // startListening 内部的 stopListening 已等完句尾冲刷，解除落点锁定。
    _unlockFlushTarget();

    if (success) {
      isListening.value = true;
      HapticFeedback.lightImpact();
    } else {
      isListening.value = false;
      isContinuousMode.value = false;
    }
  }

  /// 发送后调用：重新绑定目标输入框、清空 ASR 结果，并保证监听是活的。
  /// 连续语音输入关闭时，发送后自动停止语音输入。
  Future<void> onTextSubmitted(TextEditingController? textController) async {
    if (!isContinuousMode.value) {
      if (isListening.value) {
        await stopSingleTap();
      }
      return;
    }
    // 在途冲刷保护：流活着但录音已静默死亡（如切后台被系统掐断麦克风）时，
    // 先锁定冲刷落点为旧目标，防止 stopListening 冲刷出的句尾 final 在
    // 换目标后写入新会话输入框。
    final needFlushLock = _service.isListening && !_service.isRecordingActive;
    if (needFlushLock) {
      _lockFlushTarget();
    }

    _lastVoiceTextLength = 0;
    recognizedText.value = '';
    if (!_service.isListening || !_service.isRecordingActive) {
      await _service.stopListening();
      _unlockFlushTarget();
      if (textController != null) {
        _setTarget(textController);
      }
      await _startSingleTapListening();
    } else if (textController != null) {
      // 流健康：仅换目标，后续识别结果写入新会话输入框（连续语音语义）。
      _setTarget(textController);
    }
  }

  /// 切换 session 时把语音输入目标指向当前会话的输入框，
  /// 连续语音模式保持监听并自动切到新输入框。
  void setTargetController(TextEditingController textController) {
    _setTarget(textController);
    _lastVoiceTextLength = 0;
    recognizedText.value = '';
  }

  /// 在 [fullText] 自 [matchFrom] 起的新增区间内查找 [command]，要求跳过
  /// 空白后紧邻 command 前后的字符均为标点符号。命中则返回 command 之前的
  /// 文本（去空白），否则返回 null。
  String? _extractAutoSendText(String fullText, String command, int matchFrom) {
    if (command.isEmpty || fullText.isEmpty) return null;
    final pattern = RegExp(
      r'(\p{P}\s*)' + RegExp.escape(command) + r'(\s*\p{P})',
      unicode: true,
    );
    final from = matchFrom.clamp(0, fullText.length);
    final match = pattern.firstMatch(fullText.substring(from));
    if (match == null) return null;
    final leading = match.group(1)!;
    final cmdStart = from + match.start + leading.length;
    final sendText = fullText.substring(0, cmdStart).trim();
    return sendText.isEmpty ? null : sendText;
  }

  Future<void> stopSingleTap() async {
    // 先锁定冲刷落点再清目标：stopListening 的 ≤5s 冲刷窗口内旧流句尾
    // final 仍会经 onResult 送达，只允许写回停止时的目标输入框；期间
    // 用户切换会话（ever → setTargetController）不得把文本改道新会话。
    _lockFlushTarget();
    _setTarget(null);
    _lastVoiceTextLength = 0;
    await _service.stopListening();
    _unlockFlushTarget();
    isListening.value = false;
    isContinuousMode.value = false;
    soundLevel.value = 0.0;
    HapticFeedback.lightImpact();
  }

  /// 长按模式：开启浮动卡片预览
  Future<void> startLongPress() async {
    isLongPressMode.value = true;
    isCancelZone.value = false;
    isInsertZone.value = false;
    recognizedText.value = '';
    _accumulatedLongPressText = '';
    soundLevel.value = 0.0;
    _lastSoundLevelAt = DateTime.fromMillisecondsSinceEpoch(0);

    HapticFeedback.mediumImpact();

    final success = await _service.startListening(
      onResult: (text, isFinal) {
        final prefix =
            _accumulatedLongPressText.isNotEmpty &&
                !_accumulatedLongPressText.endsWith(' ')
            ? '$_accumulatedLongPressText '
            : _accumulatedLongPressText;
        final fullText = '$prefix$text';
        recognizedText.value = fullText;

        if (isFinal) {
          _accumulatedLongPressText = fullText;
        }
      },
      onSoundLevel: (level) {
        // PCM 块约 20-50ms 一条，直接写 Rx 会高频重建 overlay；100ms 节流足够流畅。
        final now = DateTime.now();
        if (now.difference(_lastSoundLevelAt) <
            const Duration(milliseconds: 100)) {
          return;
        }
        _lastSoundLevelAt = now;
        soundLevel.value = level;
      },
      onError: (err) {
        Snack.error(err, title: LocaleKeys.voiceRecognitionErrorTitle.tr);
        isListening.value = false;
      },
    );

    if (success) {
      // 启动期间（权限/模型下载弹窗耗时较长）用户可能已松手，endLongPress/
      // cancelLongPress 会复位 isLongPressMode。此时录音无人消费，立即回收，
      // 避免"长按早已结束、麦克风却持续录音"的幽灵状态。
      if (!isLongPressMode.value) {
        await _service.stopListening();
      } else {
        isListening.value = true;
      }
    } else {
      isLongPressMode.value = false;
      isCancelZone.value = false;
      isInsertZone.value = false;
      recognizedText.value = '';
      soundLevel.value = 0.0;
      _accumulatedLongPressText = '';
    }
  }

  /// 长按滑动过程中更新是否在取消或输入区域
  void updateDragZone(double dy) {
    final bool cancel = dy < -50;
    final bool insert = dy > 50;

    if (isCancelZone.value != cancel) {
      isCancelZone.value = cancel;
      HapticFeedback.selectionClick();
    }
    if (isInsertZone.value != insert) {
      isInsertZone.value = insert;
      HapticFeedback.selectionClick();
    }
  }

  /// 长按松开：根据状态判定是发送、输入还是丢弃
  Future<void> endLongPress({
    required Function(String text) onSend,
    required Function(String text) onInsert,
  }) async {
    final wasCancel = isCancelZone.value;
    final wasInsert = isInsertZone.value;

    // 先停止并等待句尾冲刷：stopListening 会等待 worker 把剩余音频的
    // final 事件送达（见 VoiceInputService.stopListening），此后
    // recognizedText 才包含完整的最后一句，避免发送时丢句尾。
    await _service.stopListening();

    final text = recognizedText.value.trim();

    isListening.value = false;
    isLongPressMode.value = false;
    isCancelZone.value = false;
    isInsertZone.value = false;
    soundLevel.value = 0.0;
    _accumulatedLongPressText = '';

    if (wasCancel) {
      HapticFeedback.heavyImpact();
      recognizedText.value = '';
      return;
    }

    HapticFeedback.mediumImpact();
    if (text.isNotEmpty) {
      if (wasInsert) {
        onInsert(text);
      } else {
        onSend(text);
      }
      recognizedText.value = '';
    }
  }

  /// 长按被系统中断或取消
  Future<void> cancelLongPress() async {
    await _service.cancelListening();
    isListening.value = false;
    isLongPressMode.value = false;
    isCancelZone.value = false;
    isInsertZone.value = false;
    soundLevel.value = 0.0;
    recognizedText.value = '';
    _accumulatedLongPressText = '';
  }

  /// 目标输入框被销毁（会话关闭/PageView 回收远页）时解除绑定。
  /// 单点监听仍在进行时一并停止录音：识别结果已无写入目标，继续录音
  /// 只会空转麦克风、结果全部丢失（写入 disposed controller 的异常被
  /// service 吞掉）。长按模式识别文本不写入输入框，仅解除绑定。
  Future<void> detachTarget(TextEditingController textController) async {
    if (!identical(_targetTextController, textController)) return;
    if (!isLongPressMode.value && isListening.value) {
      await stopSingleTap();
      return;
    }
    _setTarget(null);
    _lastVoiceTextLength = 0;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.stopListening();
    super.onClose();
  }
}

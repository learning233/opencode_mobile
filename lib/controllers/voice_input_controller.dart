import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../init.dart';
import '../services/voice_input_service.dart';
import '../utils/snackbar_utils.dart';
import '../utils/translations.dart';

class VoiceInputController extends GetxController {
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

  final VoiceInputService _service = VoiceInputService.instance;

  bool _isProcessingTap = false;

  /// 单点语音模式下，识别到发送指令并命中标点条件时，回调待发送文本。
  void Function(String text)? autoSendHandler;

  @override
  void onInit() {
    super.onInit();
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
          _targetTextController = textController;
          _lastVoiceTextLength = 0;
          recognizedText.value = '';
          if (!_service.isListening) {
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
      _targetTextController = textController;
    }
    _lastVoiceTextLength = 0;
    isLongPressMode.value = false;
    isCancelZone.value = false;
    recognizedText.value = '';

    final success = await _service.startListening(
      onResult: (text, isFinal) {
        recognizedText.value = text;
        if (_targetTextController != null) {
          final currentText = _targetTextController!.text;
          // Determine the prefix text before we started appending voice segments.
          // If the user modified the text manually, we preserve their changes.
          final baseLen = (currentText.length - _lastVoiceTextLength).clamp(
            0,
            currentText.length,
          );
          final baseText = currentText.substring(0, baseLen);
          final prefix = baseText.isNotEmpty && !baseText.endsWith(' ')
              ? '$baseText '
              : baseText;
          final newText = '$prefix$text';

          _targetTextController!.text = newText;
          if (isFinal) {
            _lastVoiceTextLength = 0;
          } else {
            _lastVoiceTextLength = newText.length - baseText.length;
          }

          _targetTextController!.selection = TextSelection.fromPosition(
            TextPosition(offset: _targetTextController!.text.length),
          );
        }

        // 自动发送：仅在单点模式下监听 ASR 结果。识别到发送指令且紧邻前后
        // 均为标点符号时，自动发送指令前的内容。长按模式不会走到这里。
        if (isFinal &&
            Global.autoSendVoiceEnabled &&
            autoSendHandler != null &&
            _targetTextController != null) {
          final sendText = _extractAutoSendText(
            _targetTextController!.text,
            Global.voiceSendCommand,
          );
          if (sendText != null) {
            _lastVoiceTextLength = 0;
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
    if (textController != null) {
      _targetTextController = textController;
    }
    _lastVoiceTextLength = 0;
    recognizedText.value = '';
    if (!_service.isListening || !_service.isRecordingActive) {
      await _service.stopListening();
      await _startSingleTapListening();
    }
  }

  /// 切换 session 时把语音输入目标指向当前会话的输入框，
  /// 连续语音模式保持监听并自动切到新输入框。
  void setTargetController(TextEditingController textController) {
    _targetTextController = textController;
    _lastVoiceTextLength = 0;
    recognizedText.value = '';
  }

  /// 在 [fullText] 中查找 [command]，要求跳过空白后紧邻 command 前后的字符
  /// 均为标点符号。命中则返回 command 之前的文本（去空白），否则返回 null。
  String? _extractAutoSendText(String fullText, String command) {
    if (command.isEmpty || fullText.isEmpty) return null;
    final pattern = RegExp(
      r'(\p{P}\s*)' + RegExp.escape(command) + r'(\s*\p{P})',
      unicode: true,
    );
    final match = pattern.firstMatch(fullText);
    if (match == null) return null;
    final leading = match.group(1)!;
    final cmdStart = match.start + leading.length;
    final sendText = fullText.substring(0, cmdStart).trim();
    return sendText.isEmpty ? null : sendText;
  }

  Future<void> stopSingleTap() async {
    await _service.stopListening();
    isListening.value = false;
    isContinuousMode.value = false;
    soundLevel.value = 0.0;
    _targetTextController = null;
    _lastVoiceTextLength = 0;
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
        soundLevel.value = level;
      },
      onError: (err) {
        Snack.error(err, title: LocaleKeys.voiceRecognitionErrorTitle.tr);
        isListening.value = false;
      },
    );

    if (success) {
      isListening.value = true;
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

  @override
  void onClose() {
    _service.stopListening();
    super.onClose();
  }
}

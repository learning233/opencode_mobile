import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/tablet_tool_controller.dart';
import '../../tablet/in_app_browser_view.dart';

/// Phone-layout persistent browser layer.
///
/// Mounted in [HomePage] once the browser sheet has ever been opened and never
/// unmounted afterwards: closing it just slides the sheet down behind an
/// [IgnorePointer] gate, so the underlying [InAppBrowserView] / WebView state
/// (scroll position, JS state, form input) survives and is reused on re-open.
class PhoneBrowserLayer extends StatelessWidget {
  final TabletToolController controller;
  final VoidCallback onClose;

  const PhoneBrowserLayer({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = controller.browserSheetVisible.value;
      return PopScope(
        canPop: !visible,
        onPopInvokedWithResult: (didPop, result) {
          // 系统返回键：sheet 打开时先关闭它，而非退出页面。
          if (didPop) return;
          if (controller.browserSheetVisible.value) {
            controller.closeBrowserSheet();
          }
        },
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 半透明遮罩（点按关闭）
              AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: GestureDetector(
                  onTap: visible ? onClose : null,
                  child: const ColoredBox(color: Colors.black54),
                ),
              ),
              // 浏览器 sheet：关闭时整体下滑到屏外，状态保留。
              // Material 提供 IconButton/Tooltip/TextField 所需的祖先。
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(child: InAppBrowserView(onClose: onClose)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

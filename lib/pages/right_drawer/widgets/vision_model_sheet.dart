import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/session_controller.dart';
import '../../../utils/translations.dart';

/// 视觉模型选择底部弹窗。
class VisionModelSheet {
  static void show(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LocaleKeys.mobileSelectVisionModel.tr,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ),
                Flexible(
                  child: Obx(() {
                    final models = ctrl.availableModels
                        .where((m) => m.supportsImage)
                        .toList();
                    if (models.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          LocaleKeys.mobileNoVisionModelsHint.tr,
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final m = models[i];
                        final selected = m.key == ctrl.visionModelKey;
                        return ListTile(
                          dense: true,
                          title: Text(
                            m.name.isNotEmpty ? m.name : m.id,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${m.providerId}/${m.id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () {
                            ctrl.setVisionModel(m.key);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

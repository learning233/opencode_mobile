import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/pty_session.dart';
import '../../utils/translations.dart';

class PtyIndicator extends StatelessWidget {
  final List<PtySession> sessions;
  final String activeId;
  final ValueChanged<String> onTap;

  const PtyIndicator({
    super.key,
    required this.sessions,
    required this.activeId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Text(
        LocaleKeys.terminalTitle.tr,
        style: const TextStyle(fontSize: 16),
      );
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: sessions.map((s) {
          final isActive = s.id == activeId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Obx(() {
              final isConnected = s.connected.value;
              final isError = s.error.value;

              final dotColor = isError
                  ? Colors.red
                  : isConnected
                  ? Colors.green
                  : theme.colorScheme.outline;

              return GestureDetector(
                onTap: () => onTap(s.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 10 : 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.8,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isActive ? 8 : 6,
                        height: isActive ? 8 : 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        }).toList(),
      ),
    );
  }
}

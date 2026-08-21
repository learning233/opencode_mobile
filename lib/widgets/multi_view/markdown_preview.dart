import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownPreviewPage extends StatelessWidget {
  final String title;
  final String content;

  const MarkdownPreviewPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16))),
      body: SafeArea(
        child: Markdown(
          data: content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: const TextStyle(fontSize: 15, height: 1.6),
            code: TextStyle(
              fontSize: 13,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onTapLink: (text, href, title) {
            if (href != null) {
              launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}

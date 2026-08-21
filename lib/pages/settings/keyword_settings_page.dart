import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../init.dart';
import '../../utils/translations.dart';

class KeywordSettingsPage extends StatefulWidget {
  const KeywordSettingsPage({super.key});

  @override
  State<KeywordSettingsPage> createState() => _KeywordSettingsPageState();
}

class _KeywordSettingsPageState extends State<KeywordSettingsPage> {
  final _newCtrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() {
      setState(() => _hasText = _newCtrl.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _addKeyword() async {
    final text = _newCtrl.text.trim();
    if (text.isEmpty || Global.keywordsRx.contains(text)) return;
    final next = [...Global.keywordsRx, text];
    await Global.saveKeywords(next);
    _newCtrl.clear();
  }

  Future<void> _removeKeyword(String keyword) async {
    final next = Global.keywordsRx.where((k) => k != keyword).toList();
    await Global.saveKeywords(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.mobileKeywords.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final keywords = Global.keywordsRx;
              if (keywords.isEmpty) {
                return Center(
                  child: Text(
                    LocaleKeys.mobileNoKeywordsYet.tr,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keywords.map((kw) {
                      return Chip(
                        label: Text(kw, style: const TextStyle(fontSize: 13)),
                        onDeleted: () => _removeKeyword(kw),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCtrl,
                    decoration: InputDecoration(
                      hintText: LocaleKeys.mobileAddKeywordHint.tr,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _hasText ? _addKeyword : null,
                  icon: const Icon(CupertinoIcons.add, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/translations.dart';
import '../api/models/settings.dart';
import '../controllers/settings_controller.dart';

class ProviderAuthSheet extends StatefulWidget {
  final String providerId;

  const ProviderAuthSheet({super.key, required this.providerId});

  @override
  State<ProviderAuthSheet> createState() => _ProviderAuthSheetState();
}

class _ProviderAuthSheetState extends State<ProviderAuthSheet> {
  final _keyCtrl = TextEditingController();
  List<ProviderAuthMethod> _methods = [];
  bool _loading = true;
  bool _connecting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    final ctrl = Get.find<SettingsController>();
    final methods = await ctrl.fetchProviderAuthMethods(widget.providerId);
    if (mounted) {
      setState(() {
        _methods = methods;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = Get.find<SettingsController>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Connect ${widget.providerId}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_methods.isEmpty)
              _buildKeyInput(ctrl)
            else
              _buildMethodList(ctrl, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyInput(SettingsController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _keyCtrl,
            decoration: InputDecoration(
              labelText: LocaleKeys.providersApiKey.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            obscureText: true,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _connecting ? null : () => _connectWithKey(ctrl),
            icon: _connecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link, size: 18),
            label: Text(LocaleKeys.mobileConnectWithApiKey.tr),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodList(SettingsController ctrl, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in _methods)
          if (m.type == 'oauth')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ctrl.connectProvider(widget.providerId);
                },
                icon: const Icon(Icons.login, size: 18),
                label: Text(
                  m.label.isNotEmpty
                      ? 'Connect with ${m.label}'
                      : 'Connect with OAuth',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
          else if (m.type == 'api')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyCtrl,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.providersApiKey.tr,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      obscureText: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: _connecting
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.link, size: 20),
                            onPressed: () => _connectWithKey(ctrl),
                          ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _connectWithKey(SettingsController ctrl) async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _connecting = true;
      _errorText = null;
    });
    try {
      final success = await ctrl.saveProviderKey(widget.providerId, key);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _errorText = 'Failed to connect');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = '$e');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}

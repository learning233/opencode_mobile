import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio_pkg;

import '../../../controllers/settings_controller.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/translations.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../widgets/settings/settings.dart';

class CustomProviderPage extends StatefulWidget {
  final SettingsController ctrl;
  final String? editProviderId;

  const CustomProviderPage({
    super.key,
    required this.ctrl,
    this.editProviderId,
  });

  @override
  State<CustomProviderPage> createState() => _CustomProviderPageState();
}

class _CustomProviderPageState extends State<CustomProviderPage> {
  final _providerIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _jsonCtrl = TextEditingController();

  final _models = <_CustomModelRow>[];
  final _headers = <_CustomHeaderRow>[];
  final _errors = <String, String>{};

  List<String> _fetchedModelIds = [];
  bool _fetchingModels = false;
  bool _saving = false;
  String _selectedNpm = '@ai-sdk/openai-compatible';

  Map<String, dynamic> _originalJson = {};

  String? _jsonError;
  bool _isUpdatingFromJson = false;
  bool _isUpdatingFromFields = false;

  /// 编辑模式且配置拉取在途时为 true，抑制字段→JSON 重建，
  /// 防止空字段抢先填入 JSON 编辑框。
  bool _loadingInitialConfig = false;

  static const _debounceDuration = Duration(milliseconds: 300);
  Timer? _fieldsDebounce;
  Timer? _jsonDebounce;

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  void _flushPendingDebounces() {
    if (_fieldsDebounce?.isActive ?? false) {
      _fieldsDebounce!.cancel();
      _rebuildJsonFromFields();
    }
    if (_jsonDebounce?.isActive ?? false) {
      _jsonDebounce!.cancel();
      _rebuildFieldsFromJson();
    }
  }

  @override
  void initState() {
    super.initState();

    _providerIdCtrl.addListener(_onFieldChanged);
    _nameCtrl.addListener(_onFieldChanged);
    _baseUrlCtrl.addListener(_onFieldChanged);
    _apiKeyCtrl.addListener(_onFieldChanged);

    _jsonCtrl.addListener(_onJsonChanged);

    if (widget.editProviderId != null) {
      final config =
          widget.ctrl.globalConfig.value?['provider']?[widget.editProviderId!];
      if (config is Map<String, dynamic>) {
        _providerIdCtrl.text = widget.editProviderId!;
        _updateFieldsFromJson(config);
      } else {
        // globalConfig 尚未拉取时兜底获取一次，避免编辑页拿到空配置。
        // 抑制标志须在 _providerIdCtrl 赋值前置位：赋值会同步触发监听。
        _loadingInitialConfig = true;
        _providerIdCtrl.text = widget.editProviderId!;
        _loadProviderConfig();
      }
    } else {
      final m = _CustomModelRow();
      m.id.addListener(_onFieldChanged);
      m.name.addListener(_onFieldChanged);
      _models.add(m);
    }

    _onFieldChanged();
  }

  /// 编辑模式进入时 globalConfig 可能尚未拉取（本页可直接导航进入），
  /// 拉取成功后回填原配置。
  Future<void> _loadProviderConfig() async {
    try {
      await widget.ctrl.fetchGlobalConfig();
    } catch (e) {
      AppLogger.w('custom provider: fetch config for edit failed: $e');
      _finishInitialConfigLoad();
      return;
    }
    if (!mounted) {
      _loadingInitialConfig = false;
      return;
    }
    final config =
        widget.ctrl.globalConfig.value?['provider']?[widget.editProviderId!];
    if (config is Map<String, dynamic>) {
      setState(() => _updateFieldsFromJson(config));
    }
    _finishInitialConfigLoad();
  }

  /// 回填（或拉取失败）后解除抑制并按当前字段重建一次 JSON：
  /// 抑制期间字段监听被吞，需显式触发。
  void _finishInitialConfigLoad() {
    _loadingInitialConfig = false;
    if (mounted) _rebuildJsonFromFields();
  }

  @override
  void dispose() {
    _fieldsDebounce?.cancel();
    _jsonDebounce?.cancel();
    _providerIdCtrl.dispose();
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _jsonCtrl.dispose();
    for (final model in _models) {
      model.dispose();
    }
    for (final header in _headers) {
      header.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    if (_isUpdatingFromJson || _loadingInitialConfig) return;
    _fieldsDebounce?.cancel();
    _fieldsDebounce = Timer(_debounceDuration, _rebuildJsonFromFields);
  }

  void _rebuildJsonFromFields() {
    _isUpdatingFromFields = true;
    try {
      final jsonMap = _buildJsonFromFields();
      const encoder = JsonEncoder.withIndent('  ');
      _jsonCtrl.text = encoder.convert(jsonMap);
      _jsonError = null;
    } catch (e) {
      _jsonError = e.toString();
    }
    _isUpdatingFromFields = false;
    if (mounted) setState(() {});
  }

  void _onJsonChanged() {
    if (_isUpdatingFromFields) return;
    _jsonDebounce?.cancel();
    _jsonDebounce = Timer(_debounceDuration, _rebuildFieldsFromJson);
  }

  void _rebuildFieldsFromJson() {
    _isUpdatingFromJson = true;
    try {
      final text = _jsonCtrl.text.trim();
      if (text.isEmpty) {
        setState(() {
          _jsonError = null;
        });
        _isUpdatingFromJson = false;
        return;
      }
      final dynamic parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _jsonError = null;
          _updateFieldsFromJson(parsed);
        });
      } else {
        setState(() {
          _jsonError = 'JSON must be a Map';
        });
      }
    } catch (e) {
      setState(() {
        _jsonError = e.toString();
      });
    }
    _isUpdatingFromJson = false;
  }

  Map<String, dynamic> _buildJsonFromFields() {
    final name = _nameCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final envMatch = RegExp(
      r'^\{env:([^}]+)\}$',
    ).firstMatch(_apiKeyCtrl.text.trim());
    final envName = envMatch?.group(1)?.trim();

    final modelsMap = <String, dynamic>{};
    for (final row in _models) {
      final modelId = row.id.text.trim();
      final modelName = row.name.text.trim();
      if (modelId.isNotEmpty) {
        modelsMap[modelId] = <String, dynamic>{
          'name': modelName.isNotEmpty ? modelName : modelId,
          'modalities': {
            'input': [
              if (row.supportsTextInput) 'text',
              if (row.supportsImageInput) 'image',
            ],
            'output': ['text'],
          },
          if (row.extraJson != null) ...row.extraJson!,
        };
      }
    }

    final headersMap = <String, String>{};
    for (final row in _headers) {
      final key = row.key.text.trim();
      final value = row.value.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        headersMap[key] = value;
      }
    }

    final optionsBase = <String, dynamic>{'baseURL': baseUrl};
    if (headersMap.isNotEmpty) {
      optionsBase['headers'] = headersMap;
    }
    final originalOptions = _originalJson['options'];
    if (originalOptions is Map) {
      for (final key in originalOptions.keys) {
        if (!optionsBase.containsKey(key)) {
          optionsBase[key] = originalOptions[key];
        }
      }
    }
    if (_originalJson.isEmpty && !optionsBase.containsKey('setCacheKey')) {
      optionsBase['setCacheKey'] = true;
    }

    final result = <String, dynamic>{
      'npm': _selectedNpm,
      'name': name.isNotEmpty ? name : _providerIdCtrl.text.trim(),
      if (envName != null && envName.isNotEmpty) 'env': [envName],
      'options': optionsBase,
      'models': modelsMap,
    };
    for (final key in _originalJson.keys) {
      if (key == 'env') continue;
      if (!result.containsKey(key)) {
        result[key] = _originalJson[key];
      }
    }
    return result;
  }

  void _updateFieldsFromJson(Map<String, dynamic> jsonMap) {
    _originalJson = Map<String, dynamic>.from(jsonMap);
    final npm = jsonMap['npm']?.toString() ?? '@ai-sdk/openai-compatible';
    if (_selectedNpm != npm) {
      _selectedNpm = npm;
    }

    final name = jsonMap['name']?.toString() ?? '';
    if (_nameCtrl.text != name) {
      _nameCtrl.text = name;
    }

    final optionsVal = jsonMap['options'];
    final options = optionsVal is Map
        ? Map<String, dynamic>.from(optionsVal)
        : <String, dynamic>{};
    final baseUrl = options['baseURL']?.toString() ?? '';
    if (_baseUrlCtrl.text != baseUrl) {
      _baseUrlCtrl.text = baseUrl;
    }

    final envList = jsonMap['env'];
    if (envList is List && envList.isNotEmpty) {
      final envVal = '{env:${envList.first}}';
      if (_apiKeyCtrl.text != envVal) {
        _apiKeyCtrl.text = envVal;
      }
    }

    final headersVal = options['headers'];
    final headers = headersVal is Map
        ? Map<String, dynamic>.from(headersVal)
        : <String, dynamic>{};
    for (final h in _headers) {
      h.dispose();
    }
    _headers.clear();
    headers.forEach((k, v) {
      final h = _CustomHeaderRow();
      h.key.text = k.toString();
      h.value.text = v.toString();
      h.key.addListener(_onFieldChanged);
      h.value.addListener(_onFieldChanged);
      _headers.add(h);
    });
    if (_headers.isEmpty) {
      final h = _CustomHeaderRow();
      h.key.addListener(_onFieldChanged);
      h.value.addListener(_onFieldChanged);
      _headers.add(h);
    }

    final modelsVal = jsonMap['models'];
    final models = modelsVal is Map
        ? Map<String, dynamic>.from(modelsVal)
        : <String, dynamic>{};
    for (final m in _models) {
      m.dispose();
    }
    _models.clear();
    models.forEach((k, v) {
      final m = _CustomModelRow();
      m.id.text = k.toString();
      m.id.addListener(_onFieldChanged);
      m.name.addListener(_onFieldChanged);
      if (v is Map) {
        m.name.text = v['name']?.toString() ?? k.toString();
        if (v['modalities'] is Map) {
          final input = v['modalities']['input'];
          if (input is List) {
            m.supportsTextInput = input.contains('text');
            m.supportsImageInput = input.contains('image');
          }
        }
        final extras = Map<String, dynamic>.from(v)
          ..removeWhere((k, _) => k == 'name' || k == 'modalities');
        if (extras.isNotEmpty) m.extraJson = extras;
      } else {
        m.name.text = v.toString();
      }
      _models.add(m);
    });
    if (_models.isEmpty) {
      final m = _CustomModelRow();
      m.id.addListener(_onFieldChanged);
      m.name.addListener(_onFieldChanged);
      _models.add(m);
    }
  }

  Future<void> _fetchModelsFromApi() async {
    _flushPendingDebounces();
    final baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.isEmpty) {
      Snack.error(
        '${LocaleKeys.providersBaseUrl.tr} ${LocaleKeys.required.tr}',
      );
      return;
    }
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      Snack.error(LocaleKeys.providersBaseUrlError.tr);
      return;
    }
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      Snack.error(LocaleKeys.providersApiKeyRequired.tr);
      return;
    }

    setState(() {
      _fetchingModels = true;
    });

    try {
      String url = baseUrl;
      if (!url.endsWith('/models') && !url.endsWith('/models/')) {
        if (url.endsWith('/')) {
          url += 'models';
        } else {
          url += '/models';
        }
      }

      final dioClient = dio_pkg.Dio(
        dio_pkg.BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final reqHeaders = <String, String>{};
      if (apiKey.isNotEmpty) {
        reqHeaders['Authorization'] = 'Bearer $apiKey';
      }
      for (final row in _headers) {
        final k = row.key.text.trim();
        final v = row.value.text.trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          reqHeaders[k] = v;
        }
      }

      final response = await dioClient.get(
        url,
        options: dio_pkg.Options(headers: reqHeaders),
      );
      if (!mounted) return;

      final foundIds = <String>[];
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          for (final item in data['data']) {
            if (item is Map && item['id'] != null) {
              foundIds.add(item['id'].toString());
            }
          }
        } else if (data is List) {
          for (final item in data) {
            if (item is Map && item['id'] != null) {
              foundIds.add(item['id'].toString());
            } else if (item is String) {
              foundIds.add(item);
            }
          }
        }
      }

      if (foundIds.isEmpty) {
        throw Exception(LocaleKeys.providersFetchNoModels.tr);
      }

      setState(() {
        _fetchedModelIds = foundIds;
      });
      Snack.success(
        LocaleKeys.providersFetchSuccess.trParams({
          'count': foundIds.length.toString(),
        }),
      );

      if (_models.length == 1 && _models.first.id.text.isEmpty) {
        _models.first.id.text = foundIds.first;
        _models.first.name.text = foundIds.first;
        _onFieldChanged();
      }
    } catch (e) {
      Snack.error('${LocaleKeys.providersFetchFailed.tr}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _fetchingModels = false;
        });
      }
    }
  }

  void _formatJson() {
    try {
      final text = _jsonCtrl.text.trim();
      if (text.isEmpty) return;
      final parsed = jsonDecode(text);
      const encoder = JsonEncoder.withIndent('  ');
      _jsonCtrl.text = encoder.convert(parsed);
      setState(() {
        _jsonError = null;
      });
    } catch (e) {
      setState(() {
        _jsonError = 'Format error: $e';
      });
    }
  }

  void _clearError(String key) {
    if (!_errors.containsKey(key)) return;
    setState(() => _errors.remove(key));
  }

  void _addModel() {
    setState(() {
      final row = _CustomModelRow();
      row.id.addListener(_onFieldChanged);
      row.name.addListener(_onFieldChanged);
      _models.add(row);
      _onFieldChanged();
    });
  }

  void _removeModel(int index) {
    if (_models.length <= 1) return;
    setState(() {
      _models.removeAt(index).dispose();
      _onFieldChanged();
    });
  }

  void _addHeader() {
    setState(() {
      final row = _CustomHeaderRow();
      row.key.addListener(_onFieldChanged);
      row.value.addListener(_onFieldChanged);
      _headers.add(row);
      _onFieldChanged();
    });
  }

  void _removeHeader(int index) {
    if (_headers.length <= 1) return;
    setState(() {
      _headers.removeAt(index).dispose();
      _onFieldChanged();
    });
  }

  Future<void> _save() async {
    _flushPendingDebounces();
    final providerId = _providerIdCtrl.text.trim();
    final errors = <String, String>{};

    if (providerId.isEmpty) {
      errors['providerId'] = LocaleKeys.required.tr;
    } else if (!RegExp(r'^[a-z0-9][a-z0-9-_]*$').hasMatch(providerId)) {
      errors['providerId'] = LocaleKeys.providersProviderIdError.tr;
    } else if (widget.editProviderId != providerId &&
        widget.ctrl.providers.any((p) => p.id == providerId) &&
        !widget.ctrl.disabledProviders.contains(providerId)) {
      errors['providerId'] = LocaleKeys.providersProviderExists.tr;
    }

    if (_jsonCtrl.text.trim().isEmpty) {
      setState(() {
        _jsonError = 'cannot be empty';
      });
      return;
    }

    Map<String, dynamic> parsedConfig;
    try {
      final decoded = jsonDecode(_jsonCtrl.text.trim());
      if (decoded is! Map<String, dynamic>) {
        throw Exception('must be a JSON object');
      }
      parsedConfig = decoded;
    } catch (e) {
      setState(() {
        _jsonError = 'parse error: $e';
      });
      return;
    }

    final options = parsedConfig['options'];
    final baseUrl = options is Map ? options['baseURL']?.toString() ?? '' : '';

    if (_selectedNpm == '@ai-sdk/openai-compatible') {
      if (baseUrl.isEmpty) {
        errors['baseUrl'] = LocaleKeys.required.tr;
      } else if (!baseUrl.startsWith('http://') &&
          !baseUrl.startsWith('https://')) {
        errors['baseUrl'] = LocaleKeys.providersBaseUrlError.tr;
      }
    } else {
      if (baseUrl.isNotEmpty &&
          !baseUrl.startsWith('http://') &&
          !baseUrl.startsWith('https://')) {
        errors['baseUrl'] = LocaleKeys.providersBaseUrlError.tr;
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() => _saving = true);

    final ok = await widget.ctrl.addCustomProviderRaw(
      providerId: providerId,
      config: parsedConfig,
      apiKey: _apiKeyCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      await widget.ctrl.fetchProviders(force: true);
      if (!mounted) return;
      Get.back();
    } else {
      Snack.error(LocaleKeys.providersSaveFailed.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? PremiumColors.darkBackground
          : PremiumColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.editProviderId != null
              ? LocaleKeys.providersConfigEdit.tr
              : LocaleKeys.customProvider.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: LocaleKeys.customProvider.tr),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      if (_isMobile) ...[
                        _DialogField(
                          controller: _providerIdCtrl,
                          placeholder:
                              LocaleKeys.providersProviderIdPlaceholder.tr,
                          error: _errors['providerId'],
                          onChanged: (_) => _clearError('providerId'),
                          readOnly: widget.editProviderId != null,
                        ),
                        const SizedBox(height: 10),
                        _DialogField(
                          controller: _nameCtrl,
                          placeholder: LocaleKeys.providersNamePlaceholder.tr,
                          error: _errors['name'],
                          onChanged: (_) => _clearError('name'),
                        ),
                        const SizedBox(height: 10),
                        _DropdownField(
                          value: _selectedNpm,
                          items: const [
                            DropdownMenuItem(
                              value: '@ai-sdk/openai-compatible',
                              child: Text('OpenAI Compatible'),
                            ),
                            DropdownMenuItem(
                              value: '@ai-sdk/openai',
                              child: Text('OpenAI Responses'),
                            ),
                            DropdownMenuItem(
                              value: '@ai-sdk/anthropic',
                              child: Text('Anthropic'),
                            ),
                            DropdownMenuItem(
                              value: '@ai-sdk/google',
                              child: Text('Google (Gemini)'),
                            ),
                            DropdownMenuItem(
                              value: '@ai-sdk/amazon-bedrock',
                              child: Text('Amazon Bedrock'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedNpm = val;
                              });
                              _onFieldChanged();
                            }
                          },
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _DialogField(
                                controller: _providerIdCtrl,
                                placeholder: LocaleKeys
                                    .providersProviderIdPlaceholder
                                    .tr,
                                error: _errors['providerId'],
                                onChanged: (_) => _clearError('providerId'),
                                readOnly: widget.editProviderId != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DialogField(
                                controller: _nameCtrl,
                                placeholder:
                                    LocaleKeys.providersNamePlaceholder.tr,
                                error: _errors['name'],
                                onChanged: (_) => _clearError('name'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DropdownField(
                                value: _selectedNpm,
                                items: const [
                                  DropdownMenuItem(
                                    value: '@ai-sdk/openai-compatible',
                                    child: Text('OpenAI Compatible'),
                                  ),
                                  DropdownMenuItem(
                                    value: '@ai-sdk/openai',
                                    child: Text('OpenAI Responses'),
                                  ),
                                  DropdownMenuItem(
                                    value: '@ai-sdk/anthropic',
                                    child: Text('Anthropic'),
                                  ),
                                  DropdownMenuItem(
                                    value: '@ai-sdk/google',
                                    child: Text('Google (Gemini)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '@ai-sdk/amazon-bedrock',
                                    child: Text('Amazon Bedrock'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedNpm = val;
                                    });
                                    _onFieldChanged();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      if (_isMobile) ...[
                        _DialogField(
                          controller: _baseUrlCtrl,
                          placeholder:
                              LocaleKeys.providersBaseUrlPlaceholder.tr,
                          error: _errors['baseUrl'],
                          onChanged: (_) => _clearError('baseUrl'),
                        ),
                        const SizedBox(height: 10),
                        _DialogField(
                          controller: _apiKeyCtrl,
                          placeholder: LocaleKeys.providersApiKeyPlaceholder.tr,
                          obscureText: true,
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _DialogField(
                                controller: _baseUrlCtrl,
                                placeholder:
                                    LocaleKeys.providersBaseUrlPlaceholder.tr,
                                error: _errors['baseUrl'],
                                onChanged: (_) => _clearError('baseUrl'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DialogField(
                                controller: _apiKeyCtrl,
                                placeholder:
                                    LocaleKeys.providersApiKeyPlaceholder.tr,
                                obscureText: true,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(LocaleKeys.models.tr),
                Row(
                  children: [
                    if (_fetchingModels)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _fetchModelsFromApi,
                        icon: const Icon(Icons.refresh, size: 12),
                        label: Text(
                          LocaleKeys.providersFetchModels.tr,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    const SizedBox(width: 5),
                    TextButton.icon(
                      onPressed: _addModel,
                      icon: const Icon(CupertinoIcons.add, size: 12),
                      label: Text(
                        LocaleKeys.providersAddModel.tr,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._models.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return _ModelInputRow(
                row: row,
                canRemove: _models.length > 1,
                onRemove: () => _removeModel(index),
                fetchedModelIds: _fetchedModelIds,
                onChanged: _onFieldChanged,
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(LocaleKeys.headers.tr),
                TextButton.icon(
                  onPressed: _addHeader,
                  icon: const Icon(CupertinoIcons.add, size: 12),
                  label: Text(
                    LocaleKeys.providersAddHeader.tr,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._headers.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return _HeaderInputRow(
                row: row,
                canRemove: _headers.length > 1,
                onRemove: () => _removeHeader(index),
                onChanged: _onFieldChanged,
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(LocaleKeys.providersJsonConfig.tr),
                TextButton.icon(
                  onPressed: _formatJson,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(CupertinoIcons.sparkles, size: 12),
                  label: Text(
                    LocaleKeys.providersFormatJson.tr,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _JsonEditorWithLineNumbers(
              controller: _jsonCtrl,
              error: _jsonError,
            ),
            if (_jsonError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  LocaleKeys.providersJsonError.trParams({
                    'error': _jsonError ?? '',
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      LocaleKeys.ok.tr,
                      style: const TextStyle(fontSize: 14),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CustomModelRow {
  final id = TextEditingController();
  final name = TextEditingController();
  bool supportsTextInput = true;
  bool supportsImageInput = false;
  Map<String, dynamic>? extraJson;
  String? idError;
  String? nameError;

  void dispose() {
    id.dispose();
    name.dispose();
  }
}

class _CustomHeaderRow {
  final key = TextEditingController();
  final value = TextEditingController();
  String? keyError;
  String? valueError;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: PremiumColors.secondaryText(theme.brightness),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final String? error;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const _DialogField({
    required this.controller,
    required this.placeholder,
    this.error,
    this.obscureText = false,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly
                ? theme.disabledColor
                : theme.textTheme.bodyMedium?.color,
            fontSize: 12,
          ),
          decoration: BoxDecoration(
            color: readOnly
                ? theme.disabledColor.withValues(alpha: 0.05)
                : PremiumColors.inputBg(theme.brightness),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: error == null
                  ? theme.colorScheme.outline.withValues(alpha: 0.2)
                  : theme.colorScheme.error,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          onChanged: onChanged,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12),
      decoration: InputDecoration(
        fillColor: PremiumColors.inputBg(theme.brightness),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _ModelInputRow extends StatelessWidget {
  final _CustomModelRow row;
  final bool canRemove;
  final VoidCallback onRemove;
  final List<String> fetchedModelIds;
  final VoidCallback onChanged;

  const _ModelInputRow({
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.fetchedModelIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final idField = fetchedModelIds.isEmpty
        ? _DialogField(
            controller: row.id,
            placeholder: 'model-id',
            error: row.idError,
            onChanged: (_) => onChanged(),
          )
        : DropdownButtonFormField<String>(
            initialValue: row.id.text.isEmpty
                ? fetchedModelIds.first
                : row.id.text,
            items: fetchedModelIds
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                row.id.text = val;
                if (row.name.text.isEmpty) {
                  row.name.text = val;
                }
                onChanged();
              }
            },
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              fillColor: PremiumColors.inputBg(theme.brightness),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          );

    final nameField = _DialogField(
      controller: row.name,
      placeholder: 'Model Name',
      error: row.nameError,
      onChanged: (_) => onChanged(),
    );

    final toggleGroup = _buildModalityToggleGroup(context, theme);

    final deleteButton = IconButton(
      icon: const Icon(Icons.delete, size: 16),
      onPressed: canRemove ? onRemove : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: idField),
                  const SizedBox(width: 8),
                  deleteButton,
                ],
              ),
              const SizedBox(height: 8),
              nameField,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: toggleGroup),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: idField),
          const SizedBox(width: 8),
          Expanded(child: nameField),
          const SizedBox(width: 8),
          toggleGroup,
          const SizedBox(width: 4),
          deleteButton,
        ],
      ),
    );
  }

  Widget _buildModalityToggleGroup(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModalityButton(
            theme: theme,
            label: 'Text',
            isSelected: row.supportsTextInput,
            onTap: () {
              row.supportsTextInput = !row.supportsTextInput;
              onChanged();
            },
            isLeft: true,
          ),
          Container(
            width: 0.8,
            height: 16,
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
          _buildModalityButton(
            theme: theme,
            label: 'Image',
            isSelected: row.supportsImageInput,
            onTap: () {
              row.supportsImageInput = !row.supportsImageInput;
              onChanged();
            },
            isLeft: false,
          ),
        ],
      ),
    );
  }

  Widget _buildModalityButton({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(5) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(5) : Radius.zero,
            topRight: !isLeft ? const Radius.circular(5) : Radius.zero,
            bottomRight: !isLeft ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _HeaderInputRow extends StatelessWidget {
  final _CustomHeaderRow row;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _HeaderInputRow({
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final keyField = _DialogField(
      controller: row.key,
      placeholder: 'Header',
      error: row.keyError,
      onChanged: (_) => onChanged(),
    );

    final valueField = _DialogField(
      controller: row.value,
      placeholder: 'Value',
      error: row.valueError,
      onChanged: (_) => onChanged(),
    );

    final deleteButton = IconButton(
      icon: const Icon(Icons.delete, size: 16),
      onPressed: canRemove ? onRemove : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: keyField),
                  const SizedBox(width: 8),
                  deleteButton,
                ],
              ),
              const SizedBox(height: 8),
              valueField,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: keyField),
          const SizedBox(width: 8),
          Expanded(child: valueField),
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

class _JsonEditorWithLineNumbers extends StatefulWidget {
  final TextEditingController controller;
  final String? error;

  const _JsonEditorWithLineNumbers({required this.controller, this.error});

  @override
  State<_JsonEditorWithLineNumbers> createState() =>
      _JsonEditorWithLineNumbersState();
}

class _JsonEditorWithLineNumbersState
    extends State<_JsonEditorWithLineNumbers> {
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLineCount);
    _updateLineCount();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineCount);
    super.dispose();
  }

  void _updateLineCount() {
    final text = widget.controller.text;
    final count = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
    if (count != _lineCount) {
      setState(() => _lineCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const lineHeight = 1.4;
    final baseStyle = const TextStyle(fontFamily: 'monospace', fontSize: 14);

    return Container(
      decoration: BoxDecoration(
        color: PremiumColors.inputBg(theme.brightness),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.error == null
              ? theme.colorScheme.outline.withValues(alpha: 0.2)
              : theme.colorScheme.error,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            padding: const EdgeInsets.fromLTRB(4, 10, 6, 10),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              children: [
                for (int i = 1; i <= _lineCount; i++)
                  Text(
                    '$i',
                    style: baseStyle.copyWith(
                      height: lineHeight,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              minLines: 5,
              style: baseStyle.copyWith(
                height: lineHeight,
                color: theme.textTheme.bodyMedium?.color,
              ),
              strutStyle: StrutStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: lineHeight,
                forceStrutHeight: true,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

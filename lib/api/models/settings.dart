/// Information about a single model offered by a provider.
class ProviderModelInfo {
  /// Model identifier (e.g. "gpt-4", "claude-3-opus").
  final String id;

  /// Human-readable display name for the model.
  final String name;

  ProviderModelInfo({required this.id, required this.name});

  /// Creates a [ProviderModelInfo] from a JSON map.
  factory ProviderModelInfo.fromJson(Map<String, dynamic> json) {
    return ProviderModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
    );
  }
}

/// Information about an API provider (e.g. OpenAI, Anthropic).
class ProviderInfo {
  /// Provider identifier.
  final String id;

  /// Human-readable provider name.
  final String name;

  /// Provider source type (e.g. "openai", "anthropic").
  final String type;

  /// Whether the provider is currently connected and usable.
  final bool connected;

  /// Available models offered by this provider.
  final List<ProviderModelInfo> models;

  ProviderInfo({
    required this.id,
    required this.name,
    this.type = '',
    this.connected = false,
    this.models = const [],
  });

  /// Convenience getter that returns a list of model IDs.
  List<String> get modelIds => models.map((m) => m.id).toList();

  /// Creates a [ProviderInfo] from a JSON map.
  ///
  /// Models are expected as a nested map keyed by model ID.
  factory ProviderInfo.fromJson(Map<String, dynamic> json) {
    final modelsRaw = json['models'] as Map<String, dynamic>? ?? {};
    final modelsList = modelsRaw.entries.map((entry) {
      final modelMap = entry.value as Map<String, dynamic>? ?? {};
      return ProviderModelInfo.fromJson({...modelMap, 'id': entry.key});
    }).toList();

    return ProviderInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      type: json['source'] as String? ?? json['type'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      models: modelsList,
    );
  }
}

class ProviderAuthPrompt {
  final String type;
  final String key;
  final String message;
  final String placeholder;
  final List<ProviderAuthSelectOption> options;
  final Map<String, dynamic>? when;

  ProviderAuthPrompt({
    required this.type,
    required this.key,
    required this.message,
    this.placeholder = '',
    this.options = const [],
    this.when,
  });

  factory ProviderAuthPrompt.fromJson(Map<dynamic, dynamic> json) {
    final rawOptions = json['options'];
    return ProviderAuthPrompt(
      type: json['type']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      placeholder: json['placeholder']?.toString() ?? '',
      options: rawOptions is List
          ? rawOptions
                .whereType<Map>()
                .map((item) => ProviderAuthSelectOption.fromJson(item))
                .toList()
          : const [],
      when: json['when'] is Map
          ? Map<String, dynamic>.from(json['when'] as Map)
          : null,
    );
  }
}

class ProviderAuthSelectOption {
  final String label;
  final String value;
  final String hint;

  ProviderAuthSelectOption({
    required this.label,
    required this.value,
    this.hint = '',
  });

  factory ProviderAuthSelectOption.fromJson(Map<dynamic, dynamic> json) =>
      ProviderAuthSelectOption(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        hint: json['hint']?.toString() ?? '',
      );
}

class ProviderAuthMethod {
  final String type;
  final String label;
  final List<ProviderAuthPrompt> prompts;

  ProviderAuthMethod({
    required this.type,
    required this.label,
    this.prompts = const [],
  });

  factory ProviderAuthMethod.fromJson(Map<dynamic, dynamic> json) {
    final rawPrompts = json['prompts'];
    return ProviderAuthMethod(
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      prompts: rawPrompts is List
          ? rawPrompts
                .whereType<Map>()
                .map((item) => ProviderAuthPrompt.fromJson(item))
                .toList()
          : const [],
    );
  }
}

class ProviderAuthorization {
  final String url;
  final String method;
  final String instructions;

  ProviderAuthorization({
    required this.url,
    required this.method,
    required this.instructions,
  });

  factory ProviderAuthorization.fromJson(Map<String, dynamic> json) =>
      ProviderAuthorization(
        url: json['url'] as String? ?? '',
        method: json['method'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
      );
}

/// Information about a connected MCP (Model Context Protocol) server.
class McpServerInfo {
  /// Server name as defined in the configuration.
  final String name;

  /// Server type: "local" (command-based) or "remote" (URL-based).
  final String type;

  /// Whether the server is currently connected.
  final bool connected;

  /// Detailed connection status string (e.g. "connected", "disconnected").
  final String status;

  /// List of tool names exposed by this MCP server.
  final List<String> tools;

  /// Launch command for local servers (e.g. "npx", "uvx").
  final String? command;

  /// Command-line arguments joined into a single string.
  final String? args;

  /// Base URL for remote servers.
  final String? url;

  /// Environment variables passed to the server process.
  final Map<String, dynamic>? env;

  /// Raw JSON data received from the backend.
  final Map<String, dynamic> raw;

  McpServerInfo({
    required this.name,
    this.type = '',
    this.connected = false,
    this.status = 'disconnected',
    this.tools = const [],
    this.command = '',
    this.args = '',
    this.url = '',
    this.env,
    this.raw = const {},
  });

  /// Creates an [McpServerInfo] from its name and JSON map.
  ///
  /// Automatically infers [type] from the presence of a "command" field
  /// and [status] from the "connected" field when not explicitly provided.
  factory McpServerInfo.fromJson(String name, Map<String, dynamic> json) {
    return McpServerInfo(
      name: name,
      type:
          json['type'] as String? ??
          json['source'] as String? ??
          (json.containsKey('command') ? 'local' : 'remote'),
      connected: json['connected'] as bool? ?? false,
      status:
          json['status'] as String? ??
          (json['connected'] == true ? 'connected' : 'disconnected'),
      tools:
          (json['tools'] as List?)
              ?.map(
                (e) => e is Map
                    ? (e['name'] ?? e.toString()).toString()
                    : e.toString(),
              )
              .toList() ??
          [],
      command: json['command'] as String?,
      args: json['args'] is List
          ? (json['args'] as List).map((e) => e.toString()).join(' ')
          : json['args'] as String?,
      url: json['url'] as String? ?? '',
      env: json['environment'] is Map
          ? Map<String, dynamic>.from(json['environment'] as Map)
          : json['env'] is Map
          ? Map<String, dynamic>.from(json['env'] as Map)
          : null,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Detailed configuration for an agent in the multi-agent system.
class AgentDetailInfo {
  /// Agent name (e.g. "Code", "Explorer").
  final String name;

  /// Model identifier assigned to this agent.
  final String model;

  /// Model variant (e.g. "thinking", "fast").
  final String variant;

  /// Sampling temperature for model generation.
  final double temperature;

  /// Nucleus sampling top-p parameter.
  final double topP;

  /// Maximum number of steps or iterations the agent may take.
  final int steps;

  /// Agent mode: "primary" (default) or "secondary".
  final String mode;

  /// Whether this agent is disabled.
  final bool disable;

  /// Human-readable description of the agent's purpose.
  final String description;

  /// System prompt used to configure the agent's behavior.
  final String prompt;

  /// Raw JSON data received from the backend.
  final Map<String, dynamic> raw;

  AgentDetailInfo({
    required this.name,
    this.model = '',
    this.variant = '',
    this.temperature = 0.0,
    this.topP = 1.0,
    this.steps = 0,
    this.mode = 'primary',
    this.disable = false,
    this.description = '',
    this.prompt = '',
    this.raw = const {},
  });

  /// Creates an [AgentDetailInfo] from an agent name and JSON map.
  ///
  /// Accepts snake_case keys from the backend (e.g. "top_p", "max_iterations")
  /// and V2 protocol fields (e.g. "id", "system", "hidden", model as object).
  factory AgentDetailInfo.fromJson(String name, Map<String, dynamic> json) {
    final effectiveName = name.isNotEmpty
        ? name
        : (json['id']?.toString() ?? '');

    String resolveModel(dynamic value) {
      if (value is String) return value;
      if (value is Map) {
        final pid = value['providerID']?.toString() ?? '';
        final mid =
            value['id']?.toString() ?? value['modelID']?.toString() ?? '';
        if (pid.isNotEmpty && mid.isNotEmpty) return '$pid/$mid';
        if (mid.isNotEmpty) return mid;
      }
      return '';
    }

    return AgentDetailInfo(
      name: effectiveName,
      model: resolveModel(json['model']),
      variant: json['variant'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      topP:
          (json['top_p'] as num?)?.toDouble() ??
          (json['topP'] as num?)?.toDouble() ??
          1.0,
      steps:
          json['steps'] as int? ??
          json['maxIterations'] as int? ??
          json['max_iterations'] as int? ??
          0,
      mode: json['mode'] as String? ?? 'primary',
      disable:
          json['disable'] as bool? ??
          json['disabled'] as bool? ??
          json['hidden'] as bool? ??
          false,
      description: json['description'] as String? ?? '',
      prompt:
          json['prompt'] as String? ??
          json['systemPrompt'] as String? ??
          json['system_prompt'] as String? ??
          json['system'] as String? ??
          '',
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Creates a copy with the given fields replaced by new values.
  AgentDetailInfo copyWith({
    String? model,
    String? variant,
    double? temperature,
    double? topP,
    int? steps,
    String? mode,
    bool? disable,
    String? description,
    String? prompt,
  }) {
    return AgentDetailInfo(
      name: name,
      model: model ?? this.model,
      variant: variant ?? this.variant,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      steps: steps ?? this.steps,
      mode: mode ?? this.mode,
      disable: disable ?? this.disable,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      raw: raw,
    );
  }

  /// Serializes this agent configuration to a JSON map.
  ///
  /// Only includes non-default values (empty strings, zero values, and
  /// default parameters are omitted to keep the configuration clean).
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(raw);
    json.remove('name');

    void setOrRemove(String key, Object? value, bool shouldSet) {
      if (shouldSet) {
        json[key] = value;
      } else {
        json.remove(key);
      }
    }

    setOrRemove('model', model, model.isNotEmpty);
    setOrRemove('variant', variant, variant.isNotEmpty);
    setOrRemove('temperature', temperature, temperature > 0);
    setOrRemove('top_p', topP, topP < 1.0);
    setOrRemove('steps', steps, steps > 0);
    setOrRemove('description', description, description.isNotEmpty);
    setOrRemove('prompt', prompt, prompt.isNotEmpty);
    json['mode'] = mode;
    json['disable'] = disable;
    return json;
  }
}

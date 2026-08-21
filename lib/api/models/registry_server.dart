/// A package definition from a registry server.
///
/// Describes how to install and run an MCP server from a package registry
/// (npm, PyPI, Docker/OCI, etc.).
class RegistryPackage {
  /// Registry type: "npm", "pypi", "oci", etc.
  final String registryType;

  /// Package identifier (e.g. package name or image reference).
  final String identifier;

  /// Optional package version constraint.
  final String? version;

  /// Hint for the runtime to use (e.g. "npx", "uvx").
  final String? runtimeHint;

  /// Arguments passed to the runtime tool.
  final List<String>? runtimeArgs;

  /// Arguments passed to the package itself.
  final List<String>? packageArgs;

  /// Transport protocol type ("stdio" or "sse").
  final String? transport;

  /// Environment variables required or used by this package.
  final List<RegistryEnvVar>? environmentVariables;

  RegistryPackage({
    required this.registryType,
    required this.identifier,
    this.version,
    this.runtimeHint,
    this.runtimeArgs,
    this.packageArgs,
    this.transport,
    this.environmentVariables,
  });

  /// Creates a [RegistryPackage] from a JSON map.
  factory RegistryPackage.fromJson(Map<String, dynamic> json) {
    List<String> parseArgs(dynamic raw) {
      if (raw is List) {
        return raw.map((e) {
          if (e is Map) return e['value'] as String? ?? e.toString();
          return e.toString();
        }).toList();
      }
      return [];
    }

    return RegistryPackage(
      registryType: json['registryType'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      version: json['version'] as String?,
      runtimeHint: json['runtimeHint'] as String?,
      runtimeArgs: parseArgs(json['runtimeArguments']),
      packageArgs: parseArgs(json['packageArguments']),
      transport: json['transport'] is Map
          ? (json['transport'] as Map)['type'] as String?
          : null,
      environmentVariables: (json['environmentVariables'] as List?)
          ?.map((e) => RegistryEnvVar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// An environment variable definition for a registry package.
class RegistryEnvVar {
  /// Environment variable name.
  final String name;

  /// Optional description of the variable's purpose.
  final String? description;

  /// Whether this variable is required for the server to function.
  final bool isRequired;

  /// Whether this variable contains sensitive data (e.g. API keys).
  final bool isSecret;

  /// Optional default value if the user does not provide one.
  final String? defaultValue;

  RegistryEnvVar({
    required this.name,
    this.description,
    this.isRequired = false,
    this.isSecret = false,
    this.defaultValue,
  });

  /// Creates a [RegistryEnvVar] from a JSON map.
  factory RegistryEnvVar.fromJson(Map<String, dynamic> json) {
    return RegistryEnvVar(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isRequired: json['isRequired'] as bool? ?? false,
      isSecret: json['isSecret'] as bool? ?? false,
      defaultValue: json['default'] as String?,
    );
  }
}

/// Remote connection configuration for a registry server.
class RegistryRemote {
  /// Remote type (e.g. "url", "github").
  final String type;

  /// Remote endpoint URL.
  final String url;

  /// Custom headers to include in requests to the remote.
  final List<RegistryEnvVar>? headers;

  /// Connection variables defined as environment-like key-value pairs.
  final Map<String, RegistryEnvVar>? variables;

  RegistryRemote({
    required this.type,
    required this.url,
    this.headers,
    this.variables,
  });

  /// Creates a [RegistryRemote] from a JSON map.
  factory RegistryRemote.fromJson(Map<String, dynamic> json) {
    return RegistryRemote(
      type: json['type'] as String? ?? '',
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as List?)
          ?.map((e) => RegistryEnvVar.fromJson(e as Map<String, dynamic>))
          .toList(),
      variables: (json['variables'] as Map<String, dynamic>?)?.map(
        (k, v) =>
            MapEntry(k, RegistryEnvVar.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

/// Source repository information for a registry server.
class RegistryRepository {
  /// Repository URL (e.g. GitHub URL).
  final String? url;

  /// Source label or platform identifier.
  final String? source;

  RegistryRepository({this.url, this.source});

  /// Creates a [RegistryRepository] from a JSON map.
  factory RegistryRepository.fromJson(Map<String, dynamic> json) {
    return RegistryRepository(
      url: json['url'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// Full information about a server listed in the MCP registry.
class RegistryServerInfo {
  /// Server identifier name (machine-readable).
  final String name;

  /// Optional display title (human-readable).
  final String? title;

  /// Short description of what this server provides.
  final String description;

  /// Server version string.
  final String version;

  /// Optional project website URL.
  final String? websiteUrl;

  /// Source repository metadata.
  final RegistryRepository? repository;

  /// Available installation packages for different platforms.
  final List<RegistryPackage> packages;

  /// Remote connection configurations.
  final List<RegistryRemote> remotes;

  RegistryServerInfo({
    required this.name,
    this.title,
    required this.description,
    required this.version,
    this.websiteUrl,
    this.repository,
    this.packages = const [],
    this.remotes = const [],
  });

  /// Preferred display name: uses [title] when available, otherwise [name].
  String get displayName => title ?? name;

  /// Whether this server is accessed via remote connections rather than
  /// running locally.
  bool get isRemote => remotes.isNotEmpty;

  /// Detects the installation type based on package metadata.
  ///
  /// Returns "npm" for npx-based packages, "pypi" for uvx-based packages,
  /// "docker" for OCI packages, or the raw runtime hint / registry type.
  String get installType {
    if (remotes.isNotEmpty) return 'remote';
    if (packages.isNotEmpty) {
      final hint = packages.first.runtimeHint;
      if (hint == 'npx') return 'npm';
      if (hint == 'uvx') return 'pypi';
      if (packages.first.registryType == 'oci') return 'docker';
      return hint ?? packages.first.registryType;
    }
    return 'unknown';
  }

  /// Creates a [RegistryServerInfo] from a JSON map.
  factory RegistryServerInfo.fromJson(Map<String, dynamic> json) {
    return RegistryServerInfo(
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '',
      websiteUrl: json['websiteUrl'] as String?,
      repository: json['repository'] is Map
          ? RegistryRepository.fromJson(
              Map<String, dynamic>.from(json['repository']),
            )
          : null,
      packages:
          (json['packages'] as List?)
              ?.map((e) => RegistryPackage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      remotes:
          (json['remotes'] as List?)
              ?.map((e) => RegistryRemote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Paginated search results from the MCP registry.
class RegistrySearchResult {
  /// List of servers matching the search query.
  final List<RegistryServerInfo> servers;

  /// Total number of matching results.
  final int count;

  /// Cursor for fetching the next page of results, or null if on the last page.
  final String? nextCursor;

  RegistrySearchResult({
    required this.servers,
    required this.count,
    this.nextCursor,
  });
}

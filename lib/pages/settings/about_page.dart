import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/translations.dart';
import '../../utils/snackbar_utils.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '...';
  String _buildNumber = '';

  static const String _releaseUrl =
      'https://github.com/learning233/opencode_mobile/';

  static const List<Map<String, String>> _packages = [
    {
      'name': 'get (GetX)',
      'desc':
          'High-performance state management & intelligent route management',
      'url': 'https://pub.dev/packages/get',
    },
    {
      'name': 'dio',
      'desc':
          'Powerful HTTP client for Dart/Flutter supporting SSE & interceptors',
      'url': 'https://pub.dev/packages/dio',
    },
    {
      'name': 'flutter_rust_bridge',
      'desc': 'High-level binding generator for Rust and Flutter integration',
      'url': 'https://pub.dev/packages/flutter_rust_bridge',
    },
    {
      'name': 'audioplayers',
      'desc': 'Low-latency audio playback for UI sounds & feedback',
      'url': 'https://pub.dev/packages/audioplayers',
    },
    {
      'name': 'kterm',
      'desc': 'Custom terminal emulator engine for interactive shell sessions',
      'url': 'https://pub.dev/packages/kterm',
    },
    {
      'name': 're_editor & re_highlight',
      'desc': 'Powerful text editor with syntax highlighting support',
      'url': 'https://pub.dev/packages/re_editor',
    },
    {
      'name': 'record',
      'desc': 'Cross-platform audio recorder for speech input',
      'url': 'https://pub.dev/packages/record',
    },
    {
      'name': 'webview_flutter',
      'desc': 'Platform-native WebView widget for embedded web content',
      'url': 'https://pub.dev/packages/webview_flutter',
    },
    {
      'name': 'package_info_plus',
      'desc': 'Application version & platform package metadata reader',
      'url': 'https://pub.dev/packages/package_info_plus',
    },
    {
      'name': 'url_launcher',
      'desc': 'Flutter plugin for launching URLs in mobile browser',
      'url': 'https://pub.dev/packages/url_launcher',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _version = '0.9.8';
          _buildNumber = '1';
        });
      }
    }
  }

  Future<void> _openUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Snack.error('Could not launch $urlStr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayVersion = _buildNumber.isNotEmpty
        ? 'v$_version+$_buildNumber'
        : 'v$_version';

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.aboutTitle.tr)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // App Header Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.code_rounded,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OpenCode Mobile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayVersion,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Release Page Card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(
                  Icons.open_in_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                LocaleKeys.releasePageTitle.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: const Text(
                _releaseUrl,
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openUrl(_releaseUrl),
            ),
          ),
          const SizedBox(height: 20),

          // Open Source Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.openSourceLibrariesTitle.tr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.openSourceLibrariesDesc.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Packages List
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _packages.length; i++) ...[
                  ListTile(
                    dense: true,
                    title: Text(
                      _packages[i]['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _packages[i]['desc']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_outward, size: 16),
                    onTap: () => _openUrl(_packages[i]['url']!),
                  ),
                  if (i < _packages.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Full Licenses Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              showLicensePage(
                context: context,
                applicationName: 'OpenCode Mobile',
                applicationVersion: displayVersion,
              );
            },
            icon: const Icon(Icons.policy_outlined, size: 18),
            label: Text(LocaleKeys.viewFullLicenses.tr),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

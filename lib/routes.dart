import 'package:get/get.dart';
import 'pages/splash_page.dart';
import 'pages/home/home_page.dart';
import 'pages/right_drawer/session_list_page.dart';
import 'pages/file/file_page.dart';
import 'pages/settings/opencode_settings_page.dart';
import 'pages/settings/opencode/connection_page.dart';
import 'pages/settings/opencode/general_page.dart';
import 'pages/settings/opencode/providers_page.dart';
import 'pages/settings/opencode/models_page.dart';
import 'pages/settings/opencode/mcp_page.dart';
import 'pages/settings/opencode/lsp_page.dart';
import 'pages/settings/opencode/skills_page.dart';
import 'pages/settings/opencode/rules_page.dart';
import 'pages/settings/opencode/agent_page.dart';
import 'pages/settings/opencode/permissions_page.dart';
import 'pages/settings/opencode/developer_page.dart';
import 'pages/settings/opencode/advanced_page.dart';
import 'pages/settings/opencode/experimental_page.dart';
import 'pages/settings/keyword_settings_page.dart';
import 'pages/settings/quick_phrases_page.dart';
import 'pages/settings/display_settings_page.dart';
import 'pages/settings/about_page.dart';
import 'pages/home/terminal_page.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String home = '/';
  static const String sessionList = '/session_list';
  static const String fileList = '/file_list';
  static const String fileEditor = '/file_editor';
  static const String settings = '/settings';
  static const String displaySettings = '/display_settings';
  static const String opencodeSettings = '/opencode_settings';
  static const String opencodeConnection = '/opencode_settings/connection';
  static const String opencodeGeneral = '/opencode_settings/general';
  static const String opencodeProviders = '/opencode_settings/providers';
  static const String opencodeModels = '/opencode_settings/models';
  static const String opencodeMcp = '/opencode_settings/mcp';
  static const String opencodeLsp = '/opencode_settings/lsp';
  static const String opencodeSkills = '/opencode_settings/skills';
  static const String opencodeRules = '/opencode_settings/rules';
  static const String opencodeAgent = '/opencode_settings/agent';
  static const String opencodePermissions = '/opencode_settings/permissions';
  static const String opencodeDeveloper = '/opencode_settings/developer';
  static const String opencodeAdvanced = '/opencode_settings/advanced';
  static const String opencodeExperimental = '/opencode_settings/experimental';
  static const String keywordSettings = '/keyword_settings';
  static const String quickPhrases = '/quick_phrases';
  static const String terminal = '/terminal';
  static const String about = '/about';

  static final List<GetPage> pages = [
    GetPage(name: splash, page: () => const SplashPage()),
    GetPage(name: home, page: () => const HomePage()),
    GetPage(name: sessionList, page: () => const SessionListPage()),
    GetPage(name: fileList, page: () => const FilePage()),
    GetPage(name: displaySettings, page: () => const DisplaySettingsPage()),
    GetPage(name: opencodeSettings, page: () => const OpenCodeSettingsPage()),
    GetPage(
      name: opencodeConnection,
      page: () => const OpencodeConnectionPage(),
    ),
    GetPage(name: opencodeGeneral, page: () => const OpencodeGeneralPage()),
    GetPage(name: opencodeProviders, page: () => const OpencodeProvidersPage()),
    GetPage(name: opencodeModels, page: () => const OpencodeModelsPage()),
    GetPage(name: opencodeMcp, page: () => const OpencodeMcpPage()),
    GetPage(name: opencodeLsp, page: () => const OpencodeLspPage()),
    GetPage(name: opencodeSkills, page: () => const OpencodeSkillsPage()),
    GetPage(name: opencodeRules, page: () => const OpencodeRulesPage()),
    GetPage(name: opencodeAgent, page: () => const OpencodeAgentPage()),
    GetPage(
      name: opencodePermissions,
      page: () => const OpencodePermissionsPage(),
    ),
    GetPage(name: opencodeDeveloper, page: () => const OpencodeDeveloperPage()),
    GetPage(name: opencodeAdvanced, page: () => const OpencodeAdvancedPage()),
    GetPage(
      name: opencodeExperimental,
      page: () => const OpencodeExperimentalPage(),
    ),
    GetPage(name: keywordSettings, page: () => const KeywordSettingsPage()),
    GetPage(name: quickPhrases, page: () => const QuickPhrasesPage()),
    GetPage(name: terminal, page: () => const TerminalPage()),
    GetPage(name: about, page: () => const AboutPage()),
  ];
}

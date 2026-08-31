import 'package:get/get.dart';

// ──────────────────────────────────────────────────────────
//  Translation keys – every user-visible string lives here
// ──────────────────────────────────────────────────────────

class LocaleKeys {
  // ── Common ──
  static const cancel = "common_cancel";
  static const save = "common_save";
  static const delete = "common_delete";
  static const saveFailed = "common_save_failed";
  static const deleteFailed = "common_delete_failed";
  static const close = "common_close";
  static const retry = "common_retry";
  static const search = "common_search";
  static const export = "common_export";
  static const upgrade = "common_upgrade";
  static const upgrading = "common_upgrading";
  static const reload = "common_reload";
  static const add = "common_add";
  static const remove = "common_remove";
  static const active = "common_active";
  static const notSet = "common_not_set";
  static const default_ = "common_default";
  static const unlimited = "common_unlimited";
  static const yes = "common_yes";
  static const no = "common_no";
  static const on_ = "common_on";
  static const off = "common_off";
  static const auto = "common_auto";
  static const manual = "common_manual";
  static const disabled = "common_disabled";
  static const notify = "common_notify";
  static const healthy = "common_healthy";
  static const unhealthy = "common_unhealthy";
  static const serverDefault = "common_server_default";
  static const restore = "common_restore";

  // ── Snackbar ──
  static const snackSuccess = "snackbar_success";
  static const snackError = "snackbar_error";
  static const snackInfo = "snackbar_info";
  static const snackWarning = "snackbar_warning";

  // ── Clipboard ──
  static const clipboardCopied = "clipboard_copied";
  static const clipboardCopyFailed = "clipboard_copy_failed";

  // ── Start Page ──
  static const preparing = "start_preparing";
  static const initLocalEnv = "start_init_local_env";
  static const spawningSidecar = "start_spawning_sidecar";
  static const migratingSqlite = "start_migrating_sqlite";
  static const systemReady = "start_system_ready";
  static const sidecarFailed = "start_sidecar_failed";

  // ── Titlebar ──
  static const menuFile = "titlebar_menu_file";
  static const newProject = "titlebar_new_project";
  static const noRecentProjects = "titlebar_no_recent_projects";
  static const recentProjects = "titlebar_recent_projects";

  // ── Command Palette ──
  static const cmdNewSession = "cmd_new_session";
  static const cmdNewSessionDesc = "cmd_new_session_desc";
  static const cmdOpenSettings = "cmd_open_settings";
  static const cmdOpenSettingsDesc = "cmd_open_settings_desc";
  static const cmdToggleTheme = "cmd_toggle_theme";
  static const cmdToggleThemeDesc = "cmd_toggle_theme_desc";
  static const cmdToggleTerminal = "cmd_toggle_terminal";
  static const cmdToggleTerminalDesc = "cmd_toggle_terminal_desc";
  static const cmdToggleReview = "cmd_toggle_review";
  static const cmdToggleReviewDesc = "cmd_toggle_review_desc";
  static const cmdToggleSidebar = "cmd_toggle_sidebar";
  static const cmdToggleSidebarDesc = "cmd_toggle_sidebar_desc";
  static const cmdExportLogs = "cmd_export_logs";
  static const cmdExportLogsDesc = "cmd_export_logs_desc";

  // ── Session Page ──
  static const allPanelsCollapsed = "session_all_panels_collapsed";

  // ── Left Panel ──
  static const explorer = "left_explorer";
  static const searchLabel = "left_search";
  static const gitStatus = "left_git_status";

  // ── Settings – Tabs ──
  static const tabGeneral = "settings_tab_general";
  static const tabProviders = "settings_tab_providers";
  static const tabModels = "settings_tab_models";
  static const tabMcp = "settings_tab_mcp";
  static const tabLsp = "settings_tab_lsp";
  static const tabSkills = "settings_tab_skills";
  static const tabRules = "settings_tab_rules";
  static const tabAgent = "settings_tab_agent";
  static const tabPermissions = "settings_tab_permissions";
  static const tabDeveloper = "settings_tab_developer";
  static const tabAdvanced = "settings_tab_advanced";
  static const tabExperimental = "settings_tab_experimental";
  static const tabConnection = "settings_tab_connection";
  static const opencodeSettingsTitle = "settings_opencode_title";
  static const tabAbout = "settings_tab_about";

  // ── Settings – Cloud Workspace (E2B) ──
  static const connModeSelfHosted = "conn_mode_self_hosted";
  static const connModeCloud = "conn_mode_cloud";
  static const e2bTitle = "e2b_title";
  static const e2bDesc = "e2b_desc";
  static const e2bApiKey = "e2b_api_key";
  static const e2bApiKeyHint = "e2b_api_key_hint";
  static const e2bTemplate = "e2b_template";
  static const e2bTemplateHint = "e2b_template_hint";
  static const e2bToolchains = "e2b_toolchains";
  static const e2bToolchainDart = "e2b_toolchain_dart";
  static const e2bToolchainRust = "e2b_toolchain_rust";
  static const e2bToolchainCpp = "e2b_toolchain_cpp";
  static const e2bToolchainPython = "e2b_toolchain_python";
  static const e2bGitConfig = "e2b_git_config";
  static const e2bGitRepo = "e2b_git_repo";
  static const e2bGitRepoHint = "e2b_git_repo_hint";
  static const e2bGitBranch = "e2b_git_branch";
  static const e2bGitToken = "e2b_git_token";
  static const e2bGitTokenHint = "e2b_git_token_hint";
  static const e2bGitUsername = "e2b_git_username";
  static const e2bGitEmail = "e2b_git_email";
  static const e2bLlmConfig = "e2b_llm_config";
  static const e2bAnthropicKey = "e2b_anthropic_key";
  static const e2bOpenAiKey = "e2b_openai_key";
  static const e2bGeminiKey = "e2b_gemini_key";
  static const e2bDeepseekKey = "e2b_deepseek_key";
  static const e2bTtlHours = "e2b_ttl_hours";
  static const e2bTtlDesc = "e2b_ttl_desc";
  static const e2bAutoPause = "e2b_auto_pause";
  static const e2bAutoPauseDesc = "e2b_auto_pause_desc";
  static const e2bLaunchWorkspace = "e2b_launch_workspace";
  static const e2bLaunchingWorkspace = "e2b_launching_workspace";
  static const e2bPauseSandbox = "e2b_pause_sandbox";
  static const e2bResumeSandbox = "e2b_resume_sandbox";
  static const e2bDestroySandbox = "e2b_destroy_sandbox";
  static const e2bSandboxList = "e2b_sandbox_list";
  static const e2bCreateSandbox = "e2b_create_sandbox";
  static const e2bRefreshList = "e2b_refresh_list";
  static const e2bNoSandboxes = "e2b_no_sandboxes";
  static const e2bNoSandboxesDesc = "e2b_no_sandboxes_desc";
  static const e2bApiKeyRequired = "e2b_api_key_required";
  static const e2bApiKeyRequiredDesc = "e2b_api_key_required_desc";
  static const e2bConfigApiKey = "e2b_config_api_key";
  static const e2bCurrentlyConnected = "e2b_currently_connected";
  static const e2bConnectSandbox = "e2b_connect_sandbox";
  static const e2bConnectLastSandbox = "e2b_connect_last_sandbox";
  static const e2bWakeAndConnect = "e2b_wake_and_connect";
  static const e2bManageSandboxes = "e2b_manage_sandboxes";
  static const e2bSandboxNotReadyWakeHint = "e2b_sandbox_not_ready_wake_hint";
  static const e2bCloudBackend = "e2b_cloud_backend";
  static const selfHostedBackend = "self_hosted_backend";
  static const e2bNoApiKey = "e2b_no_api_key";
  static const e2bNoApiKeyDesc = "e2b_no_api_key_desc";
  static const e2bNewSandbox = "e2b_new_sandbox";
  static const switchToSelfHosted = "switch_to_self_hosted";
  static const connectionDisconnected = "connection_disconnected";
  static const e2bClearInvalidSandbox = "e2b_clear_invalid_sandbox";
  static const e2bConfirmDestroy = "e2b_confirm_destroy";
  static const e2bConfirmDestroyDesc = "e2b_confirm_destroy_desc";
  static const e2bSandboxStatusRunning = "e2b_status_running";
  static const e2bSandboxStatusPaused = "e2b_status_paused";
  static const e2bSandboxDashboard = "e2b_sandbox_dashboard";
  static const e2bConfigWorkspace = "e2b_config_workspace";
  static const e2bFetchRepos = "e2b_fetch_repos";
  static const e2bFetchingRepos = "e2b_fetching_repos";
  static const e2bSelectRepo = "e2b_select_repo";
  static const e2bSearchRepos = "e2b_search_repos";
  static const e2bNoReposFound = "e2b_no_repos_found";
  static const e2bGitTokenRequiredForRepos = "e2b_git_token_required_for_repos";
  static const e2bProvidersConfig = "e2b_providers_config";
  static const e2bConfigured = "e2b_configured";
  static const e2bNotConfigured = "e2b_not_configured";
  static const e2bCustomBaseUrl = "e2b_custom_base_url";
  static const e2bCustomBaseUrlHint = "e2b_custom_base_url_hint";
  static const e2bRepoSelected = "e2b_repo_selected";
  static const e2bTemplateHelper = "e2b_template_helper";
  static const e2bGitProjectAndAuth = "e2b_git_project_and_auth";
  static const e2bGitPatLabel = "e2b_git_pat_label";
  static const e2bGitPatHint = "e2b_git_pat_hint";
  static const e2bFetchAndSelectRepo = "e2b_fetch_and_select_repo";
  static const e2bSelectedRepoWithBranch = "e2b_selected_repo_with_branch";
  static const e2bGitRepoUrlOptionalHint = "e2b_git_repo_url_optional_hint";
  static const e2bFetchReposFailed = "e2b_fetch_repos_failed";
  static const e2bFetchReposTokenError = "e2b_fetch_repos_token_error";
  static const e2bSelectGitHubRepo = "e2b_select_github_repo";
  static const e2bFetchingRepoList = "e2b_fetching_repo_list";
  static const e2bLaunchPreparing = "e2b_launch_preparing";
  static const e2bApiKeyEmptyError = "e2b_api_key_empty_error";
  static const e2bLaunchRequestingVm = "e2b_launch_requesting_vm";
  static const e2bLaunchFailed = "e2b_launch_failed";
  static const e2bLaunchConnecting = "e2b_launch_connecting";
  static const e2bHandshakeFailed = "e2b_handshake_failed";
  static const e2bWorkspaceReady = "e2b_workspace_ready";
  static const e2bLaunchErrorTitle = "e2b_launch_error_title";
  static const e2bSandboxPreservedHint = "e2b_sandbox_preserved_hint";
  static const e2bConnectFailed = "e2b_connect_failed";
  static const e2bServiceUnreachable = "e2b_service_unreachable";
  static const e2bConnectedToSandbox = "e2b_connected_to_sandbox";
  static const e2bConnectionError = "e2b_connection_error";
  static const e2bSandboxPausedSuccess = "e2b_sandbox_paused_success";
  static const e2bSandboxPauseFailed = "e2b_sandbox_pause_failed";
  static const e2bSandboxResumedSuccess = "e2b_sandbox_resumed_success";
  static const e2bSandboxResumeFailed = "e2b_sandbox_resume_failed";
  static const e2bSandboxDestroyedSuccess = "e2b_sandbox_destroyed_success";
  static const e2bSandboxDestroyFailed = "e2b_sandbox_destroy_failed";
  static const e2bCheckingStatus = "e2b_checking_status";
  static const e2bSandboxConnected = "e2b_sandbox_connected";
  static const e2bAuthFailedTitle = "e2b_auth_failed_title";
  static const e2bAuthFailedDesc = "e2b_auth_failed_desc";
  static const e2bServiceNotReadyTitle = "e2b_service_not_ready_title";
  static const e2bServiceNotReadyDesc = "e2b_service_not_ready_desc";
  static const e2bSandboxDisconnected = "e2b_sandbox_disconnected";
  static const e2bSandboxDisconnectedDesc = "e2b_sandbox_disconnected_desc";
  static const e2bNoActiveSandbox = "e2b_no_active_sandbox";
  static const e2bNoActiveSandboxDesc = "e2b_no_active_sandbox_desc";
  static const e2bFetchingSandboxes = "e2b_fetching_sandboxes";
  static const e2bFetchSandboxesFailed = "e2b_fetch_sandboxes_failed";
  static const e2bStartedAt = "e2b_started_at";
  static const e2bExpiresAt = "e2b_expires_at";
  static const e2bCopySandboxId = "e2b_copy_sandbox_id";
  static const e2bProbingSandbox = "e2b_probing_sandbox";
  static const e2bSandboxLabel = "e2b_sandbox_label";

  // ── Settings – General ──
  static const secAppearance = "gen_sec_appearance";
  static const colorTheme = "gen_color_theme";
  static const colorThemeDesc = "gen_color_theme_desc";
  static const dark = "gen_dark";
  static const light = "gen_light";
  static const language = "gen_language";
  static const languageDesc = "gen_language_desc";
  static const wslIntegration = "gen_wsl";
  static const wslIntegrationDesc = "gen_wsl_desc";
  static const debugLogs = "gen_debug_logs";
  static const debugLogsDesc = "gen_debug_logs_desc";

  static const secNotifications = "gen_sec_notifications";
  static const notificationSound = "gen_notif_sound";
  static const notificationSoundDesc = "gen_notif_sound_desc";

  static const secShell = "gen_sec_shell";
  static const defaultShell = "gen_default_shell";
  static const defaultShellDesc = "gen_default_shell_desc";
  static const logLevel = "gen_log_level";
  static const logLevelDesc = "gen_log_level_desc";
  static const username = "gen_username";
  static const usernameDesc = "gen_username_desc";
  static const usernamePlaceholder = "gen_username_placeholder";

  static const secSharing = "gen_sec_sharing";
  static const sharingMode = "gen_share_mode";
  static const sharingModeDesc = "gen_share_mode_desc";
  static const autoUpdate = "gen_auto_update";
  static const autoUpdateDesc = "gen_auto_update_desc";
  static const snapshotTracking = "gen_snapshot";
  static const snapshotTrackingDesc = "gen_snapshot_desc";
  static const snapshotWarningTitle = "gen_snapshot_warning_title";
  static const snapshotWarningDesc = "gen_snapshot_warning_desc";
  static const csCacheBlockedBySnapshot = "cs_cache_blocked_by_snapshot";

  static const secCompaction = "gen_sec_compaction";
  static const autoCompaction = "gen_auto_compaction";
  static const autoCompactionDesc = "gen_auto_compaction_desc";
  static const pruneOldOutputs = "gen_prune_outputs";
  static const pruneOldOutputsDesc = "gen_prune_outputs_desc";

  // ── Settings – About ──
  static const secServerStatus = "about_sec_server_status";
  static const openCodeVersion = "about_version";
  static const checkForUpdates = "about_check_updates";
  static const checkForUpdatesDesc = "about_check_updates_desc";
  static const secToolOutput = "about_sec_tool_output";
  static const maxLines = "about_max_lines";
  static const maxLinesDesc = "about_max_lines_desc";
  static const maxBytes = "about_max_bytes";
  static const maxBytesDesc = "about_max_bytes_desc";
  static const secCompactionAbout = "about_sec_compaction";
  static const tailTurns = "about_tail_turns";
  static const tailTurnsDesc = "about_tail_turns_desc";
  static const reservedTokens = "about_reserved_tokens";
  static const reservedTokensDesc = "about_reserved_tokens_desc";

  // ── Settings – Providers ──
  static const providers = "providers_title";
  static const secConnectedProviders = "providers_sec_connected";
  static const noConnectedProviders = "providers_no_connected";
  static const secAllProviders = "providers_sec_all";
  static const searchProvidersPlaceholder = "providers_search_placeholder";
  static const noMatchingProviders = "providers_no_matching";
  static const secCustomProvider = "providers_sec_custom";
  static const customProviderTag = "custom_providers_tag";
  static const customProvider = "providers_custom";
  static const customProviderDesc = "providers_custom_desc";
  static const secBlockedProviders = "providers_sec_blocked";
  static const noBlockedProviders = "providers_no_blocked";
  static const providersRestored = "providers_restored";

  // ── Settings – Models ──
  static const models = "models_title";
  static const smallModel = "models_small";
  static const smallModelDesc = "models_small_desc";
  static const searchModelsPlaceholder = "models_search_placeholder";
  static const noModelsLoaded = "models_no_loaded";
  static const noMatchingModels = "models_no_matching";

  // ── Settings – MCP ──
  static const addMcpServer = "mcp_add_server";
  static const serverNamePlaceholder = "mcp_server_name_placeholder";
  static const connectionType = "mcp_connection_type";
  static const localStdio = "mcp_local_stdio";
  static const localSse = "mcp_local_sse";
  static const remoteUrl = "mcp_remote_url";
  static const commandPlaceholder = "mcp_command_placeholder";
  static const argsPlaceholder = "mcp_args_placeholder";
  static const serverUrlPlaceholder = "mcp_server_url_placeholder";

  // ── Settings – Permissions ──
  static const secBulkActions = "perm_sec_bulk";
  static const applyToAllTools = "perm_apply_all";
  static const ask = "perm_ask";
  static const allow = "perm_allow";
  static const deny = "perm_deny";
  static const toolPermissions = "perm_tool_permissions";

  // ── Settings – Agent ──
  static const agentConfigs = "agent_configs";
  static const newAgent = "agent_new";
  static const noAgentsConfigured = "agent_no_configured";
  static const failedToLoadAgents = "agent_failed_load";

  // ── Settings – Developer ──
  static const developer = "dev_title";
  static const secCommands = "dev_sec_commands";
  static const addCommand = "dev_add_command";
  static const cmdNamePlaceholder = "dev_cmd_name_placeholder";

  // ── Settings – Advanced ──
  static const advanced = "adv_title";

  // ── Settings – Experimental ──
  static const experimental = "exp_title";
  static const secFeatures = "exp_sec_features";
  static const batchTool = "exp_batch_tool";
  static const batchToolDesc = "exp_batch_tool_desc";
  static const disablePasteSummary = "exp_disable_paste";
  static const disablePasteSummaryDesc = "exp_disable_paste_desc";
  static const continueLoopOnDeny = "exp_continue_deny";
  static const continueLoopOnDenyDesc = "exp_continue_deny_desc";
  static const openTelemetry = "exp_otel";
  static const openTelemetryDesc = "exp_otel_desc";
  static const fileWatcher = "exp_file_watcher";
  static const fileWatcherDesc = "exp_file_watcher_desc";
  static const fileWatcherRestartHint = "exp_file_watcher_restart_hint";
  static const restartSidecar = "exp_restart_sidecar";
  static const sidecarRestarting = "exp_sidecar_restarting";
  static const sidecarRestarted = "exp_sidecar_restarted";
  static const sidecarRestartFailed = "exp_sidecar_restart_failed";
  static const settingsBlockedByGeneration = "settings_blocked_generation";
  static const secMcp = "exp_sec_mcp";
  static const mcpTimeout = "exp_mcp_timeout";
  static const mcpTimeoutDesc = "exp_mcp_timeout_desc";
  static const secPrimaryTools = "exp_sec_primary_tools";
  static const primaryTools = "exp_primary_tools";
  static const primaryToolsDesc = "exp_primary_tools_desc";

  // ── Settings – Rules ──
  static const globalAgentsMd = "rules_global_agents";
  static const globalAgentsDesc = "rules_global_agents_desc";
  static const globalAgentsReadOnlyBanner = "rules_global_agents_readonly";
  static const enterGlobalRules = "rules_enter_global";
  static const instructions = "rules_instructions";
  static const instructionsDesc = "rules_instructions_desc";
  static const noCustomInstructions = "rules_no_custom";
  static const globalRulesSaved = "rules_global_saved";
  static const saved = "rules_saved";

  // ── Settings – Skills ──
  static const skillSavedSuccess = "skills_saved_success";
  static const skillSaveFailed = "skills_save_failed";
  static const skillsFailedLoad = "skills_failed_load";
  static const skillsNoLoaded = "skills_no_loaded";

  // ── Tool Cards ──
  static const enterYourAnswer = "tool_enter_answer";
  static const enterYourAnswerHere = "tool_enter_answer_here";

  // ── Git Diff ──
  static const rolledBack = "diff_rolled_back";

  // ── Editor Panel ──
  static const edKeyboardShortcuts = "ed_keyboard_shortcuts";
  static const edTypography = "ed_typography";
  static const edEditorFeatures = "ed_editor_features";
  static const edShowLineNumbers = "ed_show_line_numbers";
  static const edEnableCodeFolding = "ed_enable_code_folding";
  static const edShowGuideLines = "ed_show_guide_lines";
  static const edFormatOnSave = "ed_format_on_save";
  static const edHighlightTheme = "ed_highlight_theme";
  static const edFollowSystem = "ed_follow_system";
  static const edWorkflow = "ed_workflow";
  static const edAutoSendDiagnostics = "ed_auto_send_diagnostics";
  static const edAutoSendDiagnosticsDesc = "ed_auto_send_diagnostics_desc";
  static const edLspServers = "ed_lsp_servers";
  static const edNoLspServers = "ed_no_lsp_servers";
  static const edTabNavigation = "ed_tab_navigation";
  static const edFileOperations = "ed_file_operations";
  static const edEditorOperations = "ed_editor_operations";
  static const edReset = "ed_reset";
  static const edPreviousTab = "ed_previous_tab";
  static const edNextTab = "ed_next_tab";
  static const edEditorSettings = "ed_editor_settings";
  static const edUnsavedChanges = "ed_unsaved_changes";
  static const edUnsavedChangesDesc = "ed_unsaved_changes_desc";
  static const edDiskChangedTitle = "ed_disk_changed_title";
  static const edDiskChangedDesc = "ed_disk_changed_desc";
  static const edDiskChangedTooltip = "ed_disk_changed_tooltip";
  static const edSaveCurrentBuffer = "ed_save_current_buffer";
  static const edClose = "ed_close";
  static const edCloseOthers = "ed_close_others";
  static const edCloseRight = "ed_close_right";
  static const edCloseSaved = "ed_close_saved";
  static const edCloseAll = "ed_close_all";
  static const edCopyPath = "ed_copy_path";
  static const edCopyRelativePath = "ed_copy_relative_path";
  static const edWaitingForKeys = "ed_waiting_for_keys";
  static const edCopyAbsPathFailed = "ed_copy_abs_path_failed";
  static const edCopyRelPathFailed = "ed_copy_rel_path_failed";
  static const edFontSize = "ed_font_size";
  static const edFontFamily = "ed_font_family";
  static const edLayoutIndentation = "ed_layout_indentation";
  static const edTabSize = "ed_tab_size";
  static const ed2Spaces = "ed_2_spaces";
  static const ed4Spaces = "ed_4_spaces";
  static const edTheme = "ed_theme";
  static const edLspDesc = "ed_lsp_desc";
  static const edWordWrap = "ed_word_wrap";
  static const edEnableWordWrap = "ed_enable_word_wrap";
  static const edDisableWordWrap = "ed_disable_word_wrap";
  static const edSourceMode = "ed_source_mode";
  static const edPreviewMode = "ed_preview_mode";
  static const edZoomIn = "ed_zoom_in";
  static const edZoomOut = "ed_zoom_out";
  static const edCopyAll = "ed_copy_all";
  static const edCopied = "ed_copied";
  static const edFindPlaceholder = "ed_find_placeholder";
  static const edFindNoResult = "ed_find_no_result";
  static const edFindPrevious = "ed_find_previous";
  static const edFindNext = "ed_find_next";
  static const edCaseSensitive = "ed_case_sensitive";
  static const edRegex = "ed_regex";
  static const edCloseSearch = "ed_close_search";
  static const lspInstalled = "lsp_installed";
  static const lspMissing = "lsp_missing";
  static const lspExecutable = "lsp_executable";
  static const lspPathWarning = "lsp_path_warning";

  // ── Chat Setting ──
  static const csShowThinking = "cs_show_thinking";
  static const csShowThinkingDesc = "cs_show_thinking_desc";
  static const csTabDisplay = "cs_tab_display";
  static const csTabBuild = "cs_tab_build";
  static const csMultiBuild = "cs_multi_build";
  static const csMultiBuildDesc = "cs_multi_build_desc";
  static const csShell = "cs_shell";
  static const csShellDesc = "cs_shell_desc";
  static const csKeywordDetection = "cs_keyword_detection";
  static const csKeywordDetectionDesc = "cs_keyword_detection_desc";
  static const csQuickPhrases = "cs_quick_phrases";
  static const csAutoSend = "cs_auto_send";
  static const csAutoSendDesc = "cs_auto_send_desc";
  static const csAdd = "cs_add";
  static const csNoQuickPhrases = "cs_no_quick_phrases";
  static const csEdit = "cs_edit";
  static const csInputKeyword = "cs_input_keyword";
  static const csInputPhrase = "cs_input_phrase";
  static const csTabReview = "cs_tab_review";
  static const csReviewScope = "cs_review_scope";
  static const csReviewScopeDesc = "cs_review_scope_desc";
  static const csReviewScopeUncommitted = "cs_review_scope_uncommitted";
  static const csReviewScopeCurrentWindow = "cs_review_scope_current_window";
  static const csReviewModel = "cs_review_model";
  static const csReviewModelDesc = "cs_review_model_desc";
  static const csReviewThinkingLevel = "cs_review_thinking_level";
  static const csReviewThinkingLevelDesc = "cs_review_thinking_level_desc";
  static const csReviewPrompt = "cs_review_prompt";
  static const csReviewPromptDesc = "cs_review_prompt_desc";
  static const csReviewPromptReset = "cs_review_prompt_reset";
  static const csWatcherDiffOverlay = "cs_watcher_diff_overlay";
  static const csWatcherDiffOverlayDesc = "cs_watcher_diff_overlay_desc";
  static const csPromptSuggest = "cs_prompt_suggest";
  static const csPromptSuggestEnabled = "cs_prompt_suggest_enabled";
  static const csPromptSuggestEnabledDesc = "cs_prompt_suggest_enabled_desc";
  static const csPromptSuggestPaths = "cs_prompt_suggest_paths";
  static const csPromptSuggestPathsDesc = "cs_prompt_suggest_paths_desc";
  static const csInputPath = "cs_input_path";
  static const csPromptSuggestExclude = "cs_prompt_suggest_exclude";
  static const csPromptSuggestExcludeDesc = "cs_prompt_suggest_exclude_desc";
  static const csInputExcludeName = "cs_input_exclude_name";
  static const csCache = "cs_cache";
  static const csCacheNoGitignore = "cs_cache_no_gitignore";
  static const csCacheTrackedPaths = "cs_cache_tracked_paths";
  static const csCacheTrackedPathsDesc = "cs_cache_tracked_paths_desc";
  static const csCacheAddTrackedPath = "cs_cache_add_tracked_path";
  static const csCacheExtraExcludes = "cs_cache_extra_excludes";
  static const csCacheAddExcludedPath = "cs_cache_add_excluded_path";
  static const csCacheInvalidPath = "cs_cache_invalid_path";
  static const csCacheRebuildTitle = "cs_cache_rebuild_title";
  static const csCacheRebuildContent = "cs_cache_rebuild_content";
  static const csCacheRebuild = "cs_cache_rebuild";
  static const csCacheRefresh = "cs_cache_refresh";
  static const csCacheRebuildBtn = "cs_cache_rebuild_btn";
  static const csCacheCompress = "cs_cache_compress";
  static const csCacheOpenFolder = "cs_cache_open_folder";
  static const csCacheOpCompleted = "cs_cache_op_completed";
  static const csCacheOpFailed = "cs_cache_op_failed";
  static const csCacheGitignoreRequired = "cs_cache_gitignore_required";
  static const csTabMultiSession = "cs_tab_multi_session";
  static const inputPanelsSection = "input_panels_section";
  static const inputPanelTodo = "input_panel_todo";
  static const inputPanelDiff = "input_panel_diff";
  static const csMultiSessionModel = "cs_multi_session_model";
  static const csMultiSessionThinkingLevel = "cs_multi_session_thinking_level";
  static const csMultiSessionThinkingLevelDesc =
      "cs_multi_session_thinking_level_desc";
  static const csMultiSessionConfiguredListTitle =
      "cs_multi_session_configured_list_title";
  static const csMultiSessionEmptyList = "cs_multi_session_empty_list";
  static const chatMultiSessionTooltip = "chat_multi_session_tooltip";

  // ── Prompt Input ──
  static const piBuildRunning = "pi_build_running";
  static const piBuildFailed = "pi_build_failed";
  static const piSecurityRequest = "pi_security_request";
  static const piDenyOperation = "pi_deny_operation";
  static const piAlwaysAllow = "pi_always_allow";
  static const piAllowExecute = "pi_allow_execute";
  static const piTodoItems = "pi_todo_items";
  static const piChangedFiles = "pi_changed_files";
  static const piSelectSession = "pi_select_session";
  static const piAttachFile = "pi_attach_file";
  static const piBuildLocked = "pi_build_locked";
  static const piStop = "pi_stop";
  static const piNoAgent = "pi_no_agent";
  static const piKeep = "pi_keep";
  static const piKeepAll = "pi_keep_all";
  static const piCancelAll = "pi_cancel_all";
  static const piSendNow = "pi_send_now";

  // ── Session Header ──
  static const shSessionTitle = "sh_session_title";
  static const shSessionsHistory = "sh_sessions_history";
  static const shChatSettings = "sh_chat_settings";
  static const shUndoRevert = "sh_undo_revert";
  static const shUndoRevertDesc = "sh_undo_revert_desc";
  static const shUndoRevertDescWithFiles = "sh_undo_revert_desc_with_files";
  static const shUndoRevertDescChatOnly = "sh_undo_revert_desc_chat_only";
  static const shCancelRevert = "sh_cancel_revert";
  static const shConfirmRevert = "sh_confirm_revert";
  static const shConfirmRevertDesc = "sh_confirm_revert_desc";
  static const shConfirmRevertAffected = "sh_confirm_revert_affected";
  static const shConfirmRevertNoFiles = "sh_confirm_revert_no_files";
  static const shConfirmRevertSummary = "sh_confirm_revert_summary";
  static const shConfirmRevertCheckpointMissing =
      "sh_confirm_revert_checkpoint_missing";
  static const shConfirmRevertWorkspaceMissing =
      "sh_confirm_revert_workspace_missing";
  static const shConfirmRevertPreviewFailed =
      "sh_confirm_revert_preview_failed";
  static const shConfirmRevertScopeTitle = "sh_confirm_revert_scope_title";
  static const shConfirmRevertScopeChat = "sh_confirm_revert_scope_chat";
  static const shConfirmRevertScopeChatDesc =
      "sh_confirm_revert_scope_chat_desc";
  static const shConfirmRevertScopeSession = "sh_confirm_revert_scope_session";
  static const shConfirmRevertScopeSessionDesc =
      "sh_confirm_revert_scope_session_desc";
  static const shConfirmRevertScopeWorkspace =
      "sh_confirm_revert_scope_workspace";
  static const shConfirmRevertScopeWorkspaceDesc =
      "sh_confirm_revert_scope_workspace_desc";
  static const shConfirmRevertRelatedMissing =
      "sh_confirm_revert_related_missing";
  static const shConfirmRevertWorkspaceRisk =
      "sh_confirm_revert_workspace_risk";
  static const shRevertBlockedGenerating = "sh_revert_blocked_generating";
  static const shRevertCheckpointMissingChatOnly =
      "sh_revert_checkpoint_missing_chat_only";
  static const shRevertFailed = "sh_revert_failed";
  static const shRevertFailedAfterPartial = "sh_revert_failed_after_partial";
  static const shRevertCompensationFailed = "sh_revert_compensation_failed";
  static const shUnrevertFailed = "sh_unrevert_failed";
  static const shUnrevertChatOnlyNoFiles = "sh_unrevert_chat_only_no_files";
  static const shSessionHistory = "sh_session_history";
  static const shSearchHistory = "sh_search_history";
  static const shNoMatches = "sh_no_matches";
  static const shNoHistory = "sh_no_history";
  static const shDeleteSession = "sh_delete_session";

  // ── File Tree ──
  static const ftRenameFailed = "ft_rename_failed";
  static const ftCreateFailed = "ft_create_failed";
  static const ftDeleteFailed = "ft_delete_failed";
  static const ftNewFile = "ft_new_file";
  static const ftNewFolder = "ft_new_folder";
  static const ftCopy = "ft_copy";
  static const ftPaste = "ft_paste";
  static const ftCut = "ft_cut";
  static const ftCopyPath = "ft_copy_path";
  static const ftCopyRelativePath = "ft_copy_relative_path";
  static const ftRename = "ft_rename";
  static const ftDelete = "ft_delete";
  static const unsupportedBinaryFile = "file_unsupported_binary";

  // ── Git Panel ──
  static const gpSyncSuccess = "gp_sync_success";
  static const gpSyncFailed = "gp_sync_failed";
  static const gpCommitSuccess = "gp_commit_success";
  static const gpDiscardChanges = "gp_discard_changes";
  static const gpConfirmDiscard = "gp_confirm_discard";
  static const gpChanges = "gp_changes";
  static const gpRefreshStatus = "gp_refresh_status";
  static const gpGraph = "gp_graph";
  static const gpSwitchBranch = "gp_switch_branch";
  static const gpSyncChanges = "gp_sync_changes";
  static const gpCommit = "gp_commit";
  static const gpMoreOptions = "gp_more_options";
  static const gpCommitAndPush = "gp_commit_and_push";
  static const gpCopyCommitHash = "gp_copy_commit_hash";
  static const gpNoFileChanges = "gp_no_file_changes";
  static const gpLocalPushed = "gp_local_pushed";
  static const gpNotPushed = "gp_not_pushed";
  static const gpViewDiff = "gp_view_diff";
  static const gpDiscardTooltip = "gp_discard_tooltip";
  static const gpStageChanges = "gp_stage_changes";
  static const gpSearchCommits = "gp_search_commits";
  static const gpNoMatchingCommits = "gp_no_matching_commits";

  // ── Terminal ──
  static const termNoTerminal = "term_no_terminal";
  static const termNoOutput = "term_no_output";

  // ── Keyboard Shortcuts (labels) ──
  static const kbPrevTab = "kb_prev_tab";
  static const kbNextTab = "kb_next_tab";
  static const kbCloseTab = "kb_close_tab";
  static const kbCloseTabAlt = "kb_close_tab_alt";
  static const kbCloseAllTabs = "kb_close_all_tabs";
  static const kbCloseSavedTabs = "kb_close_saved_tabs";
  static const kbCopyAbsPath = "kb_copy_abs_path";
  static const kbCopyRelPath = "kb_copy_rel_path";
  static const kbSendToInput = "kb_send_to_input";
  static const kbFind = "kb_find";
  static const kbFindReplace = "kb_find_replace";
  static const kbSave = "kb_save";
  static const kbDuplicateLine = "kb_duplicate_line";
  static const kbUndo = "kb_undo";
  static const kbRedo = "kb_redo";
  static const kbMoveLineUp = "kb_move_line_up";
  static const kbMoveLineDown = "kb_move_line_down";
  static const kbWordLeft = "kb_word_left";
  static const kbWordRight = "kb_word_right";
  static const kbDeleteWordBack = "kb_delete_word_back";
  static const kbDeleteWordForward = "kb_delete_word_forward";
  static const kbGoToDocStart = "kb_go_to_doc_start";
  static const kbGoToDocEnd = "kb_go_to_doc_end";
  static const kbCodeActions = "kb_code_actions";
  static const kbRenameSymbol = "kb_rename_symbol";
  static const kbFormat = "kb_format";
  static const kbToggleComment = "kb_toggle_comment";

  // ── LSP ──
  static const lspConfigDesc = "lsp_config_desc";
  static const lspAgentLsp = "lsp_agent_lsp";
  static const lspAgentDiagDesc = "lsp_agent_diag_desc";
  static const lspAvailableServers = "lsp_available_servers";
  static const lspBackendManagedDesc = "lsp_backend_managed_desc";
  static const lspNotDetected = "lsp_not_detected";
  static const lspInstalling = "lsp_installing";
  static const lspInstall = "lsp_install";
  static const lspInstallDartSdkTip = "lsp_install_dart_sdk_tip";
  static const lspInstallManualTip = "lsp_install_manual_tip";
  static const lspInstallSuccess = "lsp_install_success";
  static const lspInstallFailed = "lsp_install_failed";
  static const lspDartDesc = "lsp_dart_desc";
  static const lspRustDesc = "lsp_rust_desc";
  static const lspPythonDesc = "lsp_python_desc";
  static const lspGoDesc = "lsp_go_desc";
  static const lspJsTsDesc = "lsp_jsts_desc";
  static const lspHtmlDesc = "lsp_html_desc";
  static const lspCssDesc = "lsp_css_desc";
  static const lspJsonDesc = "lsp_json_desc";
  static const lspCppDesc = "lsp_cpp_desc";
  static const lspBashDesc = "lsp_bash_desc";
  static const lspYamlDesc = "lsp_yaml_desc";
  static const lspLuaDesc = "lsp_lua_desc";

  // ── Terminal ──
  static const termTerminal = "term_terminal";
  static const termProblems = "term_problems";
  static const termOutput = "term_output";
  static const termDefaultShellAuto = "term_default_shell_auto";
  static const termCopyAll = "term_copy_all";
  static const termSendAllToAi = "term_send_all_to_ai";
  static const termCopy = "term_copy";
  static const termSendToAi = "term_send_to_ai";

  // ── Git & Editor ──
  static const gitSwitchedBranch = "git_switched_branch";
  static const gitSwitchBranchFailed = "git_switch_branch_failed";
  static const gitSwitchBranchError = "git_switch_branch_error";
  static const gitConfirmDiscardChanges = "git_confirm_discard_changes";
  static const gitCommitAmend = "git_commit_amend";
  static const gitFilesChanged = "git_files_changed";
  static const gitLinesInserted = "git_lines_inserted";
  static const gitLinesDeleted = "git_lines_deleted";
  static const gitNoChangesLine = "git_no_changes_line";
  static const gitCopiedCommitHash = "git_copied_commit_hash";
  static const gitOpenOnGithub = "git_open_on_github";
  static const gitHunkRevertFailed = "git_hunk_revert_failed";
  static const gitRevertHunk = "git_revert_hunk";
  static const previewOnly = "preview_only";
  static const editAndPreview = "edit_and_preview";
  static const edMdPreview = "ed_md_preview";
  static const edMdRaw = "ed_md_raw";
  static const preview = "preview";
  static const edit = "edit";

  // ── Chat & Session ──
  static const chatBuildRunningError = "chat_build_running_error";
  static const chatExecutionFailed = "chat_execution_failed";
  static const chatPermissionRequestDesc = "chat_permission_request_desc";
  static const chatBuildLockedTitle = "chat_build_locked_title";
  static const chatBuildLockedDesc = "chat_build_locked_desc";
  static const chatTodoTitle = "chat_todo_title";
  static const chatChangedFilesTitle = "chat_changed_files_title";
  static const chatConfirmPermissionsFirst = "chat_confirm_permissions_first";
  static const chatFileCount = "chat_file_count";
  static const chatImageCount = "chat_image_count";
  static const chatQueuingWithParts = "chat_queuing_with_parts";
  static const chatQueuing = "chat_queuing";
  static const chatManualCompact = "chat_manual_compact";
  static const chatQuickPhrases = "chat_quick_phrases";
  static const chatSelectSessionFirst = "chat_select_session_first";
  static const chatLoadingMessages = "chat_loading_messages";
  static const chatStartConversation = "chat_start_conversation";
  static const chatLoadMessagesFailed = "chat_load_messages_failed";
  static const chatWaitGenerationToCompact = "chat_wait_generation_to_compact";
  static const chatForkFailed = "chat_fork_failed";
  static const chatManualCompactCompleted = "chat_manual_compact_completed";
  static const chatContextCompaction = "chat_context_compaction";
  static const chatCompactionFailed = "chat_compaction_failed";
  static const mcpConnectFailed = "mcp_connect_failed";
  static const permDenied = "perm_denied";
  static const permRequest = "perm_request";
  static const toolRequestingUse = "tool_requesting_use";
  static const permRead = "perm_read";
  static const permWrite = "perm_write";
  static const permExecute = "perm_execute";
  static const permWeb = "perm_web";
  static const defaultKeywordPossible = "default_keyword_possible";
  static const chatBuildFixedProblemsPrompt =
      "chat_build_fixed_problems_prompt";
  static const toolApprovedMsg = "tool_approved_msg";
  static const toolDeniedMsg = "tool_denied_msg";
  static const questionAskPrefix = "question_ask_prefix";
  static const questionAnswerPrefix = "question_answer_prefix";

  // ── Feedback Notifications ──
  static const feedbackTitle = "feedback_title";
  static const feedbackCompleted = "feedback_completed";
  static const feedbackCompletedMsg = "feedback_completed_msg";
  static const feedbackError = "feedback_error";
  static const feedbackErrorMsg = "feedback_error_msg";
  static const feedbackQuestion = "feedback_question";
  static const feedbackQuestionMsg = "feedback_question_msg";
  static const feedbackPermission = "feedback_permission";
  static const feedbackPermissionMsg = "feedback_permission_msg";

  // ── Skills ──
  static const skillsPathsTooltip = "skills_paths_tooltip";

  // ── Common/General ──
  static const ok = "common_ok";
  static const success = "common_success";
  static const error = "common_error";
  static const required = "common_required";
  static const duplicate = "common_duplicate";
  static const install = "common_install";

  // ── Rules Tab ──
  static const rulesClaudeCompatTitle = "rules_claude_compat_title";
  static const rulesClaudeCompatDesc = "rules_claude_compat_desc";
  static const rulesClaudeCompatEnv = "rules_claude_compat_env";
  static const rulesAddInstructionPath = "rules_add_instruction_path";
  static const rulesInstructionPathPlaceholder =
      "rules_instruction_path_placeholder";

  // ── Skills Tab ──
  static const skillsAdditionalPaths = "skills_additional_paths";
  static const skillsRemoteUrls = "skills_remote_urls";
  static const skillsLoadedSkills = "skills_loaded_skills";
  static const skillsSaveSources = "skills_save_sources";
  static const skillsSaveContent = "skills_save_content";
  static const skillsBuiltinReadOnly = "skills_builtin_read_only";
  static const skillsLocalFileSkill = "skills_local_file_skill";
  static const skillsBuiltinDesc = "skills_builtin_desc";
  static const skillsSelectFolderTip = "skills_select_folder_tip";
  static const skillsBrowseFolderTooltip = "skills_browse_folder_tooltip";
  static const skillsBack = "skills_back";

  // ── Providers Tab ──
  static const providersConnect = "providers_connect";
  static const providersShowAll = "providers_show_all";
  static const providersProviderId = "providers_provider_id";
  static const providersProviderIdPlaceholder =
      "providers_provider_id_placeholder";
  static const providersProviderIdError = "providers_provider_id_error";
  static const providersName = "providers_name";
  static const providersNamePlaceholder = "providers_name_placeholder";
  static const providersBaseUrl = "providers_base_url";
  static const providersBaseUrlPlaceholder = "providers_base_url_placeholder";
  static const providersBaseUrlError = "providers_base_url_error";
  static const providersApiKey = "providers_api_key";
  static const providersApiKeyPlaceholder = "providers_api_key_placeholder";
  static const providersAddModel = "providers_add_model";
  static const providersAddHeader = "providers_add_header";
  static const providersModelId = "providers_model_id";
  static const providersModelName = "providers_model_name";
  static const providersHeaderKey = "providers_header_key";
  static const providersHeaderValue = "providers_header_value";
  static const providersRecommended = "providers_recommended";
  static const providersEditKey = "providers_edit_key";
  static const providersDeleteKey = "providers_delete_key";
  static const providersAddKey = "providers_add_key";
  static const providersKeyUpdatePlaceholder =
      "providers_key_update_placeholder";
  static const providersKeyEnterPlaceholder = "providers_key_enter_placeholder";
  static const providersOauth = "providers_oauth";
  static const providersOauthSuccess = "providers_oauth_success";
  static const providersOauthFailed = "providers_oauth_failed";
  static const providersFetchModels = "providers_fetch_models";
  static const providersJsonConfig = "providers_json_config";
  static const providersFormatJson = "providers_format_json";
  static const providersSaveFailed = "providers_save_failed";
  static const providersJsonError = "providers_json_error";
  static const providersApiKeyRequired = "providers_api_key_required";
  static const providersFetchSuccess = "providers_fetch_success";
  static const providersFetchNoModels = "providers_fetch_no_models";
  static const providersFetchFailed = "providers_fetch_failed";
  static const providersConfigEdit = "providers_config_edit";

  // ── MCP Tab ──
  static const mcpAlreadyInstalled = "mcp_already_installed";
  static const mcpAlreadyInstalledDesc = "mcp_already_installed_desc";
  static const mcpGoToInstalled = "mcp_go_to_installed";
  static const mcpConfigureTitle = "mcp_configure_title";
  static const mcpEnvVarsRequired = "mcp_env_vars_required";
  static const mcpInstalledTab = "mcp_installed_tab";
  static const mcpDiscoverTab = "mcp_discover_tab";
  static const mcpRemoveTitle = "mcp_remove_title";
  static const mcpRemoveConfirm = "mcp_remove_confirm";

  // ── Agent Tab ──
  static const agentNewTitle = "agent_new_title";
  static const agentCreate = "agent_create";

  // ── Command Palette ──
  static const cmdSearchPlaceholder = "cmd_search_placeholder";

  // ── Git Notifications ──
  static const gitNoChangesDetected = "git_no_changes_detected";
  static const gitCommitFailed = "git_commit_failed";
  static const gitCommitError = "git_commit_error";
  static const gitStageFailed = "git_stage_failed";
  static const gitDiscardFailed = "git_discard_failed";
  static const providersProviderExists = "providers_provider_exists";
  static const headers = "common_headers";
  static const disconnect = "common_disconnect";
  static const gitStagedSuccess = "git_staged_success";
  static const gitDiscardedSuccess = "git_discarded_success";
  static const gitStagedTitle = "git_staged_title";
  static const gitDiscardedTitle = "git_discarded_title";
  static const startExecution = "start_execution";
  static const makePlan = "make_plan";

  // ── TODO Panel ──
  static const termTodo = "term_todo";
  static const todoEmpty = "todo_empty";
  static const todoScanning = "todo_scanning";
  static const todoScanError = "todo_scan_error";
  static const todoRefresh = "todo_refresh";
  static const todoSettings = "todo_settings";
  static const todoKeywords = "todo_keywords";
  static const todoCaseSensitive = "todo_case_sensitive";
  static const todoAddKeyword = "todo_add_keyword";
  static const todoExcludedFolders = "todo_excluded_folders";
  static const todoAddExcludedFolder = "todo_add_excluded_folder";

  // ── Mobile shell ──
  static const mobileAllSessions = "mobile_all_sessions";
  static const mobileOpenSessions = "mobile_open_sessions";
  static const mobileClearAllSessions = "mobile_clear_all_sessions";
  static const mobileToggleLeftPanel = "mobile_toggle_left_panel";
  static const mobileToggleRightPanel = "mobile_toggle_right_panel";
  static const mobileDisplay = "mobile_display";
  static const mobileNoOpenSessions = "mobile_no_open_sessions";
  static const mobileSelectProject = "mobile_select_project";
  static const mobileNoActiveSessions = "mobile_no_active_sessions";
  static const mobileCheckUpdates = "mobile_check_updates";
  static const mobileUpToDate = "mobile_up_to_date";
  static const mobileSseReconnecting = "mobile_sse_reconnecting";
  static const mobileSseAuthFailed = "mobile_sse_auth_failed";

  // ── Mobile shell (extended) ──
  static const mobileSettings = "mobile_settings";
  static const vadSettingsTitle = "vad_settings_title";
  static const vadThreshold = "vad_threshold";
  static const vadMinSilenceDuration = "vad_min_silence_duration";
  static const vadMinSpeechDuration = "vad_min_speech_duration";
  static const vadMaxSpeechDuration = "vad_max_speech_duration";
  static const vadSpeechPadMs = "vad_speech_pad_ms";
  static const vadResetDefault = "vad_reset_default";
  static const voiceContinuousInput = "voice_continuous_input";
  static const voiceContinuousInputDesc = "voice_continuous_input_desc";
  static const voiceAutoSend = "voice_auto_send";
  static const voiceAutoSendDesc = "voice_auto_send_desc";
  static const voiceSendCommand = "voice_send_command";
  static const voiceSendCommandHint = "voice_send_command_hint";
  static const voiceVadParams = "voice_vad_params";
  static const vadThresholdDesc = "vad_threshold_desc";
  static const vadMinSilenceDesc = "vad_min_silence_desc";
  static const vadMinSpeechDesc = "vad_min_speech_desc";
  static const vadMaxSpeechDesc = "vad_max_speech_desc";
  static const vadSpeechPadDesc = "vad_speech_pad_desc";
  static const voiceRecognitionErrorTitle = "voice_recognition_error_title";
  static const voiceListening = "voice_listening";
  static const voiceReleaseCancel = "voice_release_cancel";
  static const voiceReleaseInsert = "voice_release_insert";
  static const voiceReleaseHint = "voice_release_hint";
  static const voiceMicPermissionDeniedPermanent =
      "voice_mic_permission_denied_permanent";
  static const voiceMicPermissionDenied = "voice_mic_permission_denied";
  static const voiceMicPermissionRequestFailed =
      "voice_mic_permission_request_failed";
  static const voiceTranscriptionError = "voice_transcription_error";
  static const voiceRecordPermissionDenied = "voice_record_permission_denied";
  static const voiceRecordStreamError = "voice_record_stream_error";
  static const voiceStartFailed = "voice_start_failed";
  static const mobileOpenCodeSection = "mobile_opencode_section";
  static const mobileOpenCodeSettingsDesc = "mobile_opencode_settings_desc";
  static const mobileCheckingUpdates = "mobile_checking_updates";
  static const mobileAboutAppName = "mobile_about_app_name";
  static const mobileAboutLegalese = "mobile_about_legalese";
  static const mobileAboutDesc = "mobile_about_desc";
  static const mobileAboutVersion = "mobile_about_version";
  static const mobileHealth = "mobile_health";
  static const mobileServerConnection = "mobile_server_connection";
  static const mobileServerUrl = "mobile_server_url";
  static const mobileServerUrlRequired = "mobile_server_url_required";
  static const mobileConnectSidecar = "mobile_connect_sidecar";
  static const mobileConnectServer = "mobile_connect_server";
  static const mobileConnecting = "mobile_connecting";
  static const mobileStatus = "mobile_status";
  static const mobilePassword = "mobile_password";
  static const mobileNoProjects = "mobile_no_projects";
  static const mobileProjectsLoadFailed = "mobile_projects_load_failed";
  static const mobileProjects = "mobile_projects";
  static const mobileHiddenProjects = "mobile_hidden_projects";
  static const mobileHideProject = "mobile_hide_project";
  static const mobileUnhideProject = "mobile_unhide_project";
  static const mobileNoKeywordsYet = "mobile_no_keywords_yet";
  static const mobileNoSessions = "mobile_no_sessions";
  static const mobileNoMatchingSessions = "mobile_no_matching_sessions";
  static const mobileJustNow = "mobile_just_now";
  static const mobileMinutesAgo = "mobile_minutes_ago";
  static const mobileHoursAgo = "mobile_hours_ago";
  static const mobileDaysAgo = "mobile_days_ago";
  static const mobileLoginProviders = "mobile_login_providers";
  static const mobileKeywords = "mobile_keywords";
  static const mobileKeywordDetection = "mobile_keyword_detection";
  static const mobileEnableKeywordDetection = "mobile_enable_keyword_detection";
  static const mobileAddKeywordHint = "mobile_add_keyword_hint";
  static const mobilePhraseLabel = "mobile_phrase_label";
  static const mobilePhraseText = "mobile_phrase_text";
  static const mobileAttachFile = "mobile_attach_file";
  static const mobileAttachImage = "mobile_attach_image";
  static const mobileImageUnsupportedFormat = "mobile_image_unsupported_format";
  static const mobileImageHeicUnsupported = "mobile_image_heic_unsupported";
  static const mobileImageDescribePrompt = "mobile_image_describe_prompt";
  static const mobileImageDescribing = "mobile_image_describing";
  static const mobileImageDescribeFailed = "mobile_image_describe_failed";
  static const mobileImageToText = "mobile_image_to_text";
  static const mobileVisionSettings = "mobile_vision_settings";
  static const aboutTitle = "about_title";
  static const releasePageTitle = "release_page_title";
  static const releasePageSubtitle = "release_page_subtitle";
  static const openSourceLibrariesTitle = "open_source_libraries_title";
  static const openSourceLibrariesDesc = "open_source_libraries_desc";
  static const viewFullLicenses = "view_full_licenses";
  static const mobileSelectVisionModel = "mobile_select_vision_model";
  static const mobileNoVisionModelsHint = "mobile_no_vision_models_hint";
  static const mobileStopEsc = "mobile_stop_esc";
  static const mobileSendEnter = "mobile_send_enter";
  static const mobileRemoteTerminal = "mobile_remote_terminal";
  static const mobileNoQuickPhrasesHint = "mobile_no_quick_phrases_hint";
  static const mobileAddProject = "mobile_add_project";
  static const mobileAddProjectFailed = "mobile_add_project_failed";
  static const mobileServerPath = "mobile_server_path";
  static const mobileBrowseFiles = "mobile_browse_files";
  static const mobileFiles = "mobile_files";
  static const mobileIgnoredFile = "mobile_ignored_file";
  static const mobileEmptyDirectory = "mobile_empty_directory";
  static const mobileSessions = "mobile_sessions";
  static const mobileDeleteSessionTitle = "mobile_delete_session_title";
  static const mobileDeleteSessionConfirm = "mobile_delete_session_confirm";
  static const mobileDeleteSessionFailed = "mobile_delete_session_failed";
  static const mobileSearchSessions = "mobile_search_sessions";
  static const mobileReconnect = "mobile_reconnect";
  static const mobileConnected = "mobile_connected";
  static const mobileUnreachable = "mobile_unreachable";
  static const mobileUnknown = "mobile_unknown";
  static const mobileTapRefresh = "mobile_tap_refresh";
  static const mobileSaveAndReconnect = "mobile_save_and_reconnect";
  static const mobileReconnecting = "mobile_reconnecting";
  static const mobileConnectionFailed = "mobile_connection_failed";
  static const mobileCancelConnection = "mobile_cancel_connection";
  static const mobileAutoConnecting = "mobile_auto_connecting";
  static const mobileMessageDensity = "mobile_message_density";
  static const mobileCompact = "mobile_compact";
  static const mobileComfortable = "mobile_comfortable";
  static const mobileSpacious = "mobile_spacious";
  static const mobileCardVisibility = "mobile_card_visibility";
  static const mobileShowAll = "mobile_show_all";
  static const mobileHideAll = "mobile_hide_all";
  static const mobileNoDiff = "mobile_no_diff";
  static const mobileNoStepsYet = "mobile_no_steps_yet";
  static const mobileNoSteps = "mobile_no_steps";
  static const mobileConnectWithApiKey = "mobile_connect_with_api_key";
  static const mobileRevert = "mobile_revert";
  static const mobileLoadMore = "mobile_load_more";
  static const mobileHeaderKey = "mobile_header_key";
  static const mobileHeaderValue = "mobile_header_value";
  static const mobileAddItem = "mobile_add_item";
  static const mobileIgnorePatterns = "mobile_ignore_patterns";
  static const mobilePlugins = "mobile_plugins";
  static const mobilePluginEntries = "mobile_plugin_entries";
  static const mobileInstructionPaths = "mobile_instruction_paths";
  static const mobileAttachments = "mobile_attachments";
  static const mobileAutoResizeImages = "mobile_auto_resize_images";
  static const mobileMaxWidth = "mobile_max_width";
  static const mobileMaxHeight = "mobile_max_height";
  static const mobileMaxBase64Bytes = "mobile_max_base64_bytes";
  static const mobileEnableLsp = "mobile_enable_lsp";
  static const mobileEnableLspDesc = "mobile_enable_lsp_desc";
  static const mobileSavedPermissions = "mobile_saved_permissions";
  static const mobileDescription = "mobile_description";
  static const mobileModel = "mobile_model";
  static const mobileMode = "mobile_mode";
  static const mobileVariant = "mobile_variant";
  static const mobileTemperature = "mobile_temperature";
  static const mobileTopP = "mobile_top_p";
  static const mobileMaxSteps = "mobile_max_steps";
  static const mobileSystemPrompt = "mobile_system_prompt";
  static const mobileAgentNameRequired = "mobile_agent_name_required";
  static const mobileEnableFormatters = "mobile_enable_formatters";
  static const mobileFormatters = "mobile_formatters";
  static const mobileReferences = "mobile_references";
  static const mobileCustomCommands = "mobile_custom_commands";
  static const mobileNameRequired = "mobile_name_required";
  static const mobileTemplateRequired = "mobile_template_required";
  static const mobileAgent = "mobile_agent";
  static const mobileSubtask = "mobile_subtask";
  static const mobileAddReference = "mobile_add_reference";
  static const mobileRefText = "mobile_ref_text";
  static const mobileRefGit = "mobile_ref_git";
  static const mobileRefPath = "mobile_ref_path";
  static const mobileBranchOptional = "mobile_branch_optional";
  static const mobileMcpTimeoutHint = "mobile_mcp_timeout_hint";
  static const mobileMcpTimeoutInvalid = "mobile_mcp_timeout_invalid";
  static const mobileInvalidNumber = "mobile_invalid_number";
  static const mobileToolNameHint = "mobile_tool_name_hint";
  static const mobilePrimaryToolsHint = "mobile_primary_tools_hint";
  static const mobileBatchToolDesc = "mobile_batch_tool_desc";
  static const mobileDisablePasteDesc = "mobile_disable_paste_desc";
  static const mobileContinueLoopDesc = "mobile_continue_loop_desc";
  static const mobileOtelDesc = "mobile_otel_desc";

  // ── Card visibility labels ──
  static const cardVisReasoning = "card_vis_reasoning";
  static const cardVisThinking = "card_vis_thinking";
  static const cardVisSearch = "card_vis_search";
  static const cardVisRead = "card_vis_read";
  static const cardVisBash = "card_vis_bash";
  static const cardVisEdit = "card_vis_edit";
  static const cardVisBatch = "card_vis_batch";
  static const cardVisGlob = "card_vis_glob";
  static const cardVisGrep = "card_vis_grep";
  static const cardVisWeb = "card_vis_web";
  static const cardVisQuestion = "card_vis_question";
  static const cardVisTask = "card_vis_task";
  static const cardVisSubtask = "card_vis_subtask";
  static const cardVisSkill = "card_vis_skill";
  static const cardVisFallback = "card_vis_fallback";
  static const cardVisFile = "card_vis_file";
  static const cardVisAgent = "card_vis_agent";
  static const cardVisDiff = "card_vis_diff";

  // ── Terminal ──
  static const terminalSettings = "terminal_settings";
  static const terminalCurrentProjectOnly = "terminal_current_project_only";
  static const terminalCurrentProjectOnlyDesc =
      "terminal_current_project_only_desc";
  static const terminalShowExtraKeys = "terminal_show_extra_keys";
  static const terminalShowExtraKeysDesc = "terminal_show_extra_keys_desc";
  static const terminalShowQuickCommands = "terminal_show_quick_commands";
  static const terminalShowQuickCommandsDesc =
      "terminal_show_quick_commands_desc";
  static const terminalCloseCurrent = "terminal_close_current";
  static const terminalConfirmClose = "terminal_confirm_close";
  static const terminalFetchingList = "terminal_fetching_list";
  static const terminalNoRunning = "terminal_no_running";
  static const terminalClickPlusToCreate = "terminal_click_plus_to_create";
  static const terminalNew = "terminal_new";
  static const terminalTitle = "terminal_title";
  static const terminalSessionEnded = "terminal_session_ended";
  static const terminalConnectionLost = "terminal_connection_lost";
  static const terminalConnectionTimeout = "terminal_connection_timeout";
  static const terminalDeleteFailed = "terminal_delete_failed";

  // ── Tablet tool panel ──
  static const tabletCodeTab = "tablet_code_tab";
  static const tabletTerminalTab = "tablet_terminal_tab";
  static const tabletWebTab = "tablet_web_tab";
  static const tabletReviewTab = "tablet_review_tab";
  static const tabletToggleToolPanel = "tablet_toggle_tool_panel";
  static const tabletNoFileOpen = "tablet_no_file_open";
  static const tabletEnterUrl = "tablet_enter_url";

  // ── Review page ──
  static const reviewTypeMessage = "review_type_message";
  static const reviewTypeSession = "review_type_session";
  static const reviewTypeAll = "review_type_all";
  static const reviewLoadFailed = "review_load_failed";
  static const reviewEmptyHint = "review_empty_hint";
  static const reviewShowChangesOnly = "review_show_changes_only";
  static const reviewShowFull = "review_show_full";
  static const reviewPrevChange = "review_prev_change";
  static const reviewNextChange = "review_next_change";
  static const reviewPrevFile = "review_prev_file";
  static const reviewNextFile = "review_next_file";

  // ── Session extra ──
  static const sessionWaitGenerationFinish = "session_wait_generation_finish";
  static const sessionForkFailed = "session_fork_failed";
  static const sessionRevertFailed = "session_revert_failed";
  static const retryLimited = "session_retry_limited";
  static const retryLimitedReason = "session_retry_limited_reason";

  // ── MCP extra ──
  static const mcpAuthTitle = "mcp_auth_title";
  static const mcpAuthDesc = "mcp_auth_desc";
  static const mcpAuthCodeLabel = "mcp_auth_code_label";
  static const mcpRemoveAuthTitle = "mcp_remove_auth_title";
  static const mcpRemoveAuthConfirm = "mcp_remove_auth_confirm";
  static const mcpLocal = "mcp_local";
  static const mcpRemote = "mcp_remote";
  static const mcpNameRequired = "mcp_name_required";
  static const mcpNameExists = "mcp_name_exists";
  static const mcpUrlRequired = "mcp_url_required";
  static const mcpCommandRequired = "mcp_command_required";
  static const mcpAddFailed = "mcp_add_failed";
  static const mcpAuthSuccess = "mcp_auth_success";
  static const mcpAuthFailed = "mcp_auth_failed";
  static const mcpRemoveAuthSuccess = "mcp_remove_auth_success";

  // ── Developer extra ──
  static const developerEditCommand = "developer_edit_command";
  static const developerNewCommand = "developer_new_command";
  static const developerRefNameExists = "developer_ref_name_exists";

  // ── Permissions extra ──
  static const permissionsReplaceConfirm = "permissions_replace_confirm";

  // ── Quick Phrases extra ──
  static const quickPhrasesDeleteTitle = "quick_phrases_delete_title";
  static const quickPhrasesDeleteConfirm = "quick_phrases_delete_confirm";

  // ── Settings extra ──
  static const generalSaveUsernameFailed = "general_save_username_failed";
  static const modelsUpdateVisibilityFailed = "models_update_visibility_failed";
  static const connectionValidUrlRequired = "connection_valid_url_required";
  static const connectionReconnected = "connection_reconnected";
  static const connectionRefreshFailed = "connection_refresh_failed";
  static const connectionReconnectFailed = "connection_reconnect_failed";

  // ── Browser ──
  static const browserBack = "browser_back";
  static const browserForward = "browser_forward";
  static const browserRefresh = "browser_refresh";
  static const browserSwitchMobile = "browser_switch_mobile";
  static const browserSwitchDesktop = "browser_switch_desktop";
  static const browserOpenExternal = "browser_open_external";
  static const browserLoadFailed = "browser_load_failed";
  static const browserNewTab = "browser_new_tab";
  static const browserCloseTab = "browser_close_tab";
  static const browserCollapseToolbar = "browser_collapse_toolbar";
  static const browserExpandToolbar = "browser_expand_toolbar";
  static const browserCloseSheet = "browser_close_sheet";
  static const browserScreenshot = "browser_screenshot";
  static const browserScreenshotAdded = "browser_screenshot_added";
  static const browserScreenshotFailed = "browser_screenshot_failed";
  static const browserScreenshotFailedReason =
      "browser_screenshot_failed_reason";
  static const browserScreenshotNoSession = "browser_screenshot_no_session";

  // ── Preview Port ──
  static const previewBindTitle = "preview_bind_title";
  static const previewPortHint = "preview_port_hint";
  static const previewPortInvalid = "preview_port_invalid";
  static const previewPortClear = "preview_port_clear";
  static const previewBindPreview = "preview_bind_preview";

  // ── Terminal Extra ──
  static const terminalSentToNewSession = "terminal_sent_to_new_session";
  static const terminalSentToSession = "terminal_sent_to_session";
  static const terminalSelectSession = "terminal_select_session";
  static const terminalNoResults = "terminal_no_results";
  static const terminalCommandLabel = "terminal_command_label";
  static const terminalCommandRequired = "terminal_command_required";
  static const terminalNeedSession = "terminal_need_session";
  // ── Left Drawer Extra ──
  static const drawerBackToProjects = "drawer_back_to_projects";
  static const drawerBrowseFiles = "drawer_browse_files";
  static const drawerBackToProjectsDesc = "drawer_back_to_projects_desc";
  static const drawerBrowseFilesDesc = "drawer_browse_files_desc";
  // ── Quick Phrases Extra ──
  static const quickPhrasesEnterName = "quick_phrases_enter_name";
  static const quickPhrasesNameExists = "quick_phrases_name_exists";
  static const quickPhrasesEnterTemplate = "quick_phrases_enter_template";
  // ── Voice Extra ──
  static const voiceDownloadModelTitle = "voice_download_model_title";
  static const voiceDownloadFailed = "voice_download_failed";
  static const voicePreparingDownload = "voice_preparing_download";
  static const voiceDownloadPrompt = "voice_download_prompt";
  static const voiceCancelDownload = "voice_cancel_download";
  static const selectFileFromSidebar = "select_file_from_sidebar";
  static const selectFileFromLeftMenu = "select_file_from_left_menu";
  // ── Search ──
  static const searchPlaceholder = "search_placeholder";
  static const searchFiles = "search_files";
  static const searchText = "search_text";
  static const searchFilesPlaceholder = "search_files_placeholder";
  static const searchTextPlaceholder = "search_text_placeholder";
  static const searchNoResults = "search_no_results";
  static const searchLoading = "search_loading";

  // ── VCS / Git ──
  static const vcsBranch = "vcs_branch";
  static const vcsStatus = "vcs_status";
  static const vcsDefault = "vcs_default";
  static const vcsClean = "vcs_clean";
  static const vcsModified = "vcs_modified";
  static const vcsAdded = "vcs_added";
  static const vcsDeleted = "vcs_deleted";
  static const vcsUntracked = "vcs_untracked";
  static const vcsViewDiff = "vcs_view_diff";
  static const vcsNotGitRepo = "vcs_not_git_repo";
  static const vcsLoading = "vcs_loading";
  static const vcsChangedFiles = "vcs_changed_files";
  static const vcsBranchCopied = "vcs_branch_copied";
}

Map<String, String> languageMap = {"简体中文": "zh_CN", "English": "en_US"};

class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'zh_CN': _zhCN, 'en_US': _enUS};

  // ──────────────────────────────────────────────────────
  //  简体中文
  // ──────────────────────────────────────────────────────
  static const Map<String, String> _zhCN = {
    // ── Common ──
    LocaleKeys.cancel: '取消',
    LocaleKeys.save: '保存',
    LocaleKeys.delete: '删除',
    LocaleKeys.saveFailed: '保存失败',
    LocaleKeys.deleteFailed: '删除失败',
    LocaleKeys.close: '关闭',
    LocaleKeys.retry: '重试',
    LocaleKeys.search: '搜索',
    LocaleKeys.export: '导出',
    LocaleKeys.upgrade: '升级',
    LocaleKeys.upgrading: '升级中...',
    LocaleKeys.reload: '重新加载',
    LocaleKeys.add: '添加',
    LocaleKeys.remove: '移除',
    LocaleKeys.active: '已启用',
    LocaleKeys.notSet: '未设置',
    LocaleKeys.default_: '默认',
    LocaleKeys.unlimited: '无限制',
    LocaleKeys.yes: '是',
    LocaleKeys.no: '否',
    LocaleKeys.on_: '开',
    LocaleKeys.off: '关',
    LocaleKeys.auto: '自动',
    LocaleKeys.manual: '手动',
    LocaleKeys.disabled: '已禁用',
    LocaleKeys.notify: '通知',
    LocaleKeys.healthy: '正常',
    LocaleKeys.unhealthy: '异常',
    LocaleKeys.serverDefault: '服务端默认',
    LocaleKeys.restore: '恢复',

    // ── Snackbar ──
    LocaleKeys.snackSuccess: '成功',
    LocaleKeys.snackError: '出错',
    LocaleKeys.snackInfo: '提示',
    LocaleKeys.snackWarning: '警告',

    // ── Clipboard ──
    LocaleKeys.clipboardCopied: '已复制到剪贴板',
    LocaleKeys.clipboardCopyFailed: '复制失败，剪贴板可能被其他程序占用，请重试',

    // ── Start Page ──
    LocaleKeys.preparing: '正在准备 OpenCode',
    LocaleKeys.initLocalEnv: '正在初始化本地环境...',
    LocaleKeys.spawningSidecar: '正在启动本地 Sidecar 服务...',
    LocaleKeys.migratingSqlite: '正在迁移 SQLite 数据库 (@0%)...',
    LocaleKeys.systemReady: '系统就绪！',
    LocaleKeys.sidecarFailed: '本地 Sidecar 启动失败',

    // ── Titlebar ──
    LocaleKeys.menuFile: '文件',
    LocaleKeys.newProject: '新项目',
    LocaleKeys.noRecentProjects: '无最近打开的项目',
    LocaleKeys.recentProjects: '最近打开',

    // ── Command Palette ──
    LocaleKeys.cmdNewSession: '新建会话',
    LocaleKeys.cmdNewSessionDesc: '创建一个新的 AI 聊天会话',
    LocaleKeys.cmdOpenSettings: '打开设置',
    LocaleKeys.cmdOpenSettingsDesc: '配置服务商、Model 和快捷键',
    LocaleKeys.cmdToggleTheme: '切换主题',
    LocaleKeys.cmdToggleThemeDesc: '在深色和浅色模式之间切换',
    LocaleKeys.cmdToggleTerminal: '切换终端',
    LocaleKeys.cmdToggleTerminalDesc: '显示或隐藏终端面板',
    LocaleKeys.cmdToggleReview: '切换代码审查',
    LocaleKeys.cmdToggleReviewDesc: '显示或隐藏代码审查面板',
    LocaleKeys.cmdToggleSidebar: '切换侧边栏',
    LocaleKeys.cmdToggleSidebarDesc: '显示或隐藏侧边栏',
    LocaleKeys.cmdExportLogs: '导出日志',
    LocaleKeys.cmdExportLogsDesc: '将调试日志导出到文件',

    // ── Session Page ──
    LocaleKeys.allPanelsCollapsed: '所有面板已折叠\n使用标题栏按钮恢复它们',

    // ── Left Panel ──
    LocaleKeys.explorer: '资源管理器',
    LocaleKeys.searchLabel: '搜索',
    LocaleKeys.gitStatus: 'Git 状态',

    // ── Settings – Tabs ──
    LocaleKeys.tabGeneral: '通用',
    LocaleKeys.tabProviders: '服务商',
    LocaleKeys.tabModels: 'Model',
    LocaleKeys.tabMcp: 'MCP 服务',
    LocaleKeys.tabLsp: 'LSP',
    LocaleKeys.tabSkills: 'Skill',
    LocaleKeys.tabRules: '规则',
    LocaleKeys.tabAgent: 'Agent',
    LocaleKeys.tabPermissions: '权限',
    LocaleKeys.tabDeveloper: '开发者',
    LocaleKeys.tabAdvanced: '高级',
    LocaleKeys.tabExperimental: '实验性',
    LocaleKeys.tabConnection: '连接',
    LocaleKeys.opencodeSettingsTitle: 'OpenCode 设置',
    LocaleKeys.tabAbout: '关于',

    // ── Settings – Cloud Workspace (E2B) ──
    LocaleKeys.connModeSelfHosted: '自建服务器',
    LocaleKeys.connModeCloud: '☁️ E2B 云端沙盒',
    LocaleKeys.e2bTitle: 'E2B 云端开发工作区',
    LocaleKeys.e2bDesc: '无需本地服务器，基于 E2B MicroVM 秒级拉起专属云端 Linux 与 OpenCode 环境。',
    LocaleKeys.e2bApiKey: 'E2B API Key',
    LocaleKeys.e2bApiKeyHint: '从 e2b.dev/dashboard 获取的 API Key',
    LocaleKeys.e2bTemplate: '沙盒模板 ID',
    LocaleKeys.e2bTemplateHint: '默认 opencode (官方预建)',
    LocaleKeys.e2bToolchains: '预装开发工具链',
    LocaleKeys.e2bToolchainDart: '🎯 Dart SDK',
    LocaleKeys.e2bToolchainRust: '🦀 Rust & Cargo',
    LocaleKeys.e2bToolchainCpp: '🛠️ C/C++ (Clang/Make)',
    LocaleKeys.e2bToolchainPython: '🐍 Python 3',
    LocaleKeys.e2bGitConfig: 'Git 仓库自动同步',
    LocaleKeys.e2bGitRepo: '仓库地址',
    LocaleKeys.e2bGitRepoHint: 'https://github.com/owner/repo.git',
    LocaleKeys.e2bGitBranch: '分支名 (默认 main)',
    LocaleKeys.e2bGitToken: 'GitHub / Gitee Token',
    LocaleKeys.e2bGitTokenHint: 'Personal Access Token',
    LocaleKeys.e2bGitUsername: 'Git 提交者姓名',
    LocaleKeys.e2bGitEmail: 'Git 提交者邮箱',
    LocaleKeys.e2bLlmConfig: '云端大模型 API Key 注入',
    LocaleKeys.e2bAnthropicKey: 'Anthropic API Key',
    LocaleKeys.e2bOpenAiKey: 'OpenAI API Key',
    LocaleKeys.e2bGeminiKey: 'Gemini API Key',
    LocaleKeys.e2bDeepseekKey: 'DeepSeek API Key',
    LocaleKeys.e2bTtlHours: '云端保活周期',
    LocaleKeys.e2bTtlDesc: '设置云端实例保持运行的时长。手机锁屏或离线期间，云端 Agent 仍会持续执行长任务。',
    LocaleKeys.e2bAutoPause: '空闲自动休眠 (Auto-Pause)',
    LocaleKeys.e2bAutoPauseDesc: '仅在 Agent 任务已全部完成且空闲时，自动快照挂起沙盒以暂停计费并保留代码。',
    LocaleKeys.e2bLaunchWorkspace: '🚀 一键启动云工作区',
    LocaleKeys.e2bLaunchingWorkspace: '正在启动 E2B 云端沙盒...',
    LocaleKeys.e2bPauseSandbox: '挂起休眠',
    LocaleKeys.e2bResumeSandbox: '秒级唤醒',
    LocaleKeys.e2bDestroySandbox: '彻底销毁沙盒',
    LocaleKeys.e2bSandboxList: '沙盒实例列表',
    LocaleKeys.e2bCreateSandbox: '新建沙盒',
    LocaleKeys.e2bRefreshList: '刷新列表',
    LocaleKeys.e2bNoSandboxes: '暂无运行中的沙盒',
    LocaleKeys.e2bNoSandboxesDesc: '点击右上角「新建沙盒」一键拉起 MicroVM 开发环境',
    LocaleKeys.e2bApiKeyRequired: '需要配置 E2B API Key',
    LocaleKeys.e2bApiKeyRequiredDesc: '配置 API Key 后可直接在手机上查看与管理所有云端沙盒',
    LocaleKeys.e2bConfigApiKey: '配置 API Key',
    LocaleKeys.e2bCurrentlyConnected: '当前连接',
    LocaleKeys.e2bConnectSandbox: '进入沙盒',
    LocaleKeys.e2bConnectLastSandbox: '连接上次沙盒',
    LocaleKeys.e2bWakeAndConnect: '唤醒并连接',
    LocaleKeys.e2bManageSandboxes: '管理沙盒',
    LocaleKeys.e2bSandboxNotReadyWakeHint: '上次沙盒未就绪，可一键唤醒并连接',
    LocaleKeys.e2bCloudBackend: 'E2B 云端',
    LocaleKeys.selfHostedBackend: '自建服务器',
    LocaleKeys.e2bNoApiKey: '未配置 E2B API Key',
    LocaleKeys.e2bNoApiKeyDesc: '使用云端工作区前，请先在设置中填写 E2B API Key。',
    LocaleKeys.e2bNewSandbox: '新建沙盒',
    LocaleKeys.switchToSelfHosted: '切换至自建服务器',
    LocaleKeys.connectionDisconnected: '未连接',
    LocaleKeys.e2bClearInvalidSandbox: '清除无效沙盒记录',
    LocaleKeys.e2bConfirmDestroy: '确认销毁沙盒？',
    LocaleKeys.e2bConfirmDestroyDesc: '销毁后该沙盒将被彻底删除，未推送到 Git 的文件将丢失。',
    LocaleKeys.e2bSandboxStatusRunning: '运行中',
    LocaleKeys.e2bSandboxStatusPaused: '🟡 已挂起休眠',
    LocaleKeys.e2bSandboxDashboard: '云端沙盒控制台',
    LocaleKeys.e2bConfigWorkspace: '配置云工作区',
    LocaleKeys.e2bFetchRepos: '🔍 获取项目列表',
    LocaleKeys.e2bFetchingRepos: '正在获取仓库列表...',
    LocaleKeys.e2bSelectRepo: '选择要拉取的项目',
    LocaleKeys.e2bSearchRepos: '搜索项目名称...',
    LocaleKeys.e2bNoReposFound: '未找到匹配的仓库',
    LocaleKeys.e2bGitTokenRequiredForRepos:
        '请先填写 Personal Access Token 以便获取您的项目列表',
    LocaleKeys.e2bProvidersConfig: 'AI 大模型供应商配置',
    LocaleKeys.e2bConfigured: '已配置',
    LocaleKeys.e2bNotConfigured: '未设置',
    LocaleKeys.e2bCustomBaseUrl: '自定义 API Base URL',
    LocaleKeys.e2bCustomBaseUrlHint: 'https://api.openai.com/v1',
    LocaleKeys.e2bRepoSelected: '已选中 GitHub 项目: @repo',
    LocaleKeys.e2bTemplateHelper: '留空默认 opencode；可填自定义模板实现秒级启动',
    LocaleKeys.e2bGitProjectAndAuth: 'GitHub 项目与授权',
    LocaleKeys.e2bGitPatLabel: 'GitHub Personal Access Token (PAT)',
    LocaleKeys.e2bGitPatHint: 'ghp_xxxx (具备 repo 读写权限)',
    LocaleKeys.e2bFetchAndSelectRepo: '🔍 获取并选择我的 GitHub 项目',
    LocaleKeys.e2bSelectedRepoWithBranch: '已选仓库: @repo (@branch)',
    LocaleKeys.e2bGitRepoUrlOptionalHint: '可选：或直接粘贴 GitHub 仓库地址',
    LocaleKeys.e2bFetchReposFailed: '获取 GitHub 仓库失败: @error',
    LocaleKeys.e2bFetchReposTokenError: '获取项目失败，请检查 GitHub Token 权限',
    LocaleKeys.e2bSelectGitHubRepo: '选择 GitHub 项目',
    LocaleKeys.e2bFetchingRepoList: '正在获取您的 GitHub 仓库列表...',
    LocaleKeys.e2bLaunchPreparing: '正在准备启动 E2B 云端沙盒...',
    LocaleKeys.e2bApiKeyEmptyError: 'E2B API Key 不能为空，请先在设置中填写',
    LocaleKeys.e2bLaunchRequestingVm: '正在向 E2B 申请微型虚拟机沙盒...',
    LocaleKeys.e2bLaunchFailed: '启动云端沙盒失败',
    LocaleKeys.e2bLaunchConnecting: '沙盒就绪，正在与本地建立安全连接...',
    LocaleKeys.e2bHandshakeFailed: 'OpenCode 连接握手失败',
    LocaleKeys.e2bWorkspaceReady: 'E2B 云端工作区已连接并就绪',
    LocaleKeys.e2bLaunchErrorTitle: '启动遇到问题',
    LocaleKeys.e2bSandboxPreservedHint: '沙盒实例已保留，可在连接页沙盒列表中销毁或重新连接。',
    LocaleKeys.e2bConnectFailed: '连接沙盒失败',
    LocaleKeys.e2bServiceUnreachable: '无法连接到沙盒 OpenCode 服务',
    LocaleKeys.e2bConnectedToSandbox: '已连接至 E2B 沙盒: @id',
    LocaleKeys.e2bConnectionError: '连接失败: @error',
    LocaleKeys.e2bSandboxPausedSuccess: '沙盒 @id 已挂起休眠',
    LocaleKeys.e2bSandboxPauseFailed: '挂起沙盒失败: @error',
    LocaleKeys.e2bSandboxResumedSuccess: '沙盒 @id 已唤醒就绪',
    LocaleKeys.e2bSandboxResumeFailed: '唤醒沙盒失败: @error',
    LocaleKeys.e2bSandboxDestroyedSuccess: '沙盒 @id 已销毁释放',
    LocaleKeys.e2bSandboxDestroyFailed: '销毁沙盒失败: @error',
    LocaleKeys.e2bCheckingStatus: '正在检查云端沙盒状态...',
    LocaleKeys.e2bSandboxConnected: '云端沙盒已连接',
    LocaleKeys.e2bAuthFailedTitle: '沙盒服务运行中 (认证未通过)',
    LocaleKeys.e2bAuthFailedDesc: '密码不匹配，可在列表中重新连接',
    LocaleKeys.e2bServiceNotReadyTitle: '沙盒服务未就绪 (HTTP @status)',
    LocaleKeys.e2bServiceNotReadyDesc: 'OpenCode 未启动，在列表中点击连接修复',
    LocaleKeys.e2bSandboxDisconnected: '云端沙盒未连接',
    LocaleKeys.e2bSandboxDisconnectedDesc: '@id · 在列表中点击连接',
    LocaleKeys.e2bNoActiveSandbox: '未连接云端沙盒',
    LocaleKeys.e2bNoActiveSandboxDesc: '新建或在列表中选择沙盒',
    LocaleKeys.e2bFetchingSandboxes: '正在获取 E2B 沙盒列表...',
    LocaleKeys.e2bFetchSandboxesFailed: '获取沙盒列表失败: @error',
    LocaleKeys.e2bStartedAt: '启动于 @time',
    LocaleKeys.e2bExpiresAt: '过期于 @time',
    LocaleKeys.e2bCopySandboxId: '复制沙盒 ID',
    LocaleKeys.e2bProbingSandbox: '正在探测 E2B 云端沙盒状态...',
    LocaleKeys.e2bSandboxLabel: '沙盒: @id',

    // ── Settings – General ──
    LocaleKeys.secAppearance: '外观与布局',
    LocaleKeys.colorTheme: '颜色主题',
    LocaleKeys.colorThemeDesc: '在深色和浅色模式之间切换。',
    LocaleKeys.dark: '深色',
    LocaleKeys.light: '浅色',
    LocaleKeys.language: '语言',
    LocaleKeys.languageDesc: '切换应用的显示语言。',
    LocaleKeys.wslIntegration: 'WSL 集成',
    LocaleKeys.wslIntegrationDesc:
        '使用 Windows Subsystem for Linux 执行 Shell 命令。',
    LocaleKeys.debugLogs: '调试日志',
    LocaleKeys.debugLogsDesc: '将应用日志导出到指定文件夹。',

    LocaleKeys.secNotifications: '通知',
    LocaleKeys.notificationSound: '通知音效',
    LocaleKeys.notificationSoundDesc: 'AI 完成生成时播放提示音。',

    LocaleKeys.secShell: 'Shell 与环境',
    LocaleKeys.defaultShell: '默认 Shell',
    LocaleKeys.defaultShellDesc: '终端会话使用的 Shell。',
    LocaleKeys.logLevel: '日志级别',
    LocaleKeys.logLevelDesc: '记录的最低日志级别。',
    LocaleKeys.username: '用户名',
    LocaleKeys.usernameDesc: '共享会话中显示的名称。',
    LocaleKeys.usernamePlaceholder: '输入用户名...',

    LocaleKeys.secSharing: '共享与更新',
    LocaleKeys.sharingMode: '共享模式',
    LocaleKeys.sharingModeDesc: '控制会话的共享方式。',
    LocaleKeys.autoUpdate: '自动更新',
    LocaleKeys.autoUpdateDesc: '何时检查并应用更新。',
    LocaleKeys.snapshotTracking: '快照追踪',
    LocaleKeys.snapshotTrackingDesc: '启用基于快照的文件变更版本追踪。',
    LocaleKeys.snapshotWarningTitle: 'Snapshot 未关闭',
    LocaleKeys.snapshotWarningDesc:
        'opencode 内置的 snapshot 文件追踪仍为开启状态，部分功能可能与之冲突。\n请在 opencode.jsonc 中设置 "snapshot": false 后重试。',
    LocaleKeys.csCacheBlockedBySnapshot:
        '缓存操作被阻止：snapshot 未关闭。请在 opencode.jsonc 中设置 "snapshot": false。',

    LocaleKeys.secCompaction: '压缩',
    LocaleKeys.autoCompaction: '自动压缩',
    LocaleKeys.autoCompactionDesc: '自动压缩长对话以节省上下文。',
    LocaleKeys.pruneOldOutputs: '清除旧输出',
    LocaleKeys.pruneOldOutputsDesc: '压缩时移除过时的工具输出。',

    // ── Settings – About ──
    LocaleKeys.secServerStatus: '服务状态',
    LocaleKeys.openCodeVersion: 'OpenCode 版本',
    LocaleKeys.checkForUpdates: '检查更新',
    LocaleKeys.checkForUpdatesDesc: '将 OpenCode 升级到最新版本。',
    LocaleKeys.secToolOutput: '工具输出',
    LocaleKeys.maxLines: '最大行数',
    LocaleKeys.maxLinesDesc: '每次工具调用捕获的最大输出行数。',
    LocaleKeys.maxBytes: '最大字节数',
    LocaleKeys.maxBytesDesc: '每次工具调用的最大输出大小（字节）。',
    LocaleKeys.secCompactionAbout: '压缩',
    LocaleKeys.tailTurns: '保留轮次',
    LocaleKeys.tailTurnsDesc: '压缩时保留的最近对话轮数。',
    LocaleKeys.reservedTokens: '保留 Token',
    LocaleKeys.reservedTokensDesc: '为响应保留的上下文窗口 Token 数。',

    // ── Settings – Providers ──
    LocaleKeys.providers: '服务商',
    LocaleKeys.secConnectedProviders: '已添加的服务商',
    LocaleKeys.noConnectedProviders: '没有已添加的服务商',
    LocaleKeys.secAllProviders: '所有服务商',
    LocaleKeys.searchProvidersPlaceholder: '搜索服务商...',
    LocaleKeys.noMatchingProviders: '没有匹配的服务商',
    LocaleKeys.secCustomProvider: '自定义服务商',
    LocaleKeys.customProviderTag: '自定义',
    LocaleKeys.customProvider: '自定义服务商',
    LocaleKeys.customProviderDesc: '添加兼容 OpenAI 的自定义服务商和 Model。',
    LocaleKeys.secBlockedProviders: '已屏蔽的供应商',
    LocaleKeys.noBlockedProviders: '暂无屏蔽的供应商',
    LocaleKeys.providersRestored: '供应商已恢复',

    // ── Settings – Models ──
    LocaleKeys.models: 'Model',
    LocaleKeys.smallModel: '小型 / 快速 Model',
    LocaleKeys.smallModelDesc: '用于快速操作和压缩的轻量 Model。',
    LocaleKeys.searchModelsPlaceholder: '搜索 Model...',
    LocaleKeys.noModelsLoaded: '没有已加载的 Model。',
    LocaleKeys.noMatchingModels: '没有匹配的 Model。',

    // ── Settings – MCP ──
    LocaleKeys.addMcpServer: '添加 MCP 服务',
    LocaleKeys.serverNamePlaceholder: '服务名称（如 my-mcp）',
    LocaleKeys.connectionType: '连接类型',
    LocaleKeys.localStdio: '本地 (stdio)',
    LocaleKeys.localSse: '本地 (sse)',
    LocaleKeys.remoteUrl: '远程 (URL)',
    LocaleKeys.commandPlaceholder: '命令（如 npx, uvx, node）',
    LocaleKeys.argsPlaceholder: '参数（空格分隔）',
    LocaleKeys.serverUrlPlaceholder: '服务 URL（如 http://localhost:3000）',

    // ── Settings – Permissions ──
    LocaleKeys.secBulkActions: '批量操作',
    LocaleKeys.applyToAllTools: '应用于所有工具：',
    LocaleKeys.ask: '询问',
    LocaleKeys.allow: '允许',
    LocaleKeys.deny: '拒绝',
    LocaleKeys.toolPermissions: '工具权限',

    // ── Settings – Agent ──
    LocaleKeys.agentConfigs: 'Agent 配置',
    LocaleKeys.newAgent: '新建 Agent',
    LocaleKeys.noAgentsConfigured: '没有已配置的 Agent。',
    LocaleKeys.failedToLoadAgents: '加载 Agent 失败',

    // ── Settings – Developer ──
    LocaleKeys.developer: '开发者',
    LocaleKeys.secCommands: '命令',
    LocaleKeys.addCommand: '添加命令',
    LocaleKeys.cmdNamePlaceholder: '命令名称（不含 /）',

    // ── Settings – Advanced ──
    LocaleKeys.advanced: '高级',

    // ── Settings – Experimental ──
    LocaleKeys.experimental: '实验性',
    LocaleKeys.secFeatures: '功能',
    LocaleKeys.batchTool: '批量工具',
    LocaleKeys.batchToolDesc: '启用批量工具以并行运行多个工具。',
    LocaleKeys.disablePasteSummary: '禁用粘贴摘要',
    LocaleKeys.disablePasteSummaryDesc: '粘贴内容到聊天时跳过摘要。',
    LocaleKeys.continueLoopOnDeny: '拒绝时继续循环',
    LocaleKeys.continueLoopOnDenyDesc: '工具调用被拒绝时继续 Agent 循环。',
    LocaleKeys.openTelemetry: 'OpenTelemetry',
    LocaleKeys.openTelemetryDesc: '为 AI SDK 调用启用 OpenTelemetry 追踪。',
    LocaleKeys.fileWatcher: '文件监视器',
    LocaleKeys.fileWatcherDesc: '文件变更检测后端。',
    LocaleKeys.fileWatcherRestartHint: '需要重启本地 Sidecar 服务后生效。',
    LocaleKeys.restartSidecar: '重启 Sidecar',
    LocaleKeys.sidecarRestarting: '正在重启 Sidecar...',
    LocaleKeys.sidecarRestarted: 'Sidecar 已重启，设置已生效。',
    LocaleKeys.sidecarRestartFailed: 'Sidecar 重启失败，请查看日志后重试。',
    LocaleKeys.settingsBlockedByGeneration: '当前有会话正在生成，完成或中止后再修改此设置。',
    LocaleKeys.secMcp: 'MCP',
    LocaleKeys.mcpTimeout: 'MCP 超时（毫秒）',
    LocaleKeys.mcpTimeoutDesc: 'MCP 请求的超时时间（毫秒）。',
    LocaleKeys.secPrimaryTools: '主要工具',
    LocaleKeys.primaryTools: '主要工具',
    LocaleKeys.primaryToolsDesc: '仅对主要 Agent 可用的工具。',

    // ── Settings – Rules ──
    LocaleKeys.globalAgentsMd: '全局 AGENTS.md',
    LocaleKeys.globalAgentsDesc: '应用于所有 OpenCode 会话的规则。',
    LocaleKeys.globalAgentsReadOnlyBanner: '远程客户端无法写入 AGENTS.md，请在服务器或桌面端编辑。',
    LocaleKeys.enterGlobalRules: '输入全局规则（Markdown）...',
    LocaleKeys.instructions: '指令文件 (opencode.json)',
    LocaleKeys.instructionsDesc: '从 opencode.json 引用的额外指令文件。',
    LocaleKeys.noCustomInstructions: '没有配置自定义指令。',
    LocaleKeys.globalRulesSaved: '全局规则保存成功。',
    LocaleKeys.saved: '已保存',

    // ── Settings – Skills ──
    LocaleKeys.skillSavedSuccess: 'Skill 保存成功！',
    LocaleKeys.skillSaveFailed: '保存 Skill 失败',
    LocaleKeys.skillsFailedLoad: '加载失败',
    LocaleKeys.skillsNoLoaded: '没有已加载的 Skill。',

    // ── Tool Cards ──
    LocaleKeys.enterYourAnswer: '输入你的答案...',
    LocaleKeys.enterYourAnswerHere: '在此输入你的答案...',

    // ── Git Diff ──
    LocaleKeys.rolledBack: '已回滚当前变更块',

    // ── Editor Panel ──
    LocaleKeys.edKeyboardShortcuts: '快捷键',
    LocaleKeys.edTypography: '排版',
    LocaleKeys.edEditorFeatures: '编辑器功能',
    LocaleKeys.edShowLineNumbers: '显示行号',
    LocaleKeys.edEnableCodeFolding: '启用代码折叠',
    LocaleKeys.edShowGuideLines: '显示参考线',
    LocaleKeys.edFormatOnSave: '保存时自动格式化',
    LocaleKeys.edHighlightTheme: '高亮主题',
    LocaleKeys.edFollowSystem: '跟随系统 (自动)',
    LocaleKeys.edWorkflow: '工作流',
    LocaleKeys.edAutoSendDiagnostics: 'Build 后自动发送诊断',
    LocaleKeys.edAutoSendDiagnosticsDesc: '自动发送 Build 错误和警告到聊天。',
    LocaleKeys.edLspServers: '编辑器 LSP 服务',
    LocaleKeys.edNoLspServers: '没有配置 LSP 服务。',
    LocaleKeys.edTabNavigation: '标签导航',
    LocaleKeys.edFileOperations: '文件操作',
    LocaleKeys.edEditorOperations: '编辑器操作',
    LocaleKeys.edReset: '重置',
    LocaleKeys.edPreviousTab: '上一个标签',
    LocaleKeys.edNextTab: '下一个标签',
    LocaleKeys.edEditorSettings: '编辑器设置',
    LocaleKeys.edUnsavedChanges: '未保存的更改',
    LocaleKeys.edUnsavedChangesDesc: '以下文件有未保存的更改，关闭将丢失这些更改。',
    LocaleKeys.edDiskChangedTitle: '磁盘文件已变更',
    LocaleKeys.edDiskChangedDesc:
        '"@file" 在此标签页存在未保存编辑时被磁盘上的版本修改。\n\n请选择是用当前编辑器缓冲区覆盖磁盘，还是重新加载磁盘版本。',
    LocaleKeys.edDiskChangedTooltip: '磁盘文件已变更，且当前标签页有未保存编辑',
    LocaleKeys.edSaveCurrentBuffer: '保存当前缓冲区',
    LocaleKeys.edClose: '关闭',
    LocaleKeys.edCloseOthers: '关闭其他',
    LocaleKeys.edCloseRight: '关闭右侧标签页',
    LocaleKeys.edCloseSaved: '关闭已保存',
    LocaleKeys.edCloseAll: '全部关闭',
    LocaleKeys.edCopyPath: '复制路径',
    LocaleKeys.edCopyRelativePath: '复制相对路径',
    LocaleKeys.edWaitingForKeys: '等待按键...',
    LocaleKeys.edCopyAbsPathFailed: '复制绝对路径失败',
    LocaleKeys.edCopyRelPathFailed: '复制相对路径失败',
    LocaleKeys.edFontSize: '字体大小：',
    LocaleKeys.edFontFamily: '字体名称：',
    LocaleKeys.edLayoutIndentation: '布局与缩进',
    LocaleKeys.edTabSize: '缩进大小：',
    LocaleKeys.ed2Spaces: '2 个空格',
    LocaleKeys.ed4Spaces: '4 个空格',
    LocaleKeys.edTheme: '主题',
    LocaleKeys.edLspDesc: '启用或禁用编辑器中的语言服务，以提供代码诊断和补全功能。',
    LocaleKeys.lspInstalled: '已安装',
    LocaleKeys.lspMissing: '缺失',
    LocaleKeys.lspExecutable: '可执行文件：@cmd',
    LocaleKeys.lspPathWarning: '警告：未在系统环境变量 PATH 中找到可执行文件 "@cmd"。',
    LocaleKeys.edWordWrap: '自动换行',
    LocaleKeys.edEnableWordWrap: '启用自动换行',
    LocaleKeys.edDisableWordWrap: '禁用自动换行',
    LocaleKeys.edSourceMode: '源码模式',
    LocaleKeys.edPreviewMode: '预览模式',
    LocaleKeys.edZoomIn: '放大字体',
    LocaleKeys.edZoomOut: '缩小字体',
    LocaleKeys.edCopyAll: '复制全文',
    LocaleKeys.edCopied: '已复制',
    LocaleKeys.edFindPlaceholder: '搜索...',
    LocaleKeys.edFindNoResult: '无结果',
    LocaleKeys.edFindPrevious: '上一个',
    LocaleKeys.edFindNext: '下一个',
    LocaleKeys.edCaseSensitive: '区分大小写',
    LocaleKeys.edRegex: '正则表达式',
    LocaleKeys.edCloseSearch: '关闭搜索',

    // ── Chat Setting ──
    LocaleKeys.csShowThinking: '显示思考',
    LocaleKeys.csShowThinkingDesc: '在时间线中显示 Model 推理内容。',
    LocaleKeys.csTabDisplay: '显示配置',
    LocaleKeys.csTabBuild: 'Build 配置',
    LocaleKeys.csMultiBuild: '多 Build',
    LocaleKeys.csMultiBuildDesc: '允许多个会话同时运行 Build Agent。',
    LocaleKeys.csShell: 'Shell',
    LocaleKeys.csShellDesc: '执行完成后自动折叠 bash 命令卡片',
    LocaleKeys.csKeywordDetection: '关键词检测',
    LocaleKeys.csKeywordDetectionDesc: 'AI 输出完成后检测本轮 text/markdown 内容',
    LocaleKeys.csQuickPhrases: '常用语',
    LocaleKeys.csAutoSend: '自动发送',
    LocaleKeys.csAutoSendDesc: '开启后点击常用语会直接发送。',
    LocaleKeys.csAdd: '新增',
    LocaleKeys.csNoQuickPhrases: '暂无常用语',
    LocaleKeys.csEdit: '编辑',
    LocaleKeys.csInputKeyword: '输入关键词',
    LocaleKeys.csInputPhrase: '输入常用语',
    LocaleKeys.csTabReview: '代码审查',
    LocaleKeys.csReviewScope: '审查范围',
    LocaleKeys.csReviewScopeDesc: '选择代码审查的文件范围',
    LocaleKeys.csReviewScopeUncommitted: '未提交的文件',
    LocaleKeys.csReviewScopeCurrentWindow: '本窗口修改的文件',
    LocaleKeys.csReviewModel: '审查模型',
    LocaleKeys.csReviewModelDesc: '选择用于代码审查的模型',
    LocaleKeys.csReviewThinkingLevel: '思考级别',
    LocaleKeys.csReviewThinkingLevelDesc: '选择模型的思考/推理级别',
    LocaleKeys.csReviewPrompt: '审查 Prompt',
    LocaleKeys.csReviewPromptDesc: '自定义发送给大模型的审查指令',
    LocaleKeys.csReviewPromptReset: '恢复默认',
    LocaleKeys.csWatcherDiffOverlay: '显示磁盘变更 Diff',
    LocaleKeys.csWatcherDiffOverlayDesc:
        '开启后，文件监控检测到的磁盘变更也会显示为待处理 Diff；关闭时，这些变更会被视为已接受内容并推进基线。',
    LocaleKeys.csPromptSuggest: '自动联想',
    LocaleKeys.csPromptSuggestEnabled: '启用 @ 联想',
    LocaleKeys.csPromptSuggestEnabledDesc: '在 Prompt 输入框中键入 @ 时自动联想文件与符号',
    LocaleKeys.csPromptSuggestPaths: '扫描路径',
    LocaleKeys.csPromptSuggestPathsDesc:
        '手动指定当前项目中需要扫描并联想的子目录路径；留空则扫描整个项目。自动遵循 .gitignore 和 .ignore',
    LocaleKeys.csInputPath: '输入扫描子路径（如 lib 或 rust/src）...',
    LocaleKeys.csPromptSuggestExclude: '排除目录',
    LocaleKeys.csPromptSuggestExcludeDesc:
        '扫描时跳过这些目录名的目录（按目录名匹配，如 target、build）',
    LocaleKeys.csInputExcludeName: '输入目录名（如 build）...',
    LocaleKeys.csCache: 'Diff 核心',
    LocaleKeys.csCacheNoGitignore: '未找到 .gitignore，Diff 缓存暂时不可用。',
    LocaleKeys.csCacheTrackedPaths: '追踪路径',
    LocaleKeys.csCacheTrackedPathsDesc:
        '不填就缓存项目中未被 .gitignore 忽略的文件。只想缓存部分文件时，填 lib、rust/src、pubspec.yaml 这类路径。',
    LocaleKeys.csCacheAddTrackedPath: '添加追踪路径',
    LocaleKeys.csCacheExtraExcludes: '额外排除路径',
    LocaleKeys.csCacheAddExcludedPath: '添加排除路径',
    LocaleKeys.csCacheInvalidPath: '路径必须是项目内的相对路径，且不能包含 . 或 ..：@path',
    LocaleKeys.csCacheRebuildTitle: '重建备份缓存',
    LocaleKeys.csCacheRebuildContent:
        '此操作将删除现有的 .opencode-git 缓存并重建。旧的检查点和撤销点将丢失。',
    LocaleKeys.csCacheRebuild: '重建',
    LocaleKeys.csCacheRefresh: '刷新缓存',
    LocaleKeys.csCacheRebuildBtn: '重建缓存',
    LocaleKeys.csCacheCompress: '压缩缓存',
    LocaleKeys.csCacheOpenFolder: '打开文件夹',
    LocaleKeys.csCacheOpCompleted: 'Diff 缓存处理完成。',
    LocaleKeys.csCacheOpFailed: 'Diff 缓存处理失败：@error',
    LocaleKeys.csCacheGitignoreRequired:
        '没有找到 .gitignore，已跳过 Diff 缓存。请先创建 .gitignore，再重新打开项目或在设置里重建缓存。',
    LocaleKeys.csTabMultiSession: '多会话分发',
    LocaleKeys.csMultiSessionModel: '选择模型',
    LocaleKeys.csMultiSessionThinkingLevel: '思考级别',
    LocaleKeys.csMultiSessionThinkingLevelDesc: '设置模型的思考级别。',
    LocaleKeys.csMultiSessionConfiguredListTitle: '已配置模型',
    LocaleKeys.csMultiSessionEmptyList: '暂未添加任何模型',
    LocaleKeys.chatMultiSessionTooltip: '一次调用多个模型（仅Plan模式）',

    // ── Prompt Input ──
    LocaleKeys.piBuildRunning: '会话正在执行 Build...',
    LocaleKeys.piBuildFailed: '执行失败',
    LocaleKeys.piSecurityRequest: '安全确权请求',
    LocaleKeys.piDenyOperation: '拒绝操作',
    LocaleKeys.piAlwaysAllow: '始终允许',
    LocaleKeys.piAllowExecute: '允许执行',
    LocaleKeys.piTodoItems: '待办事项',
    LocaleKeys.piChangedFiles: '已更改文件',
    LocaleKeys.piSelectSession: '选择一个会话开始...',
    LocaleKeys.piAttachFile: '附加文件 (Ctrl+U)',
    LocaleKeys.piBuildLocked: 'Build 被其他会话锁定',
    LocaleKeys.piStop: '停止 (Esc)',
    LocaleKeys.piNoAgent: '无 Agent',
    LocaleKeys.piKeep: '保留',
    LocaleKeys.piKeepAll: '保留',
    LocaleKeys.piCancelAll: '取消',
    LocaleKeys.piSendNow: '立即发送',
    LocaleKeys.inputPanelsSection: '输入框面板控制',
    LocaleKeys.inputPanelTodo: 'Todo 待办列表面板',
    LocaleKeys.inputPanelDiff: 'Changed Files 变更文件面板',

    // ── Session Header ──
    LocaleKeys.shSessionTitle: 'OpenCode 会话',
    LocaleKeys.shSessionsHistory: '会话历史',
    LocaleKeys.shChatSettings: '聊天设置',
    LocaleKeys.shUndoRevert: '撤销回滚',
    LocaleKeys.shUndoRevertDesc: '是否撤销之前的回滚操作？',
    LocaleKeys.shUndoRevertDescWithFiles:
        '是否撤销之前的回滚？将恢复会话消息，并恢复 @count 个已回滚文件。',
    LocaleKeys.shUndoRevertDescChatOnly:
        '是否撤销之前的回滚？仅能恢复会话消息。本机未保留回滚文件列表（常见于重启后或当时仅回滚消息），工作区文件无法恢复。',
    LocaleKeys.shCancelRevert: '取消回滚',
    LocaleKeys.shConfirmRevert: '确认回滚',
    LocaleKeys.shConfirmRevertDesc: '是否回滚到这条用户消息？此操作会撤销之后的会话变更。',
    LocaleKeys.shConfirmRevertAffected: '将恢复的文件',
    LocaleKeys.shConfirmRevertNoFiles: '此选项下无文件变更',
    LocaleKeys.shConfirmRevertSummary: '@files 个文件 · +@add -@del',
    LocaleKeys.shConfirmRevertCheckpointMissing:
        '找不到该消息的检查点，确认后只会回滚会话消息，无法恢复工作区文件。',
    LocaleKeys.shConfirmRevertWorkspaceMissing: '工作区备份基线不可用，无法预览或恢复文件。请稍后重试。',
    LocaleKeys.shConfirmRevertPreviewFailed: '无法预览受影响的文件，请稍后重试。',
    LocaleKeys.shConfirmRevertScopeTitle: '文件恢复范围',
    LocaleKeys.shConfirmRevertScopeChat: '仅回滚消息',
    LocaleKeys.shConfirmRevertScopeChatDesc: '只撤销之后的会话消息，不改动磁盘文件。',
    LocaleKeys.shConfirmRevertScopeSession: '仅本会话相关文件',
    LocaleKeys.shConfirmRevertScopeSessionDesc: '只恢复本会话跟踪过的文件，一般不会影响其他会话。',
    LocaleKeys.shConfirmRevertScopeWorkspace: '全量工作区恢复',
    LocaleKeys.shConfirmRevertScopeWorkspaceDesc:
        '按该消息检查点恢复工作区全部差异文件，可能覆盖其他会话或手动修改。',
    LocaleKeys.shConfirmRevertRelatedMissing:
        '无法识别本会话文件归属（常见于重启后）。默认仅回滚消息；若需要恢复文件，请手动选择“全量工作区恢复”。',
    LocaleKeys.shConfirmRevertWorkspaceRisk: '警告：全量恢复可能影响其他会话改动的文件。',
    LocaleKeys.shRevertBlockedGenerating: '生成进行中，请等待完成后再回滚。',
    LocaleKeys.shRevertCheckpointMissingChatOnly: '找不到消息检查点，已改为仅回滚会话消息。',
    LocaleKeys.shRevertFailed: '回滚失败，请查看日志后重试。',
    LocaleKeys.shRevertFailedAfterPartial: '回滚过程出错，会话消息已尝试恢复。请检查工作区文件是否一致。',
    LocaleKeys.shRevertCompensationFailed: '回滚失败，且无法自动恢复会话消息。聊天与文件可能不一致，请手动检查。',
    LocaleKeys.shUnrevertFailed: '取消回滚失败，请查看日志后重试。',
    LocaleKeys.shUnrevertChatOnlyNoFiles: '已取消消息回滚；没有可恢复的文件记录。',
    LocaleKeys.shSessionHistory: '会话历史',
    LocaleKeys.shSearchHistory: '搜索历史会话...',
    LocaleKeys.shNoMatches: '没有匹配结果',
    LocaleKeys.shNoHistory: '该项目没有会话历史',
    LocaleKeys.shDeleteSession: '删除会话',

    // ── File Tree ──
    LocaleKeys.ftRenameFailed: '重命名失败',
    LocaleKeys.ftCreateFailed: '创建失败',
    LocaleKeys.ftDeleteFailed: '删除失败',
    LocaleKeys.ftNewFile: '新建文件',
    LocaleKeys.ftNewFolder: '新建文件夹',
    LocaleKeys.ftCopy: '复制',
    LocaleKeys.ftPaste: '粘贴',
    LocaleKeys.ftCut: '剪切',
    LocaleKeys.ftCopyPath: '复制路径',
    LocaleKeys.ftCopyRelativePath: '复制相对路径',
    LocaleKeys.ftRename: '重命名',
    LocaleKeys.ftDelete: '删除',
    LocaleKeys.unsupportedBinaryFile: '暂不支持打开二进制文件：@file',

    // ── Git Panel ──
    LocaleKeys.gpSyncSuccess: '同步成功',
    LocaleKeys.gpSyncFailed: '同步失败',
    LocaleKeys.gpCommitSuccess: '提交成功',
    LocaleKeys.gpDiscardChanges: '放弃更改',
    LocaleKeys.gpConfirmDiscard: '确定放弃',
    LocaleKeys.gpChanges: '更改',
    LocaleKeys.gpRefreshStatus: '刷新状态',
    LocaleKeys.gpGraph: '图形',
    LocaleKeys.gpSwitchBranch: '切换分支',
    LocaleKeys.gpSyncChanges: '同步更改',
    LocaleKeys.gpCommit: '提交',
    LocaleKeys.gpMoreOptions: '更多提交选项',
    LocaleKeys.gpCommitAndPush: '提交并推送',
    LocaleKeys.gpCopyCommitHash: '复制提交哈希',
    LocaleKeys.gpNoFileChanges: '没有文件改动',
    LocaleKeys.gpLocalPushed: '本地提交 (已推送)',
    LocaleKeys.gpNotPushed: '未推送至远程',
    LocaleKeys.gpViewDiff: '查看差异',
    LocaleKeys.gpDiscardTooltip: '放弃更改',
    LocaleKeys.gpStageChanges: '暂存更改',
    LocaleKeys.gpSearchCommits: '搜索提交…',
    LocaleKeys.gpNoMatchingCommits: '无匹配提交',

    // ── Terminal ──
    LocaleKeys.termNoTerminal: '无终端',
    LocaleKeys.termNoOutput: '无输出',

    // ── Keyboard Shortcuts (labels) ──
    LocaleKeys.kbPrevTab: '上一个标签页',
    LocaleKeys.kbNextTab: '下一个标签页',
    LocaleKeys.kbCloseTab: '关闭当前标签',
    LocaleKeys.kbCloseTabAlt: '关闭当前标签 (备选)',
    LocaleKeys.kbCloseAllTabs: '关闭全部标签',
    LocaleKeys.kbCloseSavedTabs: '关闭已保存标签',
    LocaleKeys.kbCopyAbsPath: '复制绝对路径',
    LocaleKeys.kbCopyRelPath: '复制相对路径',
    LocaleKeys.kbSendToInput: '发送选中文本到输入框',
    LocaleKeys.kbFind: '查找',
    LocaleKeys.kbFindReplace: '查找替换',
    LocaleKeys.kbSave: '保存文件',
    LocaleKeys.kbDuplicateLine: '复制当前行',
    LocaleKeys.kbUndo: '撤销',
    LocaleKeys.kbRedo: '重做',
    LocaleKeys.kbMoveLineUp: '上移行',
    LocaleKeys.kbMoveLineDown: '下移行',
    LocaleKeys.kbWordLeft: '向左按词移动光标',
    LocaleKeys.kbWordRight: '向右按词移动光标',
    LocaleKeys.kbDeleteWordBack: '向后删除词',
    LocaleKeys.kbDeleteWordForward: '向前删除词',
    LocaleKeys.kbGoToDocStart: '跳到文档开头',
    LocaleKeys.kbGoToDocEnd: '跳到文档末尾',
    LocaleKeys.kbCodeActions: '代码操作 (LSP)',
    LocaleKeys.kbRenameSymbol: '重命名符号',
    LocaleKeys.kbFormat: '格式化文档',
    LocaleKeys.kbToggleComment: '注释/解注释',

    // ── LSP ──
    LocaleKeys.lspConfigDesc: '配置语言服务器以进行代码分析和补全',
    LocaleKeys.lspAgentLsp: 'AI Agent LSP',
    LocaleKeys.lspAgentDiagDesc: '控制 AI Agent 的语言服务器诊断反馈。',
    LocaleKeys.lspAvailableServers: '可用语言服务器',
    LocaleKeys.lspBackendManagedDesc:
        '语言服务器由 OpenCode 后端管理，安装后需重启 OpenCode 服务。',
    LocaleKeys.lspNotDetected: '未检测到 @cmd，请先安装',
    LocaleKeys.lspInstalling: '安装中...',
    LocaleKeys.lspInstall: '安装',
    LocaleKeys.lspInstallDartSdkTip: '请安装 Flutter/Dart SDK 后重启应用',
    LocaleKeys.lspInstallManualTip: '请手动安装 @name (可执行文件 @cmd) 后重启应用',
    LocaleKeys.lspInstallSuccess: '@name 安装成功',
    LocaleKeys.lspInstallFailed: '@name 安装失败 (exit @exitCode)',
    LocaleKeys.lspDartDesc: 'Dart 语言服务（随 Flutter SDK 自带）',
    LocaleKeys.lspRustDesc: 'Rust 语言分析器',
    LocaleKeys.lspPythonDesc: 'Python 语言分析器 (Pyright)',
    LocaleKeys.lspGoDesc: 'Go 语言官方语言服务器',
    LocaleKeys.lspJsTsDesc: 'JS/TS 语言服务',
    LocaleKeys.lspHtmlDesc: 'HTML 语言服务',
    LocaleKeys.lspCssDesc: 'CSS 语言服务',
    LocaleKeys.lspJsonDesc: 'JSON 语言服务',
    LocaleKeys.lspCppDesc: 'C/C++ 语言分析器',
    LocaleKeys.lspBashDesc: 'Bash 语言服务',
    LocaleKeys.lspYamlDesc: 'YAML 语言服务',
    LocaleKeys.lspLuaDesc: 'Lua 语言服务',

    // ── Terminal ──
    LocaleKeys.termTerminal: '终端',
    LocaleKeys.termProblems: '问题',
    LocaleKeys.termOutput: '输出',
    LocaleKeys.termDefaultShellAuto: '默认 Shell (自动检测)',
    LocaleKeys.termCopyAll: '全复制',
    LocaleKeys.termSendAllToAi: '全发送给 AI',
    LocaleKeys.termCopy: '复制',
    LocaleKeys.termSendToAi: '发送给 AI',

    // ── Git & Editor ──
    LocaleKeys.gitSwitchedBranch: '已切换到分支: @branch',
    LocaleKeys.gitSwitchBranchFailed: '切换分支失败: @error',
    LocaleKeys.gitSwitchBranchError: '切换分支出错: @error',
    LocaleKeys.gitConfirmDiscardChanges: '您确定要放弃对 "@file" 的所有未提交更改吗？此操作无法撤销。',
    LocaleKeys.gitCommitAmend: '提交 (修改)',
    LocaleKeys.gitFilesChanged: '已更改 @count 个文件',
    LocaleKeys.gitLinesInserted: '@count 行插入(+)',
    LocaleKeys.gitLinesDeleted: '@count 行删除(-)',
    LocaleKeys.gitNoChangesLine: '，0 行插入(+), 0 行删除(-)',
    LocaleKeys.gitCopiedCommitHash: '已复制提交哈希: @hash',
    LocaleKeys.gitOpenOnGithub: '在 GitHub 上打开',
    LocaleKeys.gitHunkRevertFailed: '块级回滚失败: @error',
    LocaleKeys.gitRevertHunk: '回滚此变更块',
    LocaleKeys.previewOnly: '仅预览',
    LocaleKeys.editAndPreview: '编辑 + 预览',
    LocaleKeys.edMdPreview: '预览',
    LocaleKeys.edMdRaw: '编辑',
    LocaleKeys.preview: '预览',
    LocaleKeys.edit: '编辑',

    // ── Chat & Session ──
    LocaleKeys.chatBuildRunningError: '会话 [@name] 正在执行 Build',
    LocaleKeys.chatExecutionFailed: '执行失败',
    LocaleKeys.chatPermissionRequestDesc: 'AI 正在请求 [@type] 权限，范围或目标如下：',
    LocaleKeys.chatBuildLockedTitle: 'Build 锁定中',
    LocaleKeys.chatBuildLockedDesc:
        '会话 [@name] 正在执行 Build。为避免文件冲突，当前窗口已被锁定。请等待其完成后再试，或切换为 Plan Agent。',
    LocaleKeys.chatTodoTitle: '待办事项',
    LocaleKeys.chatChangedFilesTitle: '已更改文件',
    LocaleKeys.chatConfirmPermissionsFirst: '请先确认上方的安全权限请求...',
    LocaleKeys.chatFileCount: '@count 个文件',
    LocaleKeys.chatImageCount: '@count 张图片',
    LocaleKeys.chatQueuingWithParts: '排队中: @parts',
    LocaleKeys.chatQueuing: '排队中...',
    LocaleKeys.chatManualCompact: '手动压缩',
    LocaleKeys.chatQuickPhrases: '常用语',
    LocaleKeys.chatSelectSessionFirst: '请先选择一个会话',
    LocaleKeys.chatLoadingMessages: '正在加载消息...',
    LocaleKeys.chatStartConversation: '开启对话',
    LocaleKeys.chatLoadMessagesFailed: '加载失败，点击重试',
    LocaleKeys.chatWaitGenerationToCompact: '当前会话正在生成，完成后再压缩',
    LocaleKeys.chatManualCompactCompleted: '手动压缩完成',
    LocaleKeys.chatContextCompaction: '上下文压缩',
    LocaleKeys.chatCompactionFailed: '压缩失败',
    LocaleKeys.chatForkFailed: '会话分叉失败',
    LocaleKeys.mcpConnectFailed: '无法连接到 opencode 服务，请确保 sidecar 正在运行',
    LocaleKeys.permDenied: '权限已拒绝',
    LocaleKeys.permRequest: '权限请求',
    LocaleKeys.toolRequestingUse: 'AI 请求使用 [@name] 工具：',
    LocaleKeys.permRead: '读取文件',
    LocaleKeys.permWrite: '写入文件',
    LocaleKeys.permExecute: '执行命令',
    LocaleKeys.permWeb: '访问网页',
    LocaleKeys.defaultKeywordPossible: '可能',
    LocaleKeys.chatBuildFixedProblemsPrompt:
        'Build 完成后检测到以下问题，请修复：\n\n@diagText',
    LocaleKeys.toolApprovedMsg: '已批准执行 [@name] 操作，请继续。',
    LocaleKeys.toolDeniedMsg: '已拒绝执行 [@name] 操作，请换用其他方式。',
    LocaleKeys.questionAskPrefix: '问: @text',
    LocaleKeys.questionAnswerPrefix: '答: ',

    // ── Feedback Notifications ──
    LocaleKeys.feedbackTitle: 'OpenCode 通知',
    LocaleKeys.feedbackCompleted: 'AI 生成完成',
    LocaleKeys.feedbackCompletedMsg: '会话 @session 已完成回复',
    LocaleKeys.feedbackError: 'AI 生成出错',
    LocaleKeys.feedbackErrorMsg: '会话 @session 出错：@error',
    LocaleKeys.feedbackQuestion: 'AI 提问',
    LocaleKeys.feedbackQuestionMsg: '会话 @session 需要你的回答',
    LocaleKeys.feedbackPermission: '权限请求',
    LocaleKeys.feedbackPermissionMsg: '会话 @session 请求权限',

    // ── Skills ──
    LocaleKeys.skillsPathsTooltip:
        "此路径为包含 Skill 文件夹的目录。\n"
        "Skill 要求：\n"
        "1. Skill 目录下必须包含名为 SKILL.md 的文件。\n"
        "2. 文件必须以 YAML Frontmatter 开头，格式如：\n"
        "---\n"
        "name: Skill 名称\n"
        "description: Skill 描述\n"
        "---\n"
        "# Skill 具体提示词内容",

    // ── Common/General ──
    LocaleKeys.ok: '确定',
    LocaleKeys.success: '成功',
    LocaleKeys.error: '错误',
    LocaleKeys.required: '必填',
    LocaleKeys.duplicate: '重复',
    LocaleKeys.install: '安装',

    // ── Rules Tab ──
    LocaleKeys.rulesClaudeCompatTitle: 'Claude Code 兼容性',
    LocaleKeys.rulesClaudeCompatDesc:
        '当找不到 AGENTS.md 时，OpenCode 支持使用 CLAUDE.md 作为备选。',
    LocaleKeys.rulesClaudeCompatEnv:
        '若要禁用 Claude Code 兼容性，请设置环境变量：\nOPENCODE_DISABLE_CLAUDE_CODE=1',
    LocaleKeys.rulesAddInstructionPath: '添加指令路径',
    LocaleKeys.rulesInstructionPathPlaceholder: '例如 docs/guidelines.md',

    // ── Skills Tab ──
    LocaleKeys.skillsAdditionalPaths: '附加路径',
    LocaleKeys.skillsRemoteUrls: '远程 URL',
    LocaleKeys.skillsLoadedSkills: '已加载的 Skill',
    LocaleKeys.skillsSaveSources: '保存源配置',
    LocaleKeys.skillsSaveContent: '保存内容',
    LocaleKeys.skillsBuiltinReadOnly: '内置 Skill (只读)',
    LocaleKeys.skillsLocalFileSkill: '本地文件 Skill',
    LocaleKeys.skillsBuiltinDesc: '此 Skill 内置于 OpenCode，无法编辑。',
    LocaleKeys.skillsSelectFolderTip: '点击右侧的文件夹图标进行选择...',
    LocaleKeys.skillsBrowseFolderTooltip: '浏览并添加文件夹...',
    LocaleKeys.skillsBack: '返回',

    // ── Providers Tab ──
    LocaleKeys.providersConnect: '连接',
    LocaleKeys.providersShowAll: '显示全部 (@totalCount 个服务商) →',
    LocaleKeys.providersProviderId: '服务商 ID',
    LocaleKeys.providersProviderIdPlaceholder: '输入服务商 ID(必填)',
    LocaleKeys.providersProviderIdError: '使用小写字母、数字、- 或 _',
    LocaleKeys.providersName: '名称',
    LocaleKeys.providersNamePlaceholder: '输入名称',
    LocaleKeys.providersBaseUrl: '接口地址 (Base URL)',
    LocaleKeys.providersBaseUrlPlaceholder: '输入 Base URL',
    LocaleKeys.providersBaseUrlError: '必须以 http:// 或 https:// 开头',
    LocaleKeys.providersApiKey: 'API 密钥 (API Key)',
    LocaleKeys.providersApiKeyPlaceholder: '输入密匙，如 sk-...',
    LocaleKeys.providersAddModel: '添加 Model',
    LocaleKeys.providersAddHeader: '添加请求头',
    LocaleKeys.providersModelId: 'Model ID',
    LocaleKeys.providersModelName: 'Model 名称',
    LocaleKeys.providersHeaderKey: '请求头键 (Header Key)',
    LocaleKeys.providersHeaderValue: '请求头值 (Header Value)',
    LocaleKeys.providersRecommended: '推荐',
    LocaleKeys.providersEditKey: '修改密钥',
    LocaleKeys.providersDeleteKey: '删除密钥',
    LocaleKeys.providersAddKey: '添加密钥',
    LocaleKeys.providersKeyUpdatePlaceholder: '输入新密钥以更新...',
    LocaleKeys.providersKeyEnterPlaceholder: '输入 @name 的 API 密钥...',
    LocaleKeys.providersOauth: 'OAuth 授权',
    LocaleKeys.providersOauthSuccess: 'OAuth 授权成功',
    LocaleKeys.providersOauthFailed: 'OAuth 授权失败',
    LocaleKeys.providersFetchModels: '获取模型列表',
    LocaleKeys.providersJsonConfig: 'JSON 配置',
    LocaleKeys.providersFormatJson: '格式化 JSON',
    LocaleKeys.providersSaveFailed: '保存自定义服务商失败',
    LocaleKeys.providersJsonError: 'JSON 错误: @error',
    LocaleKeys.providersApiKeyRequired: '请先填写 API Key',
    LocaleKeys.providersFetchSuccess: '成功拉取到 @count 个模型',
    LocaleKeys.providersFetchNoModels: '未在返回结果中解析到任何模型 ID',
    LocaleKeys.providersFetchFailed: '拉取模型列表失败',
    LocaleKeys.providersConfigEdit: '编辑服务商配置',

    // ── MCP Tab ──
    LocaleKeys.mcpAlreadyInstalled: '已安装',
    LocaleKeys.mcpAlreadyInstalledDesc: '"@name" 已经配置过。请到已安装的标签页中进行管理。',
    LocaleKeys.mcpGoToInstalled: '前往已安装标签',
    LocaleKeys.mcpConfigureTitle: '配置 @name',
    LocaleKeys.mcpEnvVarsRequired: '此服务器需要以下环境变量：',
    LocaleKeys.mcpInstalledTab: '已安装',
    LocaleKeys.mcpDiscoverTab: '发现',
    LocaleKeys.mcpRemoveTitle: '删除 MCP 服务',
    LocaleKeys.mcpRemoveConfirm: '确定要从 MCP 服务中删除 "@name" 吗？',

    // ── Agent Tab ──
    LocaleKeys.agentNewTitle: '新建 Agent',
    LocaleKeys.agentCreate: '创建',

    // ── Command Palette ──
    LocaleKeys.cmdSearchPlaceholder: '输入命令...',

    // ── Git Notifications ──
    LocaleKeys.gitNoChangesDetected: '未检测到可用于生成提交信息的变更。',
    LocaleKeys.gitCommitFailed: '提交失败: @error',
    LocaleKeys.gitCommitError: '提支出错: @error',
    LocaleKeys.gitStageFailed: '暂存更改失败: @error',
    LocaleKeys.gitDiscardFailed: '放弃更改失败: @error',
    LocaleKeys.providersProviderExists: '服务商已存在',
    LocaleKeys.headers: '请求头',
    LocaleKeys.disconnect: '断开',
    LocaleKeys.gitStagedSuccess: '成功暂存 @file',
    LocaleKeys.gitDiscardedSuccess: '已放弃 @file 的更改',
    LocaleKeys.gitStagedTitle: '暂存',
    LocaleKeys.gitDiscardedTitle: '已放弃',
    LocaleKeys.startExecution: '开始执行',
    LocaleKeys.makePlan: '制定计划',
    // ── TODO Panel ──
    LocaleKeys.termTodo: '待办',
    LocaleKeys.todoEmpty: '未发现待办标记',
    LocaleKeys.todoScanning: '正在扫描待办标记…',
    LocaleKeys.todoScanError: '待办扫描失败',
    LocaleKeys.todoRefresh: '刷新',
    LocaleKeys.todoSettings: '设置',
    LocaleKeys.todoKeywords: '关键词',
    LocaleKeys.todoCaseSensitive: '区分大小写',
    LocaleKeys.todoAddKeyword: '添加关键词',
    LocaleKeys.todoExcludedFolders: '排除文件夹',
    LocaleKeys.todoAddExcludedFolder: '添加排除文件夹',

    // ── Mobile shell ──
    LocaleKeys.mobileAllSessions: '全部会话',
    LocaleKeys.mobileOpenSessions: '已打开会话',
    LocaleKeys.mobileClearAllSessions: '清空',
    LocaleKeys.mobileToggleLeftPanel: '收起 / 展开左侧栏',
    LocaleKeys.mobileToggleRightPanel: '收起 / 展开右侧栏',
    LocaleKeys.mobileDisplay: '显示设置',
    LocaleKeys.mobileNoOpenSessions: '暂无已打开会话',
    LocaleKeys.mobileSelectProject: '请从侧栏选择项目',
    LocaleKeys.mobileNoActiveSessions: '暂无活动会话',
    LocaleKeys.mobileCheckUpdates: '检查更新',
    LocaleKeys.mobileUpToDate: '已是最新版本 (@version)',
    LocaleKeys.mobileSseReconnecting: '事件流已断开，正在重连…',
    LocaleKeys.mobileSseAuthFailed: '认证已失效，请在设置中检查账号密码',

    LocaleKeys.mobileSettings: '设置',
    LocaleKeys.vadSettingsTitle: '语音设置',
    LocaleKeys.vadThreshold: '语音检测灵敏度',
    LocaleKeys.vadMinSilenceDuration: '最小静音时长',
    LocaleKeys.vadMinSpeechDuration: '最小语音时长',
    LocaleKeys.vadMaxSpeechDuration: '最大语音时长',
    LocaleKeys.vadSpeechPadMs: '语音前后填充',
    LocaleKeys.vadResetDefault: '恢复默认设置',
    LocaleKeys.voiceContinuousInput: '开启连续语音输入',
    LocaleKeys.voiceContinuousInputDesc: '开启后发送消息不会停止语音输入，可连续说话',
    LocaleKeys.voiceAutoSend: '开启自动发送',
    LocaleKeys.voiceAutoSendDesc: '单点语音时，说出“发送指令”且前后有标点（如“内容。发送。”），自动发送指令前的内容',
    LocaleKeys.voiceSendCommand: '发送指令',
    LocaleKeys.voiceSendCommandHint: '发送',
    LocaleKeys.voiceVadParams: '语音检测参数',
    LocaleKeys.vadThresholdDesc: '判定是否有语音的敏感度阈值（更高更严防噪音）',
    LocaleKeys.vadMinSilenceDesc: '静音达到该时长判定说话断句/结束',
    LocaleKeys.vadMinSpeechDesc: '短于该同等长度的语音会被视作噪音过滤',
    LocaleKeys.vadMaxSpeechDesc: '单次最长连续语音切片上限',
    LocaleKeys.vadSpeechPadDesc: '在语音切片前后扩充的静音缓冲时长',
    LocaleKeys.voiceRecognitionErrorTitle: '语音识别提示',
    LocaleKeys.voiceListening: '正在聆听中...',
    LocaleKeys.voiceReleaseCancel: '松开手指，取消发送',
    LocaleKeys.voiceReleaseInsert: '松开手指，放入输入框',
    LocaleKeys.voiceReleaseHint: '松开发送 | 向上滑取消 | 向下滑输入',
    LocaleKeys.voiceMicPermissionDeniedPermanent: '麦克风权限已被拒绝，正在为您打开系统设置页面',
    LocaleKeys.voiceMicPermissionDenied: '未授予麦克风权限，无法启动语音输入',
    LocaleKeys.voiceMicPermissionRequestFailed: '申请麦克风权限失败',
    LocaleKeys.voiceTranscriptionError: '语音转写服务错误',
    LocaleKeys.voiceRecordPermissionDenied: '未开通录音权限',
    LocaleKeys.voiceRecordStreamError: '录音流错误',
    LocaleKeys.voiceStartFailed: '启动语音识别失败',
    LocaleKeys.mobileOpenCodeSection: 'OpenCode',
    LocaleKeys.mobileOpenCodeSettingsDesc: '服务器、服务商、MCP',
    LocaleKeys.mobileCheckingUpdates: '正在检查更新…',
    LocaleKeys.mobileAboutAppName: 'OpenCode Mobile',
    LocaleKeys.mobileAboutLegalese: 'OpenCode 服务器远程客户端',
    LocaleKeys.mobileAboutDesc:
        '通过 HTTP、SSE 和 PTY WebSocket 连接远程 opencode serve 实例。',
    LocaleKeys.mobileAboutVersion: 'OpenCode Mobile v@version',
    LocaleKeys.mobileHealth: '健康状态',
    LocaleKeys.mobileServerConnection: '服务器连接',
    LocaleKeys.mobileServerUrl: '服务器地址',
    LocaleKeys.mobileServerUrlRequired: '请填写服务器地址',
    LocaleKeys.mobileConnectSidecar: '连接到 Sidecar 服务器',
    LocaleKeys.mobileConnectServer: '连接服务器',
    LocaleKeys.mobileConnecting: '连接中…',
    LocaleKeys.mobileStatus: '状态：@status',
    LocaleKeys.mobilePassword: '密码',
    LocaleKeys.mobileNoProjects: '暂无项目',
    LocaleKeys.mobileProjectsLoadFailed: '项目列表加载失败',
    LocaleKeys.mobileProjects: '项目',
    LocaleKeys.mobileHiddenProjects: '已隐藏项目',
    LocaleKeys.mobileHideProject: '隐藏项目',
    LocaleKeys.mobileUnhideProject: '取消隐藏',
    LocaleKeys.mobileNoKeywordsYet: '暂无关键词',
    LocaleKeys.mobileNoSessions: '暂无会话',
    LocaleKeys.mobileNoMatchingSessions: '无匹配会话',
    LocaleKeys.mobileJustNow: '刚刚',
    LocaleKeys.mobileMinutesAgo: '@count 分钟前',
    LocaleKeys.mobileHoursAgo: '@count 小时前',
    LocaleKeys.mobileDaysAgo: '@count 天前',
    LocaleKeys.mobileLoginProviders: '登录 / 服务商',
    LocaleKeys.mobileKeywords: '关键词',
    LocaleKeys.mobileKeywordDetection: '关键词检测',
    LocaleKeys.mobileEnableKeywordDetection: '启用关键词检测',
    LocaleKeys.mobileAddKeywordHint: '添加关键词…',
    LocaleKeys.mobilePhraseLabel: '标签',
    LocaleKeys.mobilePhraseText: '常用语内容…',
    LocaleKeys.mobileAttachFile: '附加文件',
    LocaleKeys.mobileAttachImage: '附加图片',
    LocaleKeys.mobileImageUnsupportedFormat: '不支持的图片格式 (.@ext)',
    LocaleKeys.mobileImageHeicUnsupported: 'HEIC/HEIF 无法解析，请先转为 JPG/PNG',
    LocaleKeys.mobileImageDescribePrompt: '请详细描述我发给你的图片。',
    LocaleKeys.mobileImageDescribing: '正在识别图片…',
    LocaleKeys.mobileImageDescribeFailed: '图片识别失败',
    LocaleKeys.mobileImageToText: '转文字',
    LocaleKeys.mobileVisionSettings: '识图设置',
    LocaleKeys.aboutTitle: '关于与开源信息',
    LocaleKeys.releasePageTitle: '版本发布界面',
    LocaleKeys.releasePageSubtitle: '查看最新版本与 Release 动态',
    LocaleKeys.openSourceLibrariesTitle: '使用到的开源库',
    LocaleKeys.openSourceLibrariesDesc: '本软件依赖以下优秀的 Flutter / Dart 开源项目构建：',
    LocaleKeys.viewFullLicenses: '查看完整开源许可证 (Licenses)',
    LocaleKeys.mobileSelectVisionModel: '选择识图模型',
    LocaleKeys.mobileNoVisionModelsHint: '暂无可用模型',
    LocaleKeys.mobileStopEsc: '停止 (Esc)',
    LocaleKeys.mobileSendEnter: '发送 (Enter)',
    LocaleKeys.mobileRemoteTerminal: '远程终端',
    LocaleKeys.mobileNoQuickPhrasesHint: '暂无常用语，请在设置中添加。',
    LocaleKeys.mobileAddProject: '添加项目',
    LocaleKeys.mobileAddProjectFailed: '添加项目失败，请确认路径是否正确',
    LocaleKeys.mobileServerPath: '服务器路径',
    LocaleKeys.mobileBrowseFiles: '浏览文件',
    LocaleKeys.mobileFiles: '文件',
    LocaleKeys.mobileIgnoredFile: '已被忽略',
    LocaleKeys.mobileEmptyDirectory: '空目录',
    LocaleKeys.mobileSessions: '会话',
    LocaleKeys.mobileDeleteSessionTitle: '删除会话？',
    LocaleKeys.mobileDeleteSessionConfirm: '删除“@name”？此操作无法撤销。',
    LocaleKeys.mobileDeleteSessionFailed: '删除会话失败，请检查网络后重试',
    LocaleKeys.mobileSearchSessions: '搜索会话…',
    LocaleKeys.mobileReconnect: '重新连接',
    LocaleKeys.mobileConnected: '已连接',
    LocaleKeys.mobileUnreachable: '无法连接',
    LocaleKeys.mobileUnknown: '未知',
    LocaleKeys.mobileTapRefresh: '点击刷新',
    LocaleKeys.mobileSaveAndReconnect: '保存并重连',
    LocaleKeys.mobileReconnecting: '正在重连…',
    LocaleKeys.mobileConnectionFailed: '连接失败',
    LocaleKeys.mobileCancelConnection: '取消连接',
    LocaleKeys.mobileAutoConnecting: '正在自动连接 @url…',
    LocaleKeys.mobileMessageDensity: '消息密度',
    LocaleKeys.mobileCompact: '紧凑',
    LocaleKeys.mobileComfortable: '适中',
    LocaleKeys.mobileSpacious: '宽松',
    LocaleKeys.mobileCardVisibility: '卡片可见性',
    LocaleKeys.mobileShowAll: '全部显示',
    LocaleKeys.mobileHideAll: '全部隐藏',
    LocaleKeys.mobileNoDiff: '无差异',
    LocaleKeys.mobileNoStepsYet: '暂无步骤',
    LocaleKeys.mobileNoSteps: '无步骤',
    LocaleKeys.mobileConnectWithApiKey: '使用 API Key 连接',
    LocaleKeys.mobileRevert: '回退',
    LocaleKeys.mobileLoadMore: '加载更多',
    LocaleKeys.mobileHeaderKey: '键',
    LocaleKeys.mobileHeaderValue: '值',
    LocaleKeys.mobileAddItem: '添加项…',
    LocaleKeys.mobileIgnorePatterns: '忽略规则',
    LocaleKeys.mobilePlugins: '插件',
    LocaleKeys.mobilePluginEntries: '插件条目',
    LocaleKeys.mobileInstructionPaths: '指令路径',
    LocaleKeys.mobileAttachments: '附件',
    LocaleKeys.mobileAutoResizeImages: '自动缩放图片',
    LocaleKeys.mobileMaxWidth: '最大宽度',
    LocaleKeys.mobileMaxHeight: '最大高度',
    LocaleKeys.mobileMaxBase64Bytes: '最大 base64 字节',
    LocaleKeys.mobileEnableLsp: '启用 LSP',
    LocaleKeys.mobileEnableLspDesc: '语言服务器总开关。',
    LocaleKeys.mobileSavedPermissions: '已保存权限',
    LocaleKeys.mobileDescription: '描述',
    LocaleKeys.mobileModel: '模型',
    LocaleKeys.mobileMode: '模式',
    LocaleKeys.mobileVariant: '变体',
    LocaleKeys.mobileTemperature: '温度',
    LocaleKeys.mobileTopP: 'Top P',
    LocaleKeys.mobileMaxSteps: '最大步数',
    LocaleKeys.mobileSystemPrompt: '系统提示词',
    LocaleKeys.mobileAgentNameRequired: 'Agent 名称 *',
    LocaleKeys.mobileEnableFormatters: '启用格式化器',
    LocaleKeys.mobileFormatters: '格式化器',
    LocaleKeys.mobileReferences: '引用 (@count)',
    LocaleKeys.mobileCustomCommands: '自定义命令 (@count)',
    LocaleKeys.mobileNameRequired: '名称 *',
    LocaleKeys.mobileTemplateRequired: '模板 *',
    LocaleKeys.mobileAgent: 'Agent',
    LocaleKeys.mobileSubtask: '子任务',
    LocaleKeys.mobileAddReference: '添加引用',
    LocaleKeys.mobileRefText: '文本',
    LocaleKeys.mobileRefGit: 'Git',
    LocaleKeys.mobileRefPath: '路径',
    LocaleKeys.mobileBranchOptional: '分支（可选）',
    LocaleKeys.mobileMcpTimeoutHint: '例如 30000',
    LocaleKeys.mobileMcpTimeoutInvalid: 'mcp_timeout 必须是整数',
    LocaleKeys.mobileInvalidNumber: '请输入有效的正整数',
    LocaleKeys.mobileToolNameHint: '工具名',
    LocaleKeys.mobilePrimaryToolsHint: '在 Agent UI 中优先展示的工具。',
    LocaleKeys.mobileBatchToolDesc: '启用实验性批量工具执行。',
    LocaleKeys.mobileDisablePasteDesc: '跳过粘贴内容摘要。',
    LocaleKeys.mobileContinueLoopDesc: '权限拒绝后继续运行。',
    LocaleKeys.mobileOtelDesc: '发送实验性 OpenTelemetry 信号。',

    LocaleKeys.cardVisReasoning: '推理',
    LocaleKeys.cardVisThinking: '思考',
    LocaleKeys.cardVisSearch: '搜索',
    LocaleKeys.cardVisRead: '读取',
    LocaleKeys.cardVisBash: 'Bash',
    LocaleKeys.cardVisEdit: '编辑',
    LocaleKeys.cardVisBatch: '批量 / 补丁',
    LocaleKeys.cardVisGlob: 'Glob',
    LocaleKeys.cardVisGrep: 'Grep',
    LocaleKeys.cardVisWeb: '网页',
    LocaleKeys.cardVisQuestion: '提问',
    LocaleKeys.cardVisTask: '任务',
    LocaleKeys.cardVisSubtask: '子任务',
    LocaleKeys.cardVisSkill: '技能',
    LocaleKeys.cardVisFallback: '其他工具',
    LocaleKeys.cardVisFile: '文件',
    LocaleKeys.cardVisAgent: 'Agent',
    LocaleKeys.cardVisDiff: '差异',

    // ── Terminal ──
    LocaleKeys.terminalSettings: '终端设置',
    LocaleKeys.terminalCurrentProjectOnly: '只显示本项目终端',
    LocaleKeys.terminalCurrentProjectOnlyDesc: '默认开启，仅展示当前激活工程下的 PTY 终端',
    LocaleKeys.terminalShowExtraKeys: '显示扩展键盘',
    LocaleKeys.terminalShowExtraKeysDesc: '在终端底部显示 ESC/Ctrl/Alt/方向键扩展栏',
    LocaleKeys.terminalShowQuickCommands: '显示快捷命令',
    LocaleKeys.terminalShowQuickCommandsDesc: '在终端底部显示自定义 Shell 命令短语栏',
    LocaleKeys.terminalCloseCurrent: '关闭当前终端',
    LocaleKeys.terminalConfirmClose: '确定要关闭 @title 吗？关闭后后台进程将被终止。',
    LocaleKeys.terminalFetchingList: '正在获取终端列表...',
    LocaleKeys.terminalNoRunning: '暂无运行中的终端',
    LocaleKeys.terminalClickPlusToCreate: '点击右上角 + 按钮新建终端',
    LocaleKeys.terminalNew: '新建终端',
    LocaleKeys.terminalTitle: '终端',
    LocaleKeys.terminalSessionEnded: '终端会话已结束',
    LocaleKeys.terminalConnectionLost: '连接已断开',
    LocaleKeys.terminalConnectionTimeout: '连接超时',
    LocaleKeys.terminalDeleteFailed: '远端终端删除失败，可能仍在运行',
    LocaleKeys.terminalCommandLabel: '命令',
    LocaleKeys.terminalCommandRequired: '请输入命令',
    LocaleKeys.terminalNeedSession: '请先创建并连接终端',

    // ── Tablet tool panel ──
    LocaleKeys.tabletCodeTab: '代码',
    LocaleKeys.tabletTerminalTab: '终端',
    LocaleKeys.tabletWebTab: '浏览器',
    LocaleKeys.tabletReviewTab: '审查',
    LocaleKeys.tabletToggleToolPanel: '工具面板',
    LocaleKeys.tabletNoFileOpen: '未打开文件',
    LocaleKeys.tabletEnterUrl: '输入网址',
    LocaleKeys.reviewTypeMessage: '消息',
    LocaleKeys.reviewTypeSession: '会话',
    LocaleKeys.reviewTypeAll: '所有',
    LocaleKeys.reviewLoadFailed: '加载失败',
    LocaleKeys.reviewEmptyHint: '点击消息的变更文件或会话的已修改文件查看 diff，或点击右上角按钮查看全部变更',
    LocaleKeys.reviewShowChangesOnly: '仅显示变更',
    LocaleKeys.reviewShowFull: '显示全文',
    LocaleKeys.reviewPrevChange: '上一变更',
    LocaleKeys.reviewNextChange: '下一变更',
    LocaleKeys.reviewPrevFile: '上一文件',
    LocaleKeys.reviewNextFile: '下一文件',

    // ── Session extra ──
    LocaleKeys.sessionWaitGenerationFinish: '请等待消息生成完成',
    LocaleKeys.sessionForkFailed: '分支创建失败',
    LocaleKeys.sessionRevertFailed: '回滚失败',
    LocaleKeys.retryLimited: '请求受限，正在重试。',
    LocaleKeys.retryLimitedReason: '请求受限，正在重试：@reason',

    // ── MCP extra ──
    LocaleKeys.mcpAuthTitle: 'OAuth 认证',
    LocaleKeys.mcpAuthDesc: '请在浏览器中完成认证，然后将重定向 URL 中的 "code" 粘贴到下方。',
    LocaleKeys.mcpAuthCodeLabel: '授权码',
    LocaleKeys.mcpRemoveAuthTitle: '移除 OAuth',
    LocaleKeys.mcpRemoveAuthConfirm: '确定要移除 @name 的 OAuth 凭据吗？',
    LocaleKeys.mcpLocal: '本地',
    LocaleKeys.mcpRemote: '远程',
    LocaleKeys.mcpNameRequired: '请输入名称',
    LocaleKeys.mcpNameExists: '已存在同名 MCP 服务器：@name',
    LocaleKeys.mcpUrlRequired: '请输入 URL',
    LocaleKeys.mcpCommandRequired: '请输入命令',
    LocaleKeys.mcpAddFailed: '添加 MCP 失败',
    LocaleKeys.mcpAuthSuccess: '@name 认证成功',
    LocaleKeys.mcpAuthFailed: 'MCP 认证 @name 失败',
    LocaleKeys.mcpRemoveAuthSuccess: '已移除 @name 的认证',

    // ── Developer extra ──
    LocaleKeys.developerEditCommand: '编辑快捷命令',
    LocaleKeys.developerNewCommand: '新建快捷命令',
    LocaleKeys.developerRefNameExists: '引用名称已存在',

    // ── Permissions extra ──
    LocaleKeys.permissionsReplaceConfirm: '要将工具 "@tool" 的路径规则替换为 "@value" 吗？',

    // ── Quick Phrases extra ──
    LocaleKeys.quickPhrasesDeleteTitle: '删除快捷命令',
    LocaleKeys.quickPhrasesDeleteConfirm: '确定要删除 "@name" 吗？',

    // ── Settings extra ──
    LocaleKeys.generalSaveUsernameFailed: '保存用户名失败',
    LocaleKeys.modelsUpdateVisibilityFailed: '更新模型可见性失败',
    LocaleKeys.connectionValidUrlRequired: '请输入有效的 http(s) URL',
    LocaleKeys.connectionReconnected: '重新连接成功',
    LocaleKeys.connectionRefreshFailed: '已连接，但数据刷新失败',
    LocaleKeys.connectionReconnectFailed: '重新连接失败',

    // ── Browser ──
    LocaleKeys.browserBack: '后退',
    LocaleKeys.browserForward: '前进',
    LocaleKeys.browserRefresh: '刷新',
    LocaleKeys.browserSwitchMobile: '切换为手机版网页',
    LocaleKeys.browserSwitchDesktop: '切换为电脑版网页',
    LocaleKeys.browserOpenExternal: '在外部浏览器中打开',
    LocaleKeys.browserLoadFailed: '网页加载失败',
    LocaleKeys.browserNewTab: '新建标签页',
    LocaleKeys.browserCloseTab: '关闭标签页',
    LocaleKeys.browserCollapseToolbar: '折叠控制栏',
    LocaleKeys.browserExpandToolbar: '展开控制栏',
    LocaleKeys.browserCloseSheet: '关闭浏览器',
    LocaleKeys.browserScreenshot: '截图',
    LocaleKeys.browserScreenshotAdded: '截图已添加到当前会话',
    LocaleKeys.browserScreenshotFailed: '截图失败，请重试',
    LocaleKeys.browserScreenshotFailedReason: '截图失败：{reason}',
    LocaleKeys.browserScreenshotNoSession: '创建会话失败，请稍后重试',
    // ── Preview Port ──
    LocaleKeys.previewBindTitle: '绑定预览端口（项目）',
    LocaleKeys.previewPortHint: '端口号（1-65535）',
    LocaleKeys.previewPortInvalid: '端口无效，请输入 1-65535 的数字',
    LocaleKeys.previewPortClear: '清除绑定',
    LocaleKeys.previewBindPreview: '预览地址：',

    // ── Terminal Extra ──
    LocaleKeys.terminalSentToNewSession: '已发送至新 AI 会话',
    LocaleKeys.terminalSentToSession: '已发送至 @name',
    LocaleKeys.terminalSelectSession: '选择发送到的 AI 会话',
    LocaleKeys.terminalNoResults: '未找到结果',
    // ── Left Drawer Extra ──
    LocaleKeys.drawerBackToProjects: '返回项目列表',
    LocaleKeys.drawerBrowseFiles: '浏览文件列表',
    LocaleKeys.drawerBackToProjectsDesc: '查看与切换已有项目',
    LocaleKeys.drawerBrowseFilesDesc: '查看当前项目的目录文件',
    // ── Quick Phrases Extra ──
    LocaleKeys.quickPhrasesEnterName: '请输入命令名称',
    LocaleKeys.quickPhrasesNameExists: '该命令名称已存在',
    LocaleKeys.quickPhrasesEnterTemplate: '请输入命令内容/模板',
    // ── Voice Extra ──
    LocaleKeys.voiceDownloadModelTitle: '下载语音识别模型',
    LocaleKeys.voiceDownloadFailed: '下载失败',
    LocaleKeys.voicePreparingDownload: '准备下载中...',
    LocaleKeys.voiceDownloadPrompt: '首次使用语音识别需要下载语音识别模型：',
    LocaleKeys.voiceCancelDownload: '取消下载',
    LocaleKeys.selectFileFromSidebar: '从侧边栏选择文件',
    LocaleKeys.selectFileFromLeftMenu: '从左侧菜单选择文件打开',
    // ── Search ──
    LocaleKeys.searchPlaceholder: '搜索文件名或代码内容...',
    LocaleKeys.searchFiles: '文件',
    LocaleKeys.searchText: '代码',
    LocaleKeys.searchFilesPlaceholder: '搜索文件名...',
    LocaleKeys.searchTextPlaceholder: '搜索代码内容...',
    LocaleKeys.searchNoResults: '未找到匹配结果',
    LocaleKeys.searchLoading: '搜索中...',
    // ── VCS / Git ──
    LocaleKeys.vcsBranch: 'Git 分支与状态',
    LocaleKeys.vcsStatus: '工作区状态',
    LocaleKeys.vcsDefault: '默认',
    LocaleKeys.vcsClean: '工作区干净，无未提交更改',
    LocaleKeys.vcsModified: '已修改',
    LocaleKeys.vcsAdded: '新增',
    LocaleKeys.vcsDeleted: '已删除',
    LocaleKeys.vcsUntracked: '未跟踪',
    LocaleKeys.vcsViewDiff: '查看完整对比',
    LocaleKeys.vcsNotGitRepo: '非 Git 仓库或暂无版本控制信息',
    LocaleKeys.vcsLoading: '正在获取 Git 状态...',
    LocaleKeys.vcsChangedFiles: '@count 个变更文件',
    LocaleKeys.vcsBranchCopied: '已复制分支名',
  };

  // ──────────────────────────────────────────────────────
  //  English
  // ──────────────────────────────────────────────────────
  static const Map<String, String> _enUS = {
    // ── Common ──
    LocaleKeys.cancel: 'Cancel',
    LocaleKeys.save: 'Save',
    LocaleKeys.delete: 'Delete',
    LocaleKeys.saveFailed: 'Save failed',
    LocaleKeys.deleteFailed: 'Delete failed',
    LocaleKeys.close: 'Close',
    LocaleKeys.retry: 'Retry',
    LocaleKeys.search: 'Search',
    LocaleKeys.export: 'Export',
    LocaleKeys.upgrade: 'Upgrade',
    LocaleKeys.upgrading: 'Upgrading...',
    LocaleKeys.reload: 'Reload',
    LocaleKeys.add: 'Add',
    LocaleKeys.remove: 'Remove',
    LocaleKeys.active: 'Active',
    LocaleKeys.notSet: 'Not set',
    LocaleKeys.default_: 'Default',
    LocaleKeys.unlimited: 'Unlimited',
    LocaleKeys.yes: 'Yes',
    LocaleKeys.no: 'No',
    LocaleKeys.on_: 'On',
    LocaleKeys.off: 'Off',
    LocaleKeys.auto: 'Auto',
    LocaleKeys.manual: 'Manual',
    LocaleKeys.disabled: 'Disabled',
    LocaleKeys.notify: 'Notify',
    LocaleKeys.healthy: 'Healthy',
    LocaleKeys.unhealthy: 'Unhealthy',
    LocaleKeys.serverDefault: 'Server default',
    LocaleKeys.restore: 'Restore',

    // ── Snackbar ──
    LocaleKeys.snackSuccess: 'Success',
    LocaleKeys.snackError: 'Error',
    LocaleKeys.snackInfo: 'Info',
    LocaleKeys.snackWarning: 'Warning',

    // ── Clipboard ──
    LocaleKeys.clipboardCopied: 'Copied to clipboard',
    LocaleKeys.clipboardCopyFailed:
        'Copy failed, the clipboard may be in use by another app, please retry',

    // ── Start Page ──
    LocaleKeys.preparing: 'Preparing OpenCode',
    LocaleKeys.initLocalEnv: 'Initializing local environment...',
    LocaleKeys.spawningSidecar: 'Spawning local sidecar server...',
    LocaleKeys.migratingSqlite: 'Migrating SQLite Database (@0%)...',
    LocaleKeys.systemReady: 'System ready!',
    LocaleKeys.sidecarFailed: 'Local sidecar failed to start.',

    // ── Titlebar ──
    LocaleKeys.menuFile: 'File',
    LocaleKeys.newProject: 'New Project',
    LocaleKeys.noRecentProjects: 'No recent projects',
    LocaleKeys.recentProjects: 'Recent Projects',

    // ── Command Palette ──
    LocaleKeys.cmdNewSession: 'New Session',
    LocaleKeys.cmdNewSessionDesc: 'Create a new AI chat session',
    LocaleKeys.cmdOpenSettings: 'Open Settings',
    LocaleKeys.cmdOpenSettingsDesc:
        'Configure providers, models, and keybindings',
    LocaleKeys.cmdToggleTheme: 'Toggle Theme',
    LocaleKeys.cmdToggleThemeDesc: 'Switch between dark and light mode',
    LocaleKeys.cmdToggleTerminal: 'Toggle Terminal',
    LocaleKeys.cmdToggleTerminalDesc: 'Show or hide the terminal panel',
    LocaleKeys.cmdToggleReview: 'Toggle Review',
    LocaleKeys.cmdToggleReviewDesc: 'Show or hide the code review panel',
    LocaleKeys.cmdToggleSidebar: 'Toggle Sidebar',
    LocaleKeys.cmdToggleSidebarDesc: 'Show or hide the sidebar',
    LocaleKeys.cmdExportLogs: 'Export Logs',
    LocaleKeys.cmdExportLogsDesc: 'Export debug logs to file',

    // ── Session Page ──
    LocaleKeys.allPanelsCollapsed:
        'All panels collapsed.\nUse the titlebar buttons to restore them.',

    // ── Left Panel ──
    LocaleKeys.explorer: 'Explorer',
    LocaleKeys.searchLabel: 'Search',
    LocaleKeys.gitStatus: 'Git Status',

    // ── Settings – Tabs ──
    LocaleKeys.tabGeneral: 'General',
    LocaleKeys.tabProviders: 'Providers',
    LocaleKeys.tabModels: 'Models',
    LocaleKeys.tabMcp: 'MCP Servers',
    LocaleKeys.tabLsp: 'LSP',
    LocaleKeys.tabSkills: 'Skills',
    LocaleKeys.tabRules: 'Rules',
    LocaleKeys.tabAgent: 'Agent',
    LocaleKeys.tabPermissions: 'Permissions',
    LocaleKeys.tabDeveloper: 'Developer',
    LocaleKeys.tabAdvanced: 'Advanced',
    LocaleKeys.tabExperimental: 'Experimental',
    LocaleKeys.tabConnection: 'Connection',
    LocaleKeys.opencodeSettingsTitle: 'OpenCode Settings',
    LocaleKeys.tabAbout: 'About',

    // ── Settings – Cloud Workspace (E2B) ──
    LocaleKeys.connModeSelfHosted: 'Self-Hosted',
    LocaleKeys.connModeCloud: '☁️ E2B Cloud',
    LocaleKeys.e2bTitle: 'E2B Cloud Workspace',
    LocaleKeys.e2bDesc:
        'Provision isolated MicroVM Linux & OpenCode sandbox in seconds via E2B.',
    LocaleKeys.e2bApiKey: 'E2B API Key',
    LocaleKeys.e2bApiKeyHint: 'API Key from e2b.dev/dashboard',
    LocaleKeys.e2bTemplate: 'Sandbox Template ID',
    LocaleKeys.e2bTemplateHint: 'Default: opencode (official pre-built)',
    LocaleKeys.e2bToolchains: 'Development Toolchains',
    LocaleKeys.e2bToolchainDart: '🎯 Dart SDK',
    LocaleKeys.e2bToolchainRust: '🦀 Rust & Cargo',
    LocaleKeys.e2bToolchainCpp: '🛠️ C/C++ (Clang/Make)',
    LocaleKeys.e2bToolchainPython: '🐍 Python 3',
    LocaleKeys.e2bGitConfig: 'Git Auto-Clone & Sync',
    LocaleKeys.e2bGitRepo: 'Repository URL',
    LocaleKeys.e2bGitRepoHint: 'https://github.com/owner/repo.git',
    LocaleKeys.e2bGitBranch: 'Branch (default: main)',
    LocaleKeys.e2bGitToken: 'GitHub / Gitee Token',
    LocaleKeys.e2bGitTokenHint: 'Personal Access Token',
    LocaleKeys.e2bGitUsername: 'Git Author Name',
    LocaleKeys.e2bGitEmail: 'Git Author Email',
    LocaleKeys.e2bLlmConfig: 'Cloud LLM API Key Injection',
    LocaleKeys.e2bAnthropicKey: 'Anthropic API Key',
    LocaleKeys.e2bOpenAiKey: 'OpenAI API Key',
    LocaleKeys.e2bGeminiKey: 'Gemini API Key',
    LocaleKeys.e2bDeepseekKey: 'DeepSeek API Key',
    LocaleKeys.e2bTtlHours: 'Cloud Retention TTL',
    LocaleKeys.e2bTtlDesc:
        'Cloud sandbox stays active even when mobile screen is locked or offline.',
    LocaleKeys.e2bAutoPause: 'Auto-Pause when Idle',
    LocaleKeys.e2bAutoPauseDesc:
        'Auto-snapshot and pause sandbox only when agent is idle to save costs and preserve state.',
    LocaleKeys.e2bLaunchWorkspace: '🚀 Launch Cloud Workspace',
    LocaleKeys.e2bLaunchingWorkspace: 'Launching E2B Sandbox...',
    LocaleKeys.e2bPauseSandbox: 'Pause',
    LocaleKeys.e2bResumeSandbox: 'Resume',
    LocaleKeys.e2bDestroySandbox: 'Destroy Sandbox',
    LocaleKeys.e2bSandboxList: 'Sandbox List',
    LocaleKeys.e2bCreateSandbox: 'New Sandbox',
    LocaleKeys.e2bRefreshList: 'Refresh List',
    LocaleKeys.e2bNoSandboxes: 'No Running Sandboxes',
    LocaleKeys.e2bNoSandboxesDesc:
        'Click "New Sandbox" in the top right to launch a MicroVM workspace',
    LocaleKeys.e2bApiKeyRequired: 'E2B API Key Required',
    LocaleKeys.e2bApiKeyRequiredDesc:
        'Configure your API key to view and manage cloud sandboxes on mobile',
    LocaleKeys.e2bConfigApiKey: 'Configure API Key',
    LocaleKeys.e2bCurrentlyConnected: 'Connected',
    LocaleKeys.e2bConnectSandbox: 'Connect',
    LocaleKeys.e2bConnectLastSandbox: 'Connect Last Sandbox',
    LocaleKeys.e2bWakeAndConnect: 'Wake & Connect',
    LocaleKeys.e2bManageSandboxes: 'Manage Sandboxes',
    LocaleKeys.e2bSandboxNotReadyWakeHint:
        'Previous sandbox is not ready. You can wake and connect.',
    LocaleKeys.e2bCloudBackend: 'E2B Cloud',
    LocaleKeys.selfHostedBackend: 'Self-Hosted',
    LocaleKeys.e2bNoApiKey: 'No E2B API Key Configured',
    LocaleKeys.e2bNoApiKeyDesc:
        'Please configure your E2B API Key in settings before using Cloud Workspace.',
    LocaleKeys.e2bNewSandbox: 'New Sandbox',
    LocaleKeys.switchToSelfHosted: 'Switch to Self-Hosted',
    LocaleKeys.connectionDisconnected: 'Disconnected',
    LocaleKeys.e2bClearInvalidSandbox: 'Clear Invalid Sandbox',
    LocaleKeys.e2bConfirmDestroy: 'Destroy Sandbox?',
    LocaleKeys.e2bConfirmDestroyDesc:
        'The sandbox will be permanently terminated. Uncommitted changes will be lost.',
    LocaleKeys.e2bSandboxStatusRunning: 'Running',
    LocaleKeys.e2bSandboxStatusPaused: '🟡 Paused',
    LocaleKeys.e2bSandboxDashboard: 'Sandbox Dashboard',
    LocaleKeys.e2bConfigWorkspace: 'Configure Cloud Workspace',
    LocaleKeys.e2bFetchRepos: '🔍 Fetch My Repos',
    LocaleKeys.e2bFetchingRepos: 'Fetching repositories...',
    LocaleKeys.e2bSelectRepo: 'Select Repository to Clone',
    LocaleKeys.e2bSearchRepos: 'Search repository name...',
    LocaleKeys.e2bNoReposFound: 'No repositories found',
    LocaleKeys.e2bGitTokenRequiredForRepos:
        'Please enter Personal Access Token first to fetch your repositories',
    LocaleKeys.e2bProvidersConfig: 'AI Model Providers Configuration',
    LocaleKeys.e2bConfigured: 'Configured',
    LocaleKeys.e2bNotConfigured: 'Not Set',
    LocaleKeys.e2bCustomBaseUrl: 'Custom API Base URL',
    LocaleKeys.e2bCustomBaseUrlHint: 'https://api.openai.com/v1',
    LocaleKeys.e2bRepoSelected: 'Selected GitHub repo: @repo',
    LocaleKeys.e2bTemplateHelper:
        "Leave empty for default 'opencode'; custom template can achieve instant startup",
    LocaleKeys.e2bGitProjectAndAuth: 'GitHub Repository & Auth',
    LocaleKeys.e2bGitPatLabel: 'GitHub Personal Access Token (PAT)',
    LocaleKeys.e2bGitPatHint: 'ghp_xxxx (with repo read/write access)',
    LocaleKeys.e2bFetchAndSelectRepo: '🔍 Fetch & Select My GitHub Repos',
    LocaleKeys.e2bSelectedRepoWithBranch: 'Selected: @repo (@branch)',
    LocaleKeys.e2bGitRepoUrlOptionalHint:
        'Optional: or paste Git clone URL directly',
    LocaleKeys.e2bFetchReposFailed: 'Failed to fetch GitHub repos: @error',
    LocaleKeys.e2bFetchReposTokenError:
        'Failed to fetch repos, please check GitHub Token permissions',
    LocaleKeys.e2bSelectGitHubRepo: 'Select GitHub Repository',
    LocaleKeys.e2bFetchingRepoList: 'Fetching your GitHub repositories...',
    LocaleKeys.e2bLaunchPreparing: 'Preparing to launch E2B Sandbox...',
    LocaleKeys.e2bApiKeyEmptyError:
        'E2B API Key cannot be empty, please configure it in settings',
    LocaleKeys.e2bLaunchRequestingVm: 'Requesting micro-VM sandbox from E2B...',
    LocaleKeys.e2bLaunchFailed: 'Failed to launch cloud sandbox',
    LocaleKeys.e2bLaunchConnecting:
        'Sandbox ready, establishing secure connection...',
    LocaleKeys.e2bHandshakeFailed: 'OpenCode connection handshake failed',
    LocaleKeys.e2bWorkspaceReady: 'E2B Cloud Workspace connected and ready',
    LocaleKeys.e2bLaunchErrorTitle: 'Launch Issue',
    LocaleKeys.e2bSandboxPreservedHint:
        'Sandbox instance is preserved. You can destroy or reconnect from sandbox list.',
    LocaleKeys.e2bConnectFailed: 'Failed to connect sandbox',
    LocaleKeys.e2bServiceUnreachable:
        'Unable to reach sandbox OpenCode service',
    LocaleKeys.e2bConnectedToSandbox: 'Connected to E2B sandbox: @id',
    LocaleKeys.e2bConnectionError: 'Connection failed: @error',
    LocaleKeys.e2bSandboxPausedSuccess: 'Sandbox @id paused',
    LocaleKeys.e2bSandboxPauseFailed: 'Failed to pause sandbox: @error',
    LocaleKeys.e2bSandboxResumedSuccess: 'Sandbox @id resumed and ready',
    LocaleKeys.e2bSandboxResumeFailed: 'Failed to resume sandbox: @error',
    LocaleKeys.e2bSandboxDestroyedSuccess: 'Sandbox @id destroyed',
    LocaleKeys.e2bSandboxDestroyFailed: 'Failed to destroy sandbox: @error',
    LocaleKeys.e2bCheckingStatus: 'Checking cloud sandbox status...',
    LocaleKeys.e2bSandboxConnected: 'Cloud sandbox connected',
    LocaleKeys.e2bAuthFailedTitle: 'Sandbox service running (Auth Failed)',
    LocaleKeys.e2bAuthFailedDesc:
        'Password mismatch, please reconnect from list',
    LocaleKeys.e2bServiceNotReadyTitle:
        'Sandbox service not ready (HTTP @status)',
    LocaleKeys.e2bServiceNotReadyDesc:
        'OpenCode not running, click connect in list to repair',
    LocaleKeys.e2bSandboxDisconnected: 'Cloud sandbox disconnected',
    LocaleKeys.e2bSandboxDisconnectedDesc: '@id · Click connect in list',
    LocaleKeys.e2bNoActiveSandbox: 'No active cloud sandbox',
    LocaleKeys.e2bNoActiveSandboxDesc: 'Create new or select sandbox from list',
    LocaleKeys.e2bFetchingSandboxes: 'Fetching E2B sandbox list...',
    LocaleKeys.e2bFetchSandboxesFailed: 'Failed to fetch sandboxes: @error',
    LocaleKeys.e2bStartedAt: 'Started at @time',
    LocaleKeys.e2bExpiresAt: 'Expires at @time',
    LocaleKeys.e2bCopySandboxId: 'Copy Sandbox ID',
    LocaleKeys.e2bProbingSandbox: 'Probing E2B cloud sandbox status...',
    LocaleKeys.e2bSandboxLabel: 'Sandbox: @id',

    // ── Settings – General ──
    LocaleKeys.secAppearance: 'Appearance & Layout',
    LocaleKeys.colorTheme: 'Color Theme',
    LocaleKeys.colorThemeDesc: 'Switch between light and dark modes.',
    LocaleKeys.dark: 'Dark',
    LocaleKeys.light: 'Light',
    LocaleKeys.language: 'Language',
    LocaleKeys.languageDesc: 'Switch the display language of the application.',
    LocaleKeys.wslIntegration: 'WSL Integration',
    LocaleKeys.wslIntegrationDesc:
        'Use Windows Subsystem for Linux for shell commands.',
    LocaleKeys.debugLogs: 'Debug Logs',
    LocaleKeys.debugLogsDesc: 'Export application logs to a specified folder.',

    LocaleKeys.secNotifications: 'Notifications',
    LocaleKeys.notificationSound: 'Notification Sound',
    LocaleKeys.notificationSoundDesc:
        'Play a sound when the AI finishes generating.',

    LocaleKeys.secShell: 'Shell & Environment',
    LocaleKeys.defaultShell: 'Default Shell',
    LocaleKeys.defaultShellDesc: 'Shell to use for terminal sessions.',
    LocaleKeys.logLevel: 'Log Level',
    LocaleKeys.logLevelDesc: 'Minimum log severity to record.',
    LocaleKeys.username: 'Username',
    LocaleKeys.usernameDesc: 'Display name for shared sessions.',
    LocaleKeys.usernamePlaceholder: 'Enter username...',

    LocaleKeys.secSharing: 'Sharing & Updates',
    LocaleKeys.sharingMode: 'Sharing Mode',
    LocaleKeys.sharingModeDesc: 'Control how sessions are shared.',
    LocaleKeys.autoUpdate: 'Auto Update',
    LocaleKeys.autoUpdateDesc: 'When to check for and apply updates.',
    LocaleKeys.snapshotTracking: 'Snapshot Tracking',
    LocaleKeys.snapshotTrackingDesc:
        'Enable snapshot-based version tracking for file changes.',
    LocaleKeys.snapshotWarningTitle: 'Snapshot Not Disabled',
    LocaleKeys.snapshotWarningDesc:
        'OpenCode built-in snapshot tracking is still enabled, which may conflict with some features.\n'
        'Set "snapshot": false in opencode.jsonc and try again.',
    LocaleKeys.csCacheBlockedBySnapshot:
        'Cache blocked: snapshot is not disabled. Set "snapshot": false in opencode.jsonc.',

    LocaleKeys.secCompaction: 'Compaction',
    LocaleKeys.autoCompaction: 'Auto Compaction',
    LocaleKeys.autoCompactionDesc:
        'Automatically compact long conversations to save context.',
    LocaleKeys.pruneOldOutputs: 'Prune Old Outputs',
    LocaleKeys.pruneOldOutputsDesc:
        'Remove outdated tool outputs during compaction.',

    // ── Settings – About ──
    LocaleKeys.secServerStatus: 'Server Status',
    LocaleKeys.openCodeVersion: 'OpenCode Version',
    LocaleKeys.checkForUpdates: 'Check for Updates',
    LocaleKeys.checkForUpdatesDesc: 'Upgrade OpenCode to the latest version.',
    LocaleKeys.secToolOutput: 'Tool Output',
    LocaleKeys.maxLines: 'Max Lines',
    LocaleKeys.maxLinesDesc: 'Maximum output lines to capture per tool call.',
    LocaleKeys.maxBytes: 'Max Bytes',
    LocaleKeys.maxBytesDesc: 'Maximum output size in bytes per tool call.',
    LocaleKeys.secCompactionAbout: 'Compaction',
    LocaleKeys.tailTurns: 'Tail Turns',
    LocaleKeys.tailTurnsDesc:
        'Number of recent turns to retain during compaction.',
    LocaleKeys.reservedTokens: 'Reserved Tokens',
    LocaleKeys.reservedTokensDesc:
        'Context window tokens reserved for the response.',

    // ── Settings – Providers ──
    LocaleKeys.providers: 'Providers',
    LocaleKeys.secConnectedProviders: 'Connected Providers',
    LocaleKeys.noConnectedProviders: 'No connected providers',
    LocaleKeys.secAllProviders: 'All Providers',
    LocaleKeys.searchProvidersPlaceholder: 'Search providers...',
    LocaleKeys.noMatchingProviders: 'No matching providers',
    LocaleKeys.secCustomProvider: 'Custom Provider',
    LocaleKeys.customProvider: 'Custom Provider',
    LocaleKeys.customProviderTag: 'Custom',
    LocaleKeys.customProviderDesc:
        'Add an OpenAI-compatible provider with custom models.',
    LocaleKeys.secBlockedProviders: 'Blocked Providers',
    LocaleKeys.noBlockedProviders: 'No blocked providers',
    LocaleKeys.providersRestored: 'Provider restored',

    // ── Settings – Models ──
    LocaleKeys.models: 'Models',
    LocaleKeys.smallModel: 'Small / Fast Model',
    LocaleKeys.smallModelDesc:
        'Lightweight model for quick operations and compaction.',
    LocaleKeys.searchModelsPlaceholder: 'Search models...',
    LocaleKeys.noModelsLoaded: 'No models loaded.',
    LocaleKeys.noMatchingModels: 'No matching models.',

    // ── Settings – MCP ──
    LocaleKeys.addMcpServer: 'Add MCP Server',
    LocaleKeys.serverNamePlaceholder: 'Server name (e.g. my-mcp)',
    LocaleKeys.connectionType: 'Connection Type',
    LocaleKeys.localStdio: 'Local (stdio)',
    LocaleKeys.localSse: 'Local (sse)',
    LocaleKeys.remoteUrl: 'Remote (URL)',
    LocaleKeys.commandPlaceholder: 'Command (e.g. npx, uvx, node)',
    LocaleKeys.argsPlaceholder: 'Arguments (space-separated)',
    LocaleKeys.serverUrlPlaceholder: 'Server URL (e.g. http://localhost:3000)',

    // ── Settings – Permissions ──
    LocaleKeys.secBulkActions: 'Bulk Actions',
    LocaleKeys.applyToAllTools: 'Apply to all tools:',
    LocaleKeys.ask: 'Ask',
    LocaleKeys.allow: 'Allow',
    LocaleKeys.deny: 'Deny',
    LocaleKeys.toolPermissions: 'Tool Permissions',

    // ── Settings – Agent ──
    LocaleKeys.agentConfigs: 'Agent Configurations',
    LocaleKeys.newAgent: 'New Agent',
    LocaleKeys.noAgentsConfigured: 'No agents configured.',
    LocaleKeys.failedToLoadAgents: 'Failed to load agents',

    // ── Settings – Developer ──
    LocaleKeys.developer: 'Developer',
    LocaleKeys.secCommands: 'Commands',
    LocaleKeys.addCommand: 'Add Command',
    LocaleKeys.cmdNamePlaceholder: 'Command name (no /)',

    // ── Settings – Advanced ──
    LocaleKeys.advanced: 'Advanced',

    // ── Settings – Experimental ──
    LocaleKeys.experimental: 'Experimental',
    LocaleKeys.secFeatures: 'Features',
    LocaleKeys.batchTool: 'Batch Tool',
    LocaleKeys.batchToolDesc:
        'Enable the batch tool for running multiple tools in parallel.',
    LocaleKeys.disablePasteSummary: 'Disable Paste Summary',
    LocaleKeys.disablePasteSummaryDesc:
        'Skip summarization when pasting content into the chat.',
    LocaleKeys.continueLoopOnDeny: 'Continue Loop on Deny',
    LocaleKeys.continueLoopOnDenyDesc:
        'Continue the agent loop when a tool call is denied.',
    LocaleKeys.openTelemetry: 'OpenTelemetry',
    LocaleKeys.openTelemetryDesc:
        'Enable OpenTelemetry spans for AI SDK calls.',
    LocaleKeys.fileWatcher: 'File Watcher',
    LocaleKeys.fileWatcherDesc: 'File change detection backend.',
    LocaleKeys.fileWatcherRestartHint:
        'Restart the local sidecar server for this to take effect.',
    LocaleKeys.restartSidecar: 'Restart Sidecar',
    LocaleKeys.sidecarRestarting: 'Restarting sidecar...',
    LocaleKeys.sidecarRestarted:
        'Sidecar restarted and the setting is now active.',
    LocaleKeys.sidecarRestartFailed:
        'Failed to restart sidecar. Check logs and retry.',
    LocaleKeys.settingsBlockedByGeneration:
        'A session is currently generating. Finish or abort it before changing this setting.',
    LocaleKeys.secMcp: 'MCP',
    LocaleKeys.mcpTimeout: 'MCP Timeout (ms)',
    LocaleKeys.mcpTimeoutDesc: 'Timeout in milliseconds for MCP requests.',
    LocaleKeys.secPrimaryTools: 'Primary Tools',
    LocaleKeys.primaryTools: 'Primary Tools',
    LocaleKeys.primaryToolsDesc:
        'Tools that should only be available to primary agents.',

    // ── Settings – Rules ──
    LocaleKeys.globalAgentsMd: 'Global AGENTS.md',
    LocaleKeys.globalAgentsDesc: 'Rules applied to all opencode sessions.',
    LocaleKeys.globalAgentsReadOnlyBanner:
        'Remote clients cannot write AGENTS.md — edit on the server or desktop.',
    LocaleKeys.enterGlobalRules: 'Enter global rules (Markdown)...',
    LocaleKeys.instructions: 'Instructions (opencode.json)',
    LocaleKeys.instructionsDesc:
        'Additional instruction files referenced from opencode.json.',
    LocaleKeys.noCustomInstructions: 'No custom instructions configured.',
    LocaleKeys.globalRulesSaved: 'Global rules saved successfully.',
    LocaleKeys.saved: 'Saved',

    // ── Settings – Skills ──
    LocaleKeys.skillSavedSuccess: 'Skill saved successfully!',
    LocaleKeys.skillSaveFailed: 'Failed to save skill',
    LocaleKeys.skillsFailedLoad: 'Failed to load',
    LocaleKeys.skillsNoLoaded: 'No skills loaded.',

    // ── Tool Cards ──
    LocaleKeys.enterYourAnswer: 'Enter your answer...',
    LocaleKeys.enterYourAnswerHere: 'Enter your answer here...',

    // ── Git Diff ──
    LocaleKeys.rolledBack: 'Rolled back current change block',

    // ── Editor Panel ──
    LocaleKeys.edKeyboardShortcuts: 'Keyboard Shortcuts',
    LocaleKeys.edTypography: 'Typography',
    LocaleKeys.edEditorFeatures: 'Editor Features',
    LocaleKeys.edShowLineNumbers: 'Show Line Numbers',
    LocaleKeys.edEnableCodeFolding: 'Enable Code Folding',
    LocaleKeys.edShowGuideLines: 'Show Guide Lines',
    LocaleKeys.edFormatOnSave: 'Format on Save',
    LocaleKeys.edHighlightTheme: 'Highlight Theme',
    LocaleKeys.edFollowSystem: 'Follow System (Auto)',
    LocaleKeys.edWorkflow: 'Workflow',
    LocaleKeys.edAutoSendDiagnostics: 'Auto-send diagnostics after build',
    LocaleKeys.edAutoSendDiagnosticsDesc:
        'Automatically send build errors and warnings to chat.',
    LocaleKeys.edLspServers: 'Editor LSP Servers',
    LocaleKeys.edNoLspServers: 'No LSP servers configured.',
    LocaleKeys.edTabNavigation: 'Tab Navigation',
    LocaleKeys.edFileOperations: 'File Operations',
    LocaleKeys.edEditorOperations: 'Editor Operations',
    LocaleKeys.edReset: 'Reset',
    LocaleKeys.edPreviousTab: 'Previous Tab',
    LocaleKeys.edNextTab: 'Next Tab',
    LocaleKeys.edEditorSettings: 'Editor Settings',
    LocaleKeys.edUnsavedChanges: 'Unsaved Changes',
    LocaleKeys.edUnsavedChangesDesc:
        'The following files have unsaved changes. Closing will lose these changes.',
    LocaleKeys.edDiskChangedTitle: 'Disk File Changed',
    LocaleKeys.edDiskChangedDesc:
        '"@file" was changed on disk while this tab has unsaved edits.\n\nChoose whether to overwrite the disk with your current editor buffer or reload the disk version.',
    LocaleKeys.edDiskChangedTooltip:
        'Disk changed while this tab has unsaved edits',
    LocaleKeys.edSaveCurrentBuffer: 'Save Current Buffer',
    LocaleKeys.edClose: 'Close',
    LocaleKeys.edCloseOthers: 'Close Others',
    LocaleKeys.edCloseRight: 'Close Tabs to the Right',
    LocaleKeys.edCloseSaved: 'Close Saved',
    LocaleKeys.edCloseAll: 'Close All',
    LocaleKeys.edCopyPath: 'Copy Path',
    LocaleKeys.edCopyRelativePath: 'Copy Relative Path',
    LocaleKeys.edWaitingForKeys: 'Waiting for keys...',
    LocaleKeys.edCopyAbsPathFailed: 'Failed to copy absolute path',
    LocaleKeys.edCopyRelPathFailed: 'Failed to copy relative path',

    // ── Chat Setting ──
    LocaleKeys.csShowThinking: 'Show Thinking',
    LocaleKeys.csShowThinkingDesc:
        'Show model reasoning content in the timeline.',
    LocaleKeys.csTabDisplay: 'Display',
    LocaleKeys.csTabBuild: 'Build',
    LocaleKeys.csMultiBuild: 'Multi-Build',
    LocaleKeys.csMultiBuildDesc:
        'Allow multiple sessions to run build agent simultaneously.',
    LocaleKeys.csShell: 'Shell',
    LocaleKeys.csShellDesc: 'Auto-collapse bash command cards after completion',
    LocaleKeys.csKeywordDetection: 'Keyword Detection',
    LocaleKeys.csKeywordDetectionDesc:
        'Check current turn\'s text/markdown content after AI finishes generating',
    LocaleKeys.csQuickPhrases: 'Quick Phrases',
    LocaleKeys.csAutoSend: 'Auto Send',
    LocaleKeys.csAutoSendDesc: 'Clicking a phrase sends it directly.',
    LocaleKeys.csAdd: 'Add',
    LocaleKeys.csNoQuickPhrases: 'No quick phrases',
    LocaleKeys.csEdit: 'Edit',
    LocaleKeys.csInputKeyword: 'Enter keyword',
    LocaleKeys.csInputPhrase: 'Enter phrase',
    LocaleKeys.csTabReview: 'Review',
    LocaleKeys.csReviewScope: 'Review Scope',
    LocaleKeys.csReviewScopeDesc: 'Select the file scope for code review',
    LocaleKeys.csReviewScopeUncommitted: 'Uncommitted files',
    LocaleKeys.csReviewScopeCurrentWindow: 'Files modified in this window',
    LocaleKeys.csReviewModel: 'Review Model',
    LocaleKeys.csReviewModelDesc: 'Select the model to perform code review',
    LocaleKeys.csReviewThinkingLevel: 'Thinking Level',
    LocaleKeys.csReviewThinkingLevelDesc:
        'Select the model reasoning/thinking level',
    LocaleKeys.csReviewPrompt: 'Review Prompt',
    LocaleKeys.csReviewPromptDesc:
        'Customize the review instruction sent to the model',
    LocaleKeys.csReviewPromptReset: 'Reset to Default',
    LocaleKeys.csWatcherDiffOverlay: 'Show Disk Change Diff',
    LocaleKeys.csWatcherDiffOverlayDesc:
        'Show watcher-detected disk changes as pending diffs. When off, these changes are treated as accepted disk content.',
    LocaleKeys.csPromptSuggest: 'Mentions',
    LocaleKeys.csPromptSuggestEnabled: 'Enable Mentions',
    LocaleKeys.csPromptSuggestEnabledDesc:
        'Suggest files and symbols when typing @ in prompt input',
    LocaleKeys.csPromptSuggestPaths: 'Scan Paths',
    LocaleKeys.csPromptSuggestPathsDesc:
        'Choose directories to scan; leave empty to scan the whole project. .gitignore and .ignore are respected automatically',
    LocaleKeys.csInputPath: 'Enter path (e.g. lib or rust/src)...',
    LocaleKeys.csPromptSuggestExclude: 'Excluded Directories',
    LocaleKeys.csPromptSuggestExcludeDesc:
        'Skip directories with these names during scan (e.g. target, build)',
    LocaleKeys.csInputExcludeName: 'Enter dir name (e.g. build)...',
    LocaleKeys.csCache: 'Diff Core',
    LocaleKeys.csCacheNoGitignore:
        'No .gitignore found. Diff cache is unavailable for now.',
    LocaleKeys.csCacheTrackedPaths: 'Tracked paths',
    LocaleKeys.csCacheTrackedPathsDesc:
        'Leave empty to cache files that are not ignored by .gitignore. To cache only part of the project, enter paths like lib, rust/src, or pubspec.yaml.',
    LocaleKeys.csCacheAddTrackedPath: 'Add tracked path',
    LocaleKeys.csCacheExtraExcludes: 'Extra excludes',
    LocaleKeys.csCacheAddExcludedPath: 'Add excluded path',
    LocaleKeys.csCacheInvalidPath:
        'Path must be workspace-relative and cannot contain . or ..: @path',
    LocaleKeys.csCacheRebuildTitle: 'Rebuild backup cache',
    LocaleKeys.csCacheRebuildContent:
        'This removes the existing .opencode-git cache and rebuilds it. Old checkpoints and revert points will be lost.',
    LocaleKeys.csCacheRebuild: 'Rebuild',
    LocaleKeys.csCacheRefresh: 'Refresh cache',
    LocaleKeys.csCacheRebuildBtn: 'Rebuild cache',
    LocaleKeys.csCacheCompress: 'Compress cache',
    LocaleKeys.csCacheOpenFolder: 'Open folder',
    LocaleKeys.csCacheOpCompleted: 'Diff cache updated.',
    LocaleKeys.csCacheOpFailed: 'Diff cache failed: @error',
    LocaleKeys.csCacheGitignoreRequired:
        'No .gitignore found, so Diff cache was skipped. Create .gitignore, then reopen the project or rebuild the cache in settings.',
    LocaleKeys.csTabMultiSession: 'Multi-Session Dispatch',
    LocaleKeys.csMultiSessionModel: 'Select Model',
    LocaleKeys.csMultiSessionThinkingLevel: 'Thinking Level',
    LocaleKeys.csMultiSessionThinkingLevelDesc:
        'Set the model\'s thinking level.',
    LocaleKeys.csMultiSessionConfiguredListTitle: 'Configured Models',
    LocaleKeys.csMultiSessionEmptyList: 'No models added yet',
    LocaleKeys.chatMultiSessionTooltip:
        'Invoke multiple models at once (Plan mode only)',

    // ── Prompt Input ──
    LocaleKeys.piBuildRunning: 'Session is running Build...',
    LocaleKeys.piBuildFailed: 'Execution failed',
    LocaleKeys.piSecurityRequest: 'Security Authorization Request',
    LocaleKeys.piDenyOperation: 'Deny Operation',
    LocaleKeys.piAlwaysAllow: 'Always Allow',
    LocaleKeys.piAllowExecute: 'Allow Execution',
    LocaleKeys.piTodoItems: 'Todo Items',
    LocaleKeys.piChangedFiles: 'Changed Files',
    LocaleKeys.piSelectSession: 'Select a session to begin...',
    LocaleKeys.piAttachFile: 'Attach file (Ctrl+U)',
    LocaleKeys.piBuildLocked: 'Build locked by another session',
    LocaleKeys.piStop: 'Stop (Esc)',
    LocaleKeys.piNoAgent: 'No Agent',
    LocaleKeys.piKeep: 'Keep',
    LocaleKeys.piKeepAll: 'Keep',
    LocaleKeys.piCancelAll: 'Cancel',
    LocaleKeys.piSendNow: 'Send Now',

    // ── Session Header ──
    LocaleKeys.shSessionTitle: 'OpenCode Session',
    LocaleKeys.shSessionsHistory: 'Sessions History',
    LocaleKeys.shChatSettings: 'Chat Settings',
    LocaleKeys.shUndoRevert: 'Undo Revert',
    LocaleKeys.shUndoRevertDesc:
        'Do you want to undo the previous revert operation?',
    LocaleKeys.shUndoRevertDescWithFiles:
        'Undo the previous revert? Chat will be restored, and @count reverted file(s) will be restored.',
    LocaleKeys.shUndoRevertDescChatOnly:
        'Undo the previous revert? Only chat can be restored. No local file list is available (common after restart or chat-only revert), so workspace files cannot be restored.',
    LocaleKeys.shCancelRevert: 'Cancel Revert',
    LocaleKeys.shConfirmRevert: 'Confirm Revert',
    LocaleKeys.shConfirmRevertDesc:
        'Revert to this user message? This will discard later session changes.',
    LocaleKeys.shConfirmRevertAffected: 'Files to restore',
    LocaleKeys.shConfirmRevertNoFiles: 'No file changes for this option',
    LocaleKeys.shConfirmRevertSummary: '@files files · +@add -@del',
    LocaleKeys.shConfirmRevertCheckpointMissing:
        'Checkpoint for this message is missing. Confirming will only revert chat messages; workspace files cannot be restored.',
    LocaleKeys.shConfirmRevertWorkspaceMissing:
        'Workspace backup baseline is unavailable. File preview and restore cannot proceed. Please try again.',
    LocaleKeys.shConfirmRevertPreviewFailed:
        'Could not preview affected files. Please try again.',
    LocaleKeys.shConfirmRevertScopeTitle: 'File restore scope',
    LocaleKeys.shConfirmRevertScopeChat: 'Chat only',
    LocaleKeys.shConfirmRevertScopeChatDesc:
        'Revert later chat messages only. Leave workspace files unchanged.',
    LocaleKeys.shConfirmRevertScopeSession: 'This session only',
    LocaleKeys.shConfirmRevertScopeSessionDesc:
        'Restore only files tracked by this session. Safer for multi-session work.',
    LocaleKeys.shConfirmRevertScopeWorkspace: 'Full workspace',
    LocaleKeys.shConfirmRevertScopeWorkspaceDesc:
        'Restore every file that differs from this message checkpoint. May overwrite other sessions or manual edits.',
    LocaleKeys.shConfirmRevertRelatedMissing:
        'Could not identify this session\'s owned files (common after restart). Defaults to chat only; choose Full workspace manually to restore files.',
    LocaleKeys.shConfirmRevertWorkspaceRisk:
        'Warning: full restore may affect files changed by other sessions.',
    LocaleKeys.shRevertBlockedGenerating:
        'Generation is in progress. Wait until it finishes before reverting.',
    LocaleKeys.shRevertCheckpointMissingChatOnly:
        'Message checkpoint is missing. Falling back to chat-only revert.',
    LocaleKeys.shRevertFailed: 'Revert failed. Check logs and try again.',
    LocaleKeys.shRevertFailedAfterPartial:
        'Revert failed partway. Chat was restored if possible. Check workspace files for consistency.',
    LocaleKeys.shRevertCompensationFailed:
        'Revert failed and chat could not be restored automatically. Chat and files may be inconsistent.',
    LocaleKeys.shUnrevertFailed:
        'Undo revert failed. Check logs and try again.',
    LocaleKeys.shUnrevertChatOnlyNoFiles:
        'Chat revert was undone. No restored file list was available.',
    LocaleKeys.shSessionHistory: 'Session History',
    LocaleKeys.shSearchHistory: 'Search historical sessions...',
    LocaleKeys.shNoMatches: 'No matches found',
    LocaleKeys.shNoHistory: 'No session history in this project',
    LocaleKeys.shDeleteSession: 'Delete Session',

    // ── File Tree ──
    LocaleKeys.ftRenameFailed: 'Rename failed',
    LocaleKeys.ftCreateFailed: 'Create failed',
    LocaleKeys.ftDeleteFailed: 'Delete failed',
    LocaleKeys.ftNewFile: 'New File',
    LocaleKeys.ftNewFolder: 'New Folder',
    LocaleKeys.ftCopy: 'Copy',
    LocaleKeys.ftPaste: 'Paste',
    LocaleKeys.ftCut: 'Cut',
    LocaleKeys.ftCopyPath: 'Copy Path',
    LocaleKeys.ftCopyRelativePath: 'Copy Relative Path',
    LocaleKeys.ftRename: 'Rename',
    LocaleKeys.ftDelete: 'Delete',
    LocaleKeys.unsupportedBinaryFile: 'Unsupported binary file: @file',

    // ── Git Panel ──
    LocaleKeys.gpSyncSuccess: 'Sync Success',
    LocaleKeys.gpSyncFailed: 'Sync Failed',
    LocaleKeys.gpCommitSuccess: 'Commit successful',
    LocaleKeys.gpDiscardChanges: 'Discard Changes',
    LocaleKeys.gpConfirmDiscard: 'Confirm Discard',
    LocaleKeys.gpChanges: 'Changes',
    LocaleKeys.gpRefreshStatus: 'Refresh Status',
    LocaleKeys.gpGraph: 'Graph',
    LocaleKeys.gpSwitchBranch: 'Switch Branch',
    LocaleKeys.gpSyncChanges: 'Sync Changes',
    LocaleKeys.gpCommit: 'Commit',
    LocaleKeys.gpMoreOptions: 'More Commit Options',
    LocaleKeys.gpCommitAndPush: 'Commit and Push',
    LocaleKeys.gpCopyCommitHash: 'Copy Commit Hash',
    LocaleKeys.gpNoFileChanges: 'No file changes',
    LocaleKeys.gpLocalPushed: 'Local commit (pushed)',
    LocaleKeys.gpNotPushed: 'Not pushed to remote',
    LocaleKeys.gpViewDiff: 'View Diff',
    LocaleKeys.gpDiscardTooltip: 'Discard Changes',
    LocaleKeys.gpStageChanges: 'Stage Changes',
    LocaleKeys.gpSearchCommits: 'Search commits…',
    LocaleKeys.gpNoMatchingCommits: 'No matching commits',

    // ── Terminal ──
    LocaleKeys.termNoTerminal: 'No terminal',
    LocaleKeys.termNoOutput: 'No output',

    // ── Keyboard Shortcuts (labels) ──
    LocaleKeys.kbPrevTab: 'Previous Tab',
    LocaleKeys.kbNextTab: 'Next Tab',
    LocaleKeys.kbCloseTab: 'Close Tab',
    LocaleKeys.kbCloseTabAlt: 'Close Tab (Alternative)',
    LocaleKeys.kbCloseAllTabs: 'Close All Tabs',
    LocaleKeys.kbCloseSavedTabs: 'Close Saved Tabs',
    LocaleKeys.kbCopyAbsPath: 'Copy Absolute Path',
    LocaleKeys.kbCopyRelPath: 'Copy Relative Path',
    LocaleKeys.kbSendToInput: 'Send Selection to Input',
    LocaleKeys.kbFind: 'Find',
    LocaleKeys.kbFindReplace: 'Replace',
    LocaleKeys.kbSave: 'Save File',
    LocaleKeys.kbDuplicateLine: 'Duplicate Current Line',
    LocaleKeys.kbUndo: 'Undo',
    LocaleKeys.kbRedo: 'Redo',
    LocaleKeys.kbMoveLineUp: 'Move Line Up',
    LocaleKeys.kbMoveLineDown: 'Move Line Down',
    LocaleKeys.kbWordLeft: 'Move Cursor Word Left',
    LocaleKeys.kbWordRight: 'Move Cursor Word Right',
    LocaleKeys.kbDeleteWordBack: 'Delete Word Backward',
    LocaleKeys.kbDeleteWordForward: 'Delete Word Forward',
    LocaleKeys.kbGoToDocStart: 'Go to Document Start',
    LocaleKeys.kbGoToDocEnd: 'Go to Document End',
    LocaleKeys.kbCodeActions: 'Code Actions (LSP)',
    LocaleKeys.kbRenameSymbol: 'Rename Symbol',
    LocaleKeys.kbFormat: 'Format Document',
    LocaleKeys.kbToggleComment: 'Toggle Line Comment',

    // ── LSP ──
    LocaleKeys.lspConfigDesc:
        'Configure language servers for code diagnostics and completion',
    LocaleKeys.lspAgentLsp: 'AI Agent LSP',
    LocaleKeys.lspAgentDiagDesc:
        'Control language server diagnostic feedback for AI Agent.',
    LocaleKeys.lspAvailableServers: 'Available Language Servers',
    LocaleKeys.lspBackendManagedDesc:
        'Language servers are managed by the OpenCode backend and require a service restart after installation.',
    LocaleKeys.lspNotDetected: '@cmd not detected, please install it first',
    LocaleKeys.lspInstalling: 'Installing...',
    LocaleKeys.lspInstall: 'Install',
    LocaleKeys.lspInstallDartSdkTip:
        'Please install Flutter/Dart SDK and restart the app',
    LocaleKeys.lspInstallManualTip:
        'Please manually install @name (executable: @cmd) and restart the app',
    LocaleKeys.lspInstallSuccess: '@name installed successfully',
    LocaleKeys.lspInstallFailed: '@name installation failed (exit @exitCode)',
    LocaleKeys.lspDartDesc: 'Dart Language Service (comes with Flutter SDK)',
    LocaleKeys.lspRustDesc: 'Rust Language Analyzer',
    LocaleKeys.lspPythonDesc: 'Python Language Analyzer (Pyright)',
    LocaleKeys.lspGoDesc: 'Go Language Official Server',
    LocaleKeys.lspJsTsDesc: 'JS/TS Language Service',
    LocaleKeys.lspHtmlDesc: 'HTML Language Service',
    LocaleKeys.lspCssDesc: 'CSS Language Service',
    LocaleKeys.lspJsonDesc: 'JSON Language Service',
    LocaleKeys.lspCppDesc: 'C/C++ Language Analyzer',
    LocaleKeys.lspBashDesc: 'Bash Language Service',
    LocaleKeys.lspYamlDesc: 'YAML Language Service',
    LocaleKeys.lspLuaDesc: 'Lua Language Service',

    // ── Terminal ──
    LocaleKeys.termTerminal: 'Terminal',
    LocaleKeys.termProblems: 'Problems',
    LocaleKeys.termOutput: 'Output',
    LocaleKeys.termDefaultShellAuto: 'Default Shell (auto-detect)',
    LocaleKeys.termCopyAll: 'Copy All',
    LocaleKeys.termSendAllToAi: 'Send All to AI',
    LocaleKeys.termCopy: 'Copy',
    LocaleKeys.termSendToAi: 'Send to AI',

    // ── Git & Editor ──
    LocaleKeys.gitSwitchedBranch: 'Switched to branch: @branch',
    LocaleKeys.gitSwitchBranchFailed: 'Switch branch failed: @error',
    LocaleKeys.gitSwitchBranchError: 'Switch branch error: @error',
    LocaleKeys.gitConfirmDiscardChanges:
        'Are you sure you want to discard all uncommitted changes for "@file"? This action cannot be undone.',
    LocaleKeys.gitCommitAmend: 'Commit (Amend)',
    LocaleKeys.gitFilesChanged: 'Changed @count files',
    LocaleKeys.gitLinesInserted: '@count insertions(+)',
    LocaleKeys.gitLinesDeleted: '@count deletions(-)',
    LocaleKeys.gitNoChangesLine: ', 0 insertions(+), 0 deletions(-)',
    LocaleKeys.gitCopiedCommitHash: 'Copied commit hash: @hash',
    LocaleKeys.gitOpenOnGithub: 'Open on GitHub',
    LocaleKeys.gitHunkRevertFailed: 'Hunk revert failed: @error',
    LocaleKeys.gitRevertHunk: 'Revert this hunk',
    LocaleKeys.previewOnly: 'Preview Only',
    LocaleKeys.editAndPreview: 'Edit & Preview',
    LocaleKeys.edMdPreview: 'Preview',
    LocaleKeys.edMdRaw: 'Edit',
    LocaleKeys.preview: 'Preview',
    LocaleKeys.edit: 'Edit',

    // ── Chat & Session ──
    LocaleKeys.chatBuildRunningError: 'Session [@name] is running Build',
    LocaleKeys.chatExecutionFailed: 'Execution failed',
    LocaleKeys.chatPermissionRequestDesc:
        'AI is requesting [@type] permission, scope/target:',
    LocaleKeys.chatBuildLockedTitle: 'Build Locked',
    LocaleKeys.chatBuildLockedDesc:
        'Session [@name] is running Build. To avoid file conflicts, this window is locked. Wait for it to complete or switch to Plan agent.',
    LocaleKeys.chatTodoTitle: 'Todo Items',
    LocaleKeys.chatChangedFilesTitle: 'Changed Files',
    LocaleKeys.chatConfirmPermissionsFirst:
        'Please confirm the security permission requests above first...',
    LocaleKeys.chatFileCount: '@count files',
    LocaleKeys.chatImageCount: '@count images',
    LocaleKeys.chatQueuingWithParts: 'Queuing: @parts',
    LocaleKeys.chatQueuing: 'Queuing...',
    LocaleKeys.chatManualCompact: 'Manual Compact',
    LocaleKeys.chatQuickPhrases: 'Quick Phrases',
    LocaleKeys.chatSelectSessionFirst: 'Please select a session first',
    LocaleKeys.chatLoadingMessages: 'Loading messages...',
    LocaleKeys.chatStartConversation: 'Start a conversation',
    LocaleKeys.chatLoadMessagesFailed: 'Failed to load, tap to retry',
    LocaleKeys.chatWaitGenerationToCompact:
        'Active session is generating, wait until it finishes to compact',
    LocaleKeys.chatManualCompactCompleted: 'Manual compaction completed',
    LocaleKeys.chatContextCompaction: 'Context Compaction',
    LocaleKeys.chatCompactionFailed: 'Compaction failed',
    LocaleKeys.chatForkFailed: 'Failed to fork session',
    LocaleKeys.mcpConnectFailed:
        'Failed to connect to opencode service, make sure sidecar is running',
    LocaleKeys.permDenied: 'Permission Denied',
    LocaleKeys.permRequest: 'Permission Request',
    LocaleKeys.toolRequestingUse: 'AI requests to use [@name] tool:',
    LocaleKeys.permRead: 'Read files',
    LocaleKeys.permWrite: 'Write files',
    LocaleKeys.permExecute: 'Execute commands',
    LocaleKeys.permWeb: 'Access websites',
    LocaleKeys.defaultKeywordPossible: 'possible',
    LocaleKeys.chatBuildFixedProblemsPrompt:
        'The following problems were detected after Build completed, please fix them:\n\n@diagText',
    LocaleKeys.toolApprovedMsg:
        'Approved execution of [@name] operation, please proceed.',
    LocaleKeys.toolDeniedMsg:
        'Denied execution of [@name] operation, please use another method.',
    LocaleKeys.questionAskPrefix: 'Q: @text',
    LocaleKeys.questionAnswerPrefix: 'A: ',

    // ── Feedback Notifications ──
    LocaleKeys.feedbackTitle: 'OpenCode',
    LocaleKeys.feedbackCompleted: 'AI generation completed',
    LocaleKeys.feedbackCompletedMsg: 'Session @session has finished its reply',
    LocaleKeys.feedbackError: 'AI generation error',
    LocaleKeys.feedbackErrorMsg: 'Session @session error: @error',
    LocaleKeys.feedbackQuestion: 'AI is asking a question',
    LocaleKeys.feedbackQuestionMsg: 'Session @session needs your answer',
    LocaleKeys.feedbackPermission: 'Permission request',
    LocaleKeys.feedbackPermissionMsg:
        'Session @session is requesting permission',

    // ── Skills ──
    LocaleKeys.skillsPathsTooltip:
        "This path points to a directory containing skill folders.\n"
        "Skill requirements:\n"
        "1. Must contain a file named SKILL.md under the skill folder.\n"
        "2. The file must start with YAML Frontmatter, formatted as:\n"
        "---\n"
        "name: Skill Name\n"
        "description: Skill Description\n"
        "---\n"
        "# Detailed skill prompt content",

    // ── Common/General ──
    LocaleKeys.ok: 'OK',
    LocaleKeys.success: 'Success',
    LocaleKeys.error: 'Error',
    LocaleKeys.required: 'Required',
    LocaleKeys.duplicate: 'Duplicate',
    LocaleKeys.install: 'Install',

    // ── Rules Tab ──
    LocaleKeys.rulesClaudeCompatTitle: 'Claude Code Compatibility',
    LocaleKeys.rulesClaudeCompatDesc:
        'OpenCode supports CLAUDE.md as a fallback when AGENTS.md is not found.',
    LocaleKeys.rulesClaudeCompatEnv:
        'To disable Claude Code compatibility, set environment variable:\nOPENCODE_DISABLE_CLAUDE_CODE=1',
    LocaleKeys.rulesAddInstructionPath: 'Add Instruction Path',
    LocaleKeys.rulesInstructionPathPlaceholder: 'e.g. docs/guidelines.md',

    // ── Skills Tab ──
    LocaleKeys.skillsAdditionalPaths: 'Additional Paths',
    LocaleKeys.skillsRemoteUrls: 'Remote URLs',
    LocaleKeys.skillsLoadedSkills: 'Loaded Skills',
    LocaleKeys.skillsSaveSources: 'Save Sources',
    LocaleKeys.skillsSaveContent: 'Save Content',
    LocaleKeys.skillsBuiltinReadOnly: 'Built-in Skill (Read-only)',
    LocaleKeys.skillsLocalFileSkill: 'Local File Skill',
    LocaleKeys.skillsBuiltinDesc:
        'This skill is built into OpenCode and cannot be edited.',
    LocaleKeys.skillsSelectFolderTip:
        'Click folder icon on the right to select...',
    LocaleKeys.skillsBrowseFolderTooltip: 'Browse and add folder...',
    LocaleKeys.skillsBack: 'Back',

    // ── Providers Tab ──
    LocaleKeys.providersConnect: 'Connect',
    LocaleKeys.providersShowAll: 'Show All (@totalCount providers) →',
    LocaleKeys.providersProviderId: 'Provider ID',
    LocaleKeys.providersProviderIdPlaceholder: 'Enter Provider ID (Required)',
    LocaleKeys.providersProviderIdError:
        'Use lowercase letters, numbers, - or _',
    LocaleKeys.providersName: 'Name',
    LocaleKeys.providersNamePlaceholder: 'Provider Name',
    LocaleKeys.providersBaseUrl: 'Base URL',
    LocaleKeys.providersBaseUrlPlaceholder: 'Enter Base URL',
    LocaleKeys.providersBaseUrlError: 'Must start with http:// or https://',
    LocaleKeys.providersApiKey: 'API Key',
    LocaleKeys.providersApiKeyPlaceholder: 'Enter API key, e.g. sk-...',
    LocaleKeys.providersAddModel: 'Add model',
    LocaleKeys.providersAddHeader: 'Add header',
    LocaleKeys.providersModelId: 'Model ID',
    LocaleKeys.providersModelName: 'Model Name',
    LocaleKeys.providersHeaderKey: 'Header Key',
    LocaleKeys.providersHeaderValue: 'Header Value',
    LocaleKeys.providersRecommended: 'Recommended',
    LocaleKeys.providersEditKey: 'Edit key',
    LocaleKeys.providersDeleteKey: 'Delete key',
    LocaleKeys.providersAddKey: 'Add key',
    LocaleKeys.providersKeyUpdatePlaceholder: 'Enter new key to update...',
    LocaleKeys.providersKeyEnterPlaceholder: 'Enter API key for @name...',
    LocaleKeys.providersOauth: 'OAuth',
    LocaleKeys.providersOauthSuccess: 'OAuth authorization successful',
    LocaleKeys.providersOauthFailed: 'OAuth authorization failed',
    LocaleKeys.providersFetchModels: 'Fetch Models',
    LocaleKeys.providersJsonConfig: 'JSON Config',
    LocaleKeys.providersFormatJson: 'Format JSON',
    LocaleKeys.providersSaveFailed: 'Failed to save custom provider',
    LocaleKeys.providersJsonError: 'JSON Error: @error',
    LocaleKeys.providersApiKeyRequired: 'Please enter API Key first',
    LocaleKeys.providersFetchSuccess: 'Successfully fetched @count models',
    LocaleKeys.providersFetchNoModels: 'No model IDs found in response',
    LocaleKeys.providersFetchFailed: 'Failed to fetch model list',
    LocaleKeys.providersConfigEdit: 'Edit provider config',

    // ── MCP Tab ──
    LocaleKeys.mcpAlreadyInstalled: 'Already Installed',
    LocaleKeys.mcpAlreadyInstalledDesc:
        '"@name" is already configured. Go to the Installed tab to manage it.',
    LocaleKeys.mcpGoToInstalled: 'Go to Installed',
    LocaleKeys.mcpConfigureTitle: 'Configure @name',
    LocaleKeys.mcpEnvVarsRequired:
        'This server requires the following environment variables:',
    LocaleKeys.mcpInstalledTab: 'Installed',
    LocaleKeys.mcpDiscoverTab: 'Discover',
    LocaleKeys.mcpRemoveTitle: 'Remove MCP Server',
    LocaleKeys.mcpRemoveConfirm: 'Remove "@name" from MCP servers?',

    // ── Agent Tab ──
    LocaleKeys.agentNewTitle: 'New Agent',
    LocaleKeys.agentCreate: 'Create',

    // ── Command Palette ──
    LocaleKeys.cmdSearchPlaceholder: 'Type a command...',

    // ── Git Notifications ──
    LocaleKeys.gitNoChangesDetected: 'No changes detected to generate message.',
    LocaleKeys.gitCommitFailed: 'Commit failed: @error',
    LocaleKeys.gitCommitError: 'Commit error: @error',
    LocaleKeys.gitStageFailed: 'Failed to stage changes: @error',
    LocaleKeys.gitDiscardFailed: 'Failed to discard changes: @error',
    LocaleKeys.providersProviderExists: 'Provider already exists',
    LocaleKeys.headers: 'Headers',
    LocaleKeys.disconnect: 'Disconnect',
    LocaleKeys.gitStagedSuccess: 'Successfully staged @file',
    LocaleKeys.gitDiscardedSuccess: 'Discarded changes for @file',
    LocaleKeys.gitStagedTitle: 'Staged',
    LocaleKeys.gitDiscardedTitle: 'Discarded',
    LocaleKeys.edFontSize: 'Font Size:',
    LocaleKeys.edFontFamily: 'Font Family:',
    LocaleKeys.edLayoutIndentation: 'Layout & Indentation',
    LocaleKeys.edTabSize: 'Tab Size:',
    LocaleKeys.ed2Spaces: '2 Spaces',
    LocaleKeys.ed4Spaces: '4 Spaces',
    LocaleKeys.edTheme: 'Theme',
    LocaleKeys.edLspDesc:
        'Enable or disable language servers for code diagnostics and completion in the editor.',
    LocaleKeys.lspInstalled: 'Installed',
    LocaleKeys.lspMissing: 'Missing',
    LocaleKeys.lspExecutable: 'Executable: @cmd',
    LocaleKeys.lspPathWarning: 'Warning: \'@cmd\' not found in PATH.',
    LocaleKeys.edWordWrap: 'Word Wrap',
    LocaleKeys.edEnableWordWrap: 'Enable Word Wrap',
    LocaleKeys.edDisableWordWrap: 'Disable Word Wrap',
    LocaleKeys.edSourceMode: 'Source Mode',
    LocaleKeys.edPreviewMode: 'Preview Mode',
    LocaleKeys.edZoomIn: 'Increase Font Size',
    LocaleKeys.edZoomOut: 'Decrease Font Size',
    LocaleKeys.edCopyAll: 'Copy All',
    LocaleKeys.edCopied: 'Copied',
    LocaleKeys.edFindPlaceholder: 'Search...',
    LocaleKeys.edFindNoResult: 'No results',
    LocaleKeys.edFindPrevious: 'Previous',
    LocaleKeys.edFindNext: 'Next',
    LocaleKeys.edCaseSensitive: 'Match Case',
    LocaleKeys.edRegex: 'Regex',
    LocaleKeys.edCloseSearch: 'Close Search',
    LocaleKeys.startExecution: 'Start Execution',
    LocaleKeys.makePlan: 'Make Plan',
    // ── TODO Panel ──
    LocaleKeys.termTodo: 'TODO',
    LocaleKeys.todoEmpty: 'No TODO markers found',
    LocaleKeys.todoScanning: 'Scanning for TODO markers…',
    LocaleKeys.todoScanError: 'TODO scan failed',
    LocaleKeys.todoRefresh: 'Refresh',
    LocaleKeys.todoSettings: 'Settings',
    LocaleKeys.todoKeywords: 'Keywords',
    LocaleKeys.todoCaseSensitive: 'Case Sensitive',
    LocaleKeys.todoAddKeyword: 'Add Keyword',
    LocaleKeys.todoExcludedFolders: 'Exclude Folders',
    LocaleKeys.todoAddExcludedFolder: 'Add Excluded Folder',

    // ── Mobile shell ──
    LocaleKeys.mobileAllSessions: 'All Sessions',
    LocaleKeys.mobileOpenSessions: 'Open Sessions',
    LocaleKeys.mobileClearAllSessions: 'Clear',
    LocaleKeys.mobileToggleLeftPanel: 'Toggle left panel',
    LocaleKeys.mobileToggleRightPanel: 'Toggle right panel',
    LocaleKeys.mobileDisplay: 'Display',
    LocaleKeys.mobileNoOpenSessions: 'No open sessions',
    LocaleKeys.mobileSelectProject: 'Select a project from the drawer',
    LocaleKeys.mobileNoActiveSessions: 'No active sessions',
    LocaleKeys.mobileCheckUpdates: 'Check for Updates',
    LocaleKeys.mobileUpToDate: 'You are on the latest version (@version)',
    LocaleKeys.mobileSseReconnecting:
        'Event stream disconnected — reconnecting…',
    LocaleKeys.mobileSseAuthFailed:
        'Authentication failed — check credentials in Settings',

    LocaleKeys.mobileSettings: 'Settings',
    LocaleKeys.vadSettingsTitle: 'Voice Settings',
    LocaleKeys.vadThreshold: 'Voice Detection Sensitivity',
    LocaleKeys.vadMinSilenceDuration: 'Min Silence Duration',
    LocaleKeys.vadMinSpeechDuration: 'Min Speech Duration',
    LocaleKeys.vadMaxSpeechDuration: 'Max Speech Duration',
    LocaleKeys.vadSpeechPadMs: 'Speech Pad Duration',
    LocaleKeys.vadResetDefault: 'Reset Defaults',
    LocaleKeys.voiceContinuousInput: 'Continuous Voice Input',
    LocaleKeys.voiceContinuousInputDesc:
        'When enabled, sending won\'t stop voice input — keep speaking continuously.',
    LocaleKeys.voiceAutoSend: 'Enable Auto-send',
    LocaleKeys.voiceAutoSendDesc:
        'During single-tap voice input, say the send command surrounded by punctuation (e.g. “content. send.”) to auto-send the preceding text.',
    LocaleKeys.voiceSendCommand: 'Send Command',
    LocaleKeys.voiceSendCommandHint: 'send',
    LocaleKeys.voiceVadParams: 'Voice Detection Parameters',
    LocaleKeys.vadThresholdDesc:
        'Sensitivity threshold for detecting speech (higher = stricter against noise)',
    LocaleKeys.vadMinSilenceDesc:
        'Silence longer than this ends the current utterance',
    LocaleKeys.vadMinSpeechDesc:
        'Speech shorter than this is treated as noise and filtered',
    LocaleKeys.vadMaxSpeechDesc:
        'Max duration of a single continuous speech segment',
    LocaleKeys.vadSpeechPadDesc:
        'Silence padding added before and after each speech segment',
    LocaleKeys.voiceRecognitionErrorTitle: 'Voice Recognition',
    LocaleKeys.voiceListening: 'Listening...',
    LocaleKeys.voiceReleaseCancel: 'Release to cancel',
    LocaleKeys.voiceReleaseInsert: 'Release to insert into input',
    LocaleKeys.voiceReleaseHint: 'Release: Send | ↑ Cancel | ↓ Insert',
    LocaleKeys.voiceMicPermissionDeniedPermanent:
        'Microphone permission denied. Opening system settings.',
    LocaleKeys.voiceMicPermissionDenied:
        'Microphone permission not granted. Voice input unavailable.',
    LocaleKeys.voiceMicPermissionRequestFailed:
        'Failed to request microphone permission',
    LocaleKeys.voiceTranscriptionError: 'Transcription service error',
    LocaleKeys.voiceRecordPermissionDenied: 'Recording permission not granted',
    LocaleKeys.voiceRecordStreamError: 'Audio stream error',
    LocaleKeys.voiceStartFailed: 'Failed to start voice recognition',
    LocaleKeys.mobileOpenCodeSection: 'OpenCode',
    LocaleKeys.mobileOpenCodeSettingsDesc: 'Server, providers, MCP',
    LocaleKeys.mobileCheckingUpdates: 'Checking for updates...',
    LocaleKeys.mobileAboutAppName: 'OpenCode Mobile',
    LocaleKeys.mobileAboutLegalese: 'Remote client for OpenCode server',
    LocaleKeys.mobileAboutDesc:
        'Connect to a remote opencode serve instance via HTTP, SSE, and PTY WebSocket.',
    LocaleKeys.mobileAboutVersion: 'OpenCode Mobile v@version',
    LocaleKeys.mobileHealth: 'Health',
    LocaleKeys.mobileServerConnection: 'Server Connection',
    LocaleKeys.mobileServerUrl: 'Server URL',
    LocaleKeys.mobileServerUrlRequired: 'Server URL is required',
    LocaleKeys.mobileConnectSidecar: 'Connect to Sidecar Server',
    LocaleKeys.mobileConnectServer: 'Connect to Server',
    LocaleKeys.mobileConnecting: 'Connecting…',
    LocaleKeys.mobileStatus: 'Status: @status',
    LocaleKeys.mobilePassword: 'Password',
    LocaleKeys.mobileNoProjects: 'No projects',
    LocaleKeys.mobileProjectsLoadFailed: 'Failed to load projects',
    LocaleKeys.mobileProjects: 'Projects',
    LocaleKeys.mobileHiddenProjects: 'Hidden projects',
    LocaleKeys.mobileHideProject: 'Hide project',
    LocaleKeys.mobileUnhideProject: 'Unhide',
    LocaleKeys.mobileNoKeywordsYet: 'No keywords yet',
    LocaleKeys.mobileNoSessions: 'No sessions',
    LocaleKeys.mobileNoMatchingSessions: 'No matching sessions',
    LocaleKeys.mobileJustNow: 'just now',
    LocaleKeys.mobileMinutesAgo: '@count m ago',
    LocaleKeys.mobileHoursAgo: '@count h ago',
    LocaleKeys.mobileDaysAgo: '@count d ago',
    LocaleKeys.mobileLoginProviders: 'Login / Providers',
    LocaleKeys.mobileKeywords: 'Keywords',
    LocaleKeys.mobileKeywordDetection: 'Keyword Detection',
    LocaleKeys.mobileEnableKeywordDetection: 'Enable keyword detection',
    LocaleKeys.mobileAddKeywordHint: 'Add keyword...',
    LocaleKeys.mobilePhraseLabel: 'Label',
    LocaleKeys.mobilePhraseText: 'Phrase text...',
    LocaleKeys.mobileAttachFile: 'Attach file',
    LocaleKeys.mobileAttachImage: 'Attach image',
    LocaleKeys.mobileImageUnsupportedFormat: 'Unsupported image format (.@ext)',
    LocaleKeys.mobileImageHeicUnsupported:
        'HEIC/HEIF cannot be parsed, convert to JPG/PNG first',
    LocaleKeys.mobileImageDescribePrompt:
        'Please describe the images I sent you in detail.',
    LocaleKeys.mobileImageDescribing: 'Describing images…',
    LocaleKeys.mobileImageDescribeFailed: 'Failed to describe image',
    LocaleKeys.mobileImageToText: 'To text',
    LocaleKeys.mobileVisionSettings: 'Vision settings',
    LocaleKeys.aboutTitle: 'About & Open Source',
    LocaleKeys.releasePageTitle: 'Release Page',
    LocaleKeys.releasePageSubtitle: 'View latest updates on GitHub',
    LocaleKeys.openSourceLibrariesTitle: 'Open Source Libraries',
    LocaleKeys.openSourceLibrariesDesc:
        'Built with the following Flutter & Dart open-source packages:',
    LocaleKeys.viewFullLicenses: 'View All Open Source Licenses',
    LocaleKeys.mobileSelectVisionModel: 'Select vision model',
    LocaleKeys.mobileNoVisionModelsHint: 'No models available',
    LocaleKeys.mobileStopEsc: 'Stop (Esc)',
    LocaleKeys.mobileSendEnter: 'Send (Enter)',
    LocaleKeys.mobileRemoteTerminal: 'Remote terminal',
    LocaleKeys.mobileNoQuickPhrasesHint:
        'No quick phrases yet. Add some in Settings.',
    LocaleKeys.mobileAddProject: 'Add Project',
    LocaleKeys.mobileAddProjectFailed: 'Failed to add project. Check the path.',
    LocaleKeys.mobileServerPath: 'Server path',
    LocaleKeys.mobileBrowseFiles: 'Browse files',
    LocaleKeys.mobileFiles: 'Files',
    LocaleKeys.mobileIgnoredFile: 'Ignored',
    LocaleKeys.mobileEmptyDirectory: 'Empty directory',
    LocaleKeys.mobileSessions: 'Sessions',
    LocaleKeys.mobileDeleteSessionTitle: 'Delete session?',
    LocaleKeys.mobileDeleteSessionConfirm:
        'Delete "@name"? This cannot be undone.',
    LocaleKeys.mobileDeleteSessionFailed:
        'Failed to delete session. Check the connection and retry.',
    LocaleKeys.mobileSearchSessions: 'Search sessions...',
    LocaleKeys.mobileReconnect: 'Reconnect',
    LocaleKeys.mobileConnected: 'Connected',
    LocaleKeys.mobileUnreachable: 'Unreachable',
    LocaleKeys.mobileUnknown: 'Unknown',
    LocaleKeys.mobileTapRefresh: 'Tap refresh',
    LocaleKeys.mobileSaveAndReconnect: 'Save & Reconnect',
    LocaleKeys.mobileReconnecting: 'Reconnecting...',
    LocaleKeys.mobileConnectionFailed: 'Connection failed',
    LocaleKeys.mobileCancelConnection: 'Cancel Connection',
    LocaleKeys.mobileAutoConnecting: 'Auto-connecting to @url...',
    LocaleKeys.mobileMessageDensity: 'Message density',
    LocaleKeys.mobileCompact: 'Compact',
    LocaleKeys.mobileComfortable: 'Comfortable',
    LocaleKeys.mobileSpacious: 'Spacious',
    LocaleKeys.mobileCardVisibility: 'Card visibility',
    LocaleKeys.inputPanelsSection: 'Input Stack Panels',
    LocaleKeys.inputPanelTodo: 'Todo List Panel',
    LocaleKeys.inputPanelDiff: 'Changed Files Panel',
    LocaleKeys.mobileShowAll: 'Show all',
    LocaleKeys.mobileHideAll: 'Hide all',
    LocaleKeys.mobileNoDiff: 'No diff',
    LocaleKeys.mobileNoStepsYet: 'No steps yet',
    LocaleKeys.mobileNoSteps: 'No steps',
    LocaleKeys.mobileConnectWithApiKey: 'Connect with API Key',
    LocaleKeys.mobileRevert: 'Revert',
    LocaleKeys.mobileLoadMore: 'Load more',
    LocaleKeys.mobileHeaderKey: 'Key',
    LocaleKeys.mobileHeaderValue: 'Value',
    LocaleKeys.mobileAddItem: 'Add item…',
    LocaleKeys.mobileIgnorePatterns: 'Ignore Patterns',
    LocaleKeys.mobilePlugins: 'Plugins',
    LocaleKeys.mobilePluginEntries: 'Plugin entries',
    LocaleKeys.mobileInstructionPaths: 'Instruction paths',
    LocaleKeys.mobileAttachments: 'Attachments',
    LocaleKeys.mobileAutoResizeImages: 'Auto resize images',
    LocaleKeys.mobileMaxWidth: 'Max width',
    LocaleKeys.mobileMaxHeight: 'Max height',
    LocaleKeys.mobileMaxBase64Bytes: 'Max base64 bytes',
    LocaleKeys.mobileEnableLsp: 'Enable LSP',
    LocaleKeys.mobileEnableLspDesc: 'Master switch for language servers.',
    LocaleKeys.mobileSavedPermissions: 'Saved Permissions',
    LocaleKeys.mobileDescription: 'Description',
    LocaleKeys.mobileModel: 'Model',
    LocaleKeys.mobileMode: 'Mode',
    LocaleKeys.mobileVariant: 'Variant',
    LocaleKeys.mobileTemperature: 'Temperature',
    LocaleKeys.mobileTopP: 'Top P',
    LocaleKeys.mobileMaxSteps: 'Max Steps',
    LocaleKeys.mobileSystemPrompt: 'System Prompt',
    LocaleKeys.mobileAgentNameRequired: 'Agent Name *',
    LocaleKeys.mobileEnableFormatters: 'Enable formatters',
    LocaleKeys.mobileFormatters: 'Formatters',
    LocaleKeys.mobileReferences: 'References (@count)',
    LocaleKeys.mobileCustomCommands: 'Custom Commands (@count)',
    LocaleKeys.mobileNameRequired: 'Name *',
    LocaleKeys.mobileTemplateRequired: 'Template *',
    LocaleKeys.mobileAgent: 'Agent',
    LocaleKeys.mobileSubtask: 'Subtask',
    LocaleKeys.mobileAddReference: 'Add Reference',
    LocaleKeys.mobileRefText: 'Text',
    LocaleKeys.mobileRefGit: 'Git',
    LocaleKeys.mobileRefPath: 'Path',
    LocaleKeys.mobileBranchOptional: 'Branch (optional)',
    LocaleKeys.mobileMcpTimeoutHint: 'e.g. 30000',
    LocaleKeys.mobileMcpTimeoutInvalid: 'mcp_timeout must be an integer',
    LocaleKeys.mobileInvalidNumber: 'Please enter a valid positive integer',
    LocaleKeys.mobileToolNameHint: 'tool name',
    LocaleKeys.mobilePrimaryToolsHint: 'Tools surfaced first in the agent UI.',
    LocaleKeys.mobileBatchToolDesc: 'Enable experimental batch tool execution.',
    LocaleKeys.mobileDisablePasteDesc: 'Skip summarizing pasted content.',
    LocaleKeys.mobileContinueLoopDesc: 'Keep running after a permission deny.',
    LocaleKeys.mobileOtelDesc: 'Emit experimental OpenTelemetry signals.',

    LocaleKeys.cardVisReasoning: 'Reasoning',
    LocaleKeys.cardVisThinking: 'Thinking',
    LocaleKeys.cardVisSearch: 'Search',
    LocaleKeys.cardVisRead: 'Read',
    LocaleKeys.cardVisBash: 'Bash',
    LocaleKeys.cardVisEdit: 'Edit',
    LocaleKeys.cardVisBatch: 'Batch / Patch',
    LocaleKeys.cardVisGlob: 'Glob',
    LocaleKeys.cardVisGrep: 'Grep',
    LocaleKeys.cardVisWeb: 'Web',
    LocaleKeys.cardVisQuestion: 'Question',
    LocaleKeys.cardVisTask: 'Task',
    LocaleKeys.cardVisSubtask: 'Subtask',
    LocaleKeys.cardVisSkill: 'Skill',
    LocaleKeys.cardVisFallback: 'Other tools',
    LocaleKeys.cardVisFile: 'File',
    LocaleKeys.cardVisAgent: 'Agent',
    LocaleKeys.cardVisDiff: 'Diff',

    // ── Terminal ──
    LocaleKeys.terminalSettings: 'Terminal Settings',
    LocaleKeys.terminalCurrentProjectOnly:
        'Show Current Project Terminals Only',
    LocaleKeys.terminalCurrentProjectOnlyDesc:
        'Enabled by default, only shows PTY terminals for the currently active project',
    LocaleKeys.terminalShowExtraKeys: 'Show Extra Keys Bar',
    LocaleKeys.terminalShowExtraKeysDesc:
        'Show ESC, Ctrl, Alt, and arrow keys bar at bottom of terminal',
    LocaleKeys.terminalShowQuickCommands: 'Show Quick Commands Bar',
    LocaleKeys.terminalShowQuickCommandsDesc:
        'Show custom shell command shortcuts bar at bottom of terminal',
    LocaleKeys.terminalCloseCurrent: 'Close Current Terminal',
    LocaleKeys.terminalConfirmClose:
        'Are you sure you want to close @title? Background process will be terminated.',
    LocaleKeys.terminalFetchingList: 'Fetching terminal list...',
    LocaleKeys.terminalNoRunning: 'No running terminals',
    LocaleKeys.terminalClickPlusToCreate:
        'Tap the + button at the top-right to create a terminal',
    LocaleKeys.terminalNew: 'New Terminal',
    LocaleKeys.terminalTitle: 'Terminal',
    LocaleKeys.terminalSessionEnded: 'Terminal session ended',
    LocaleKeys.terminalConnectionLost: 'Connection lost',
    LocaleKeys.terminalConnectionTimeout: 'Connection timeout',
    LocaleKeys.terminalDeleteFailed:
        'Failed to delete remote terminal, it may still be running',
    LocaleKeys.terminalCommandLabel: 'Command',
    LocaleKeys.terminalCommandRequired: 'Enter a command',
    LocaleKeys.terminalNeedSession: 'Create and connect a terminal first',

    // ── Tablet tool panel ──
    LocaleKeys.tabletCodeTab: 'Code',
    LocaleKeys.tabletTerminalTab: 'Terminal',
    LocaleKeys.tabletWebTab: 'Browser',
    LocaleKeys.tabletReviewTab: 'Review',
    LocaleKeys.tabletToggleToolPanel: 'Tool Panel',
    LocaleKeys.tabletNoFileOpen: 'No file open',
    LocaleKeys.tabletEnterUrl: 'Enter URL',
    LocaleKeys.reviewTypeMessage: 'Message',
    LocaleKeys.reviewTypeSession: 'Session',
    LocaleKeys.reviewTypeAll: 'All',
    LocaleKeys.reviewLoadFailed: 'Failed to load',
    LocaleKeys.reviewEmptyHint:
        'Tap a message change card or session changed-files panel to view its diff, or use the top-right button to see all changes',
    LocaleKeys.reviewShowChangesOnly: 'Show changes only',
    LocaleKeys.reviewShowFull: 'Show full diff',
    LocaleKeys.reviewPrevChange: 'Previous change',
    LocaleKeys.reviewNextChange: 'Next change',
    LocaleKeys.reviewPrevFile: 'Previous file',
    LocaleKeys.reviewNextFile: 'Next file',

    // ── Session extra ──
    LocaleKeys.sessionWaitGenerationFinish: 'Wait for generation to finish',
    LocaleKeys.sessionForkFailed: 'Fork failed',
    LocaleKeys.sessionRevertFailed: 'Revert failed',
    LocaleKeys.retryLimited: 'Request limited, retrying.',
    LocaleKeys.retryLimitedReason: 'Request limited, retrying: @reason',

    // ── MCP extra ──
    LocaleKeys.mcpAuthTitle: 'OAuth Authorization',
    LocaleKeys.mcpAuthDesc:
        'Complete auth in your browser, then paste the "code" from the redirect URL below.',
    LocaleKeys.mcpAuthCodeLabel: 'Authorization Code',
    LocaleKeys.mcpRemoveAuthTitle: 'Remove OAuth',
    LocaleKeys.mcpRemoveAuthConfirm:
        'Remove stored OAuth credentials for @name?',
    LocaleKeys.mcpLocal: 'Local',
    LocaleKeys.mcpRemote: 'Remote',
    LocaleKeys.mcpNameRequired: 'Name is required',
    LocaleKeys.mcpNameExists: 'MCP server "@name" already exists',
    LocaleKeys.mcpUrlRequired: 'URL is required',
    LocaleKeys.mcpCommandRequired: 'Command is required',
    LocaleKeys.mcpAddFailed: 'Failed to add MCP',
    LocaleKeys.mcpAuthSuccess: '@name authenticated',
    LocaleKeys.mcpAuthFailed: 'MCP auth @name failed',
    LocaleKeys.mcpRemoveAuthSuccess: 'Auth removed for @name',

    // ── Developer extra ──
    LocaleKeys.developerEditCommand: 'Edit Command',
    LocaleKeys.developerNewCommand: 'New Command',
    LocaleKeys.developerRefNameExists: 'Reference name already exists',

    // ── Permissions extra ──
    LocaleKeys.permissionsReplaceConfirm:
        'Replace path-based rules for "@tool" with "@value"?',

    // ── Quick Phrases extra ──
    LocaleKeys.quickPhrasesDeleteTitle: 'Delete Quick Command',
    LocaleKeys.quickPhrasesDeleteConfirm: 'Delete "@name"?',

    // ── Settings extra ──
    LocaleKeys.generalSaveUsernameFailed: 'Failed to save username',
    LocaleKeys.modelsUpdateVisibilityFailed:
        'Failed to update model visibility',
    LocaleKeys.connectionValidUrlRequired: 'Enter a valid http(s) URL',
    LocaleKeys.connectionReconnected: 'Reconnected successfully',
    LocaleKeys.connectionRefreshFailed: 'Connected, but data refresh failed',
    LocaleKeys.connectionReconnectFailed: 'Failed to reconnect',

    // ── Browser ──
    LocaleKeys.browserBack: 'Back',
    LocaleKeys.browserForward: 'Forward',
    LocaleKeys.browserRefresh: 'Reload',
    LocaleKeys.browserSwitchMobile: 'Switch to mobile view',
    LocaleKeys.browserSwitchDesktop: 'Switch to desktop view',
    LocaleKeys.browserOpenExternal: 'Open in external browser',
    LocaleKeys.browserLoadFailed: 'Failed to load webpage',
    LocaleKeys.browserNewTab: 'New tab',
    LocaleKeys.browserCloseTab: 'Close tab',
    LocaleKeys.browserCollapseToolbar: 'Collapse toolbar',
    LocaleKeys.browserExpandToolbar: 'Expand toolbar',
    LocaleKeys.browserCloseSheet: 'Close browser',
    LocaleKeys.browserScreenshot: 'Screenshot',
    LocaleKeys.browserScreenshotAdded: 'Screenshot added to current session',
    LocaleKeys.browserScreenshotFailed: 'Screenshot failed. Please retry',
    LocaleKeys.browserScreenshotFailedReason: 'Screenshot failed: {reason}',
    LocaleKeys.browserScreenshotNoSession:
        'Failed to create a session. Please retry later',
    // ── Preview Port ──
    LocaleKeys.previewBindTitle: 'Bind preview port',
    LocaleKeys.previewPortHint: 'Port (1-65535)',
    LocaleKeys.previewPortInvalid:
        'Invalid port. Enter a number between 1 and 65535',
    LocaleKeys.previewPortClear: 'Clear binding',
    LocaleKeys.previewBindPreview: 'Preview URL:',
    // ── Terminal Extra ──
    LocaleKeys.terminalSentToNewSession: 'Sent to new AI session',
    LocaleKeys.terminalSentToSession: 'Sent to @name',
    LocaleKeys.terminalSelectSession: 'Select AI session to send to',
    LocaleKeys.terminalNoResults: 'No results found',
    // ── Left Drawer Extra ──
    LocaleKeys.drawerBackToProjects: 'Back to projects',
    LocaleKeys.drawerBrowseFiles: 'Browse file tree',
    LocaleKeys.drawerBackToProjectsDesc: 'View & switch projects',
    LocaleKeys.drawerBrowseFilesDesc: 'View project files',
    // ── Quick Phrases Extra ──
    LocaleKeys.quickPhrasesEnterName: 'Please enter command name',
    LocaleKeys.quickPhrasesNameExists: 'Command name already exists',
    LocaleKeys.quickPhrasesEnterTemplate:
        'Please enter command content/template',
    // ── Voice Extra ──
    LocaleKeys.voiceDownloadModelTitle: 'Download ASR Model',
    LocaleKeys.voiceDownloadFailed: 'Download Failed',
    LocaleKeys.voicePreparingDownload: 'Preparing download...',
    LocaleKeys.voiceDownloadPrompt: 'Downloading ASR model for first time use:',
    LocaleKeys.voiceCancelDownload: 'Cancel Download',
    LocaleKeys.selectFileFromSidebar: 'Select a file from sidebar',
    LocaleKeys.selectFileFromLeftMenu: 'Select a file from left menu',
    // ── Search ──
    LocaleKeys.searchPlaceholder: 'Search files or content...',
    LocaleKeys.searchFiles: 'Files',
    LocaleKeys.searchText: 'Code',
    LocaleKeys.searchFilesPlaceholder: 'Search files...',
    LocaleKeys.searchTextPlaceholder: 'Search code...',
    LocaleKeys.searchNoResults: 'No matches found',
    LocaleKeys.searchLoading: 'Searching...',
    // ── VCS / Git ──
    LocaleKeys.vcsBranch: 'Git Branch & Status',
    LocaleKeys.vcsStatus: 'Workspace Status',
    LocaleKeys.vcsDefault: 'Default',
    LocaleKeys.vcsClean: 'Working tree clean, no uncommitted changes',
    LocaleKeys.vcsModified: 'Modified',
    LocaleKeys.vcsAdded: 'Added',
    LocaleKeys.vcsDeleted: 'Deleted',
    LocaleKeys.vcsUntracked: 'Untracked',
    LocaleKeys.vcsViewDiff: 'View Full Diff',
    LocaleKeys.vcsNotGitRepo: 'Not a Git repository or no VCS info',
    LocaleKeys.vcsLoading: 'Fetching Git status...',
    LocaleKeys.vcsChangedFiles: '@count changed files',
    LocaleKeys.vcsBranchCopied: 'Branch name copied',
  };
}

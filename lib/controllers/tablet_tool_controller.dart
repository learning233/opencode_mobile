import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../init.dart';
import '../models/browser_tab.dart';
import '../models/opened_file.dart';
import '../utils/url_utils.dart';

class FileLineJumpRequest {
  final String path;
  final String? worktree;
  final int line;
  final int timestamp;

  const FileLineJumpRequest({
    required this.path,
    this.worktree,
    required this.line,
    required this.timestamp,
  });
}

/// Controls the tool panel state in tablet/desktop and code editor mode.
/// Manages opened file tabs, active tab index, visibility, and panel width.
class TabletToolController extends GetxController {
  // ── Tab indices ──
  static const int tabCode = 0;
  static const int tabTerminal = 1;
  static const int tabWeb = 2;
  static const int tabReview = 3;

  // ── Review scope types ──
  static const String reviewTypeMessage = 'message';
  static const String reviewTypeSession = 'session';
  static const String reviewTypeAll = 'all';

  // ── Observable state ──
  final activeTabIndex = tabCode.obs;
  final isVisible = true.obs;
  final panelWidthFraction = 0.5.obs; // fraction of screen width

  // Code editor settings
  final isWordWrap = false.obs;

  // ── Opened files state (Multi-Tab) ──
  final openedFiles = <OpenedFile>[].obs;

  /// Path of the active tab (backward-compatible; ambiguous across worktrees).
  /// Use [activeFileKey] to disambiguate when the same relative path is open
  /// from two different worktrees.
  final activeFilePath = ''.obs;

  /// Worktree of the active tab, paired with [activeFilePath].
  final activeFileWorktree = Rxn<String>();

  /// Request signal for jumping to a specific line in a file tab.
  /// Uses a distinct timestamp so duplicate line requests trigger reactively.
  final fileLineJumpRequest = Rxn<FileLineJumpRequest>();

  /// Stable identity of a file tab: worktree + path, so same-relative-path
  /// files from different projects are distinct tabs (never merged).
  static String fileKey(String path, String? worktree) =>
      worktree == null ? path : '$worktree\u0000$path';

  /// Key of the active tab.
  String get activeFileKey =>
      fileKey(activeFilePath.value, activeFileWorktree.value);

  /// Per-path cache of file contents loaded by editors. Stored separately from
  /// [openedFiles] so writing the cache does not mutate the Rx list (which would
  /// trigger an Obx rebuild of every tab). Read by `FileEditorPage.initState`
  /// when the tab is (re)created lazily so it can skip re-downloading.
  final Map<String, String> _contentCache = {};

  /// Bumped by `SessionController` when a `file.edited` / `file.watcher.updated`
  /// SSE event arrives for the current worktree. Consumers (file tree cache,
  /// opened editor) listen and invalidate/refresh, debounced.
  final fileChangeTick = 0.obs;

  /// Raw `file` path of the most recent file-change SSE event (empty until the
  /// first event). Editors match against their own path to decide whether to
  /// reload.
  final lastChangedFile = ''.obs;

  // Backward compatibility getters
  String get currentFilePath => activeFilePath.value;
  OpenedFile? get activeFile {
    if (activeFilePath.value.isEmpty) return null;
    final key = activeFileKey;
    final idx = openedFiles.indexWhere(
      (f) => fileKey(f.path, f.worktree) == key,
    );
    return idx != -1 ? openedFiles[idx] : null;
  }

  // Web tab state (Multi-Tab browser)
  final browserTabs = <BrowserTab>[].obs;
  final activeBrowserTabIndex = 0.obs;

  /// Phone-layout browser sheet visibility. Kept in the controller so the
  /// persistent `InAppBrowserView` layer in HomePage can show/hide it without
  /// being destroyed (WebView state survives close).
  final browserSheetVisible = false.obs;

  /// Bumped to force-reload the active browser tab's WebView (e.g. the preview
  /// button re-tapped on an already-open tab refreshes the page).
  final browserReloadTick = 0.obs;
  static int _browserTabIdSeq = 0;

  /// Stable identity for a browser tab.
  static String nextBrowserTabId() => 'browser_tab_${_browserTabIdSeq++}';

  // ── Review tab state ──
  /// Current review scope: [reviewTypeMessage] / [reviewTypeSession] / [reviewTypeAll].
  final reviewType = ''.obs;
  final reviewSessionId = ''.obs;
  final reviewMessageId = ''.obs;

  /// The file currently selected in the Review tab. Written by both the
  /// right-side tab switching (via `ReviewPage`) and the left-side file lists
  /// (message diff cards / session changed-files panel) so the two panes stay
  /// in sync. Empty means "no specific file selected yet".
  final reviewSelectedFile = ''.obs;

  /// Bumped whenever the Review tab must (re)load its data from the network.
  /// `ReviewPage` watches this instead of the scope fields so that re-opening
  /// the *same* scope (e.g. tapping a message card summary again) still
  /// refetches instead of being a no-op.
  final reviewReloadTick = 0.obs;

  /// Whether the Review tab renders only changed lines instead of the full diff.
  final showChangesOnly = false.obs;

  // ── Constraints ──
  static const double minWidthFraction = 0.2;
  static const double maxWidthFraction = 0.7;

  static const String _prefKeyVisible = 'tablet_tool_visible';
  static const String _prefKeyWidth = 'tablet_tool_width_fraction';
  static const String _prefKeyReviewShowChangesOnly =
      'tablet_review_show_changes_only';

  SharedPreferences? _prefs;
  Future<void>? _saveChain;

  @override
  void onInit() {
    super.onInit();
    isWordWrap.value = Global.settings.editorWordWrap;
    ever(isWordWrap, (v) => Global.settings.setEditorWordWrap(v));
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    isVisible.value = prefs.getBool(_prefKeyVisible) ?? true;
    panelWidthFraction.value = prefs.getDouble(_prefKeyWidth) ?? 0.5;
    showChangesOnly.value =
        prefs.getBool(_prefKeyReviewShowChangesOnly) ?? false;
  }

  Future<void> _savePrefs() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    // 串行化写入，避免高频 toggle/拖拽时多次 set 乱序互相覆盖。
    final next = _saveChain ?? Future.value();
    _saveChain = next.then((_) async {
      await prefs.setBool(_prefKeyVisible, isVisible.value);
      await prefs.setDouble(_prefKeyWidth, panelWidthFraction.value);
      await prefs.setBool(_prefKeyReviewShowChangesOnly, showChangesOnly.value);
    });
    await _saveChain;
  }

  /// Toggle panel visibility
  void togglePanel() {
    isVisible.value = !isVisible.value;
    unawaited(_savePrefs());
  }

  /// Adjust panel width by a delta (in pixels).
  void adjustWidth(double dx, double screenWidth) {
    if (screenWidth <= 0) return;
    // 保证左侧聊天面板最小固定留出 350px 宽度
    final maxAllowedFraction = (1.0 - 350.0 / screenWidth).clamp(
      minWidthFraction,
      maxWidthFraction,
    );
    final newFraction = (panelWidthFraction.value - dx / screenWidth).clamp(
      minWidthFraction,
      maxAllowedFraction,
    );
    panelWidthFraction.value = newFraction;
  }

  /// Call when drag ends to persist the width.
  void commitWidth() {
    unawaited(_savePrefs());
  }

  /// Get the actual pixel width for a given screen width.
  double getPixelWidth(double screenWidth) {
    // 保证左侧聊天面板最小固定留出 350px 宽度
    final maxAllowedFraction = (1.0 - 350.0 / screenWidth).clamp(
      minWidthFraction,
      maxWidthFraction,
    );
    final clampedFraction = panelWidthFraction.value.clamp(
      minWidthFraction,
      maxAllowedFraction,
    );
    return screenWidth * clampedFraction;
  }

  // ── Multi-Tab File Actions ──

  void _activate(int idx) {
    activeFilePath.value = openedFiles[idx].path;
    activeFileWorktree.value = openedFiles[idx].worktree;
  }

  /// Open a file in the Code tab. If already open (same worktree+path), switch
  /// to its tab; a same-relative-path file from another worktree is a distinct
  /// tab.
  void openFile(
    String path,
    String name, {
    String? worktree,
    String? content,
    int? targetLine,
  }) {
    if (path.isEmpty) return;

    final existingIdx = openedFiles.indexWhere(
      (f) => f.path == path && f.worktree == worktree,
    );
    if (existingIdx != -1) {
      openedFiles[existingIdx].targetLine = targetLine;
      _activate(existingIdx);
    } else {
      openedFiles.add(
        OpenedFile(
          path: path,
          name: name,
          worktree: worktree,
          initialContent: content,
          targetLine: targetLine,
        ),
      );
      _activate(openedFiles.length - 1);
    }

    if (targetLine != null) {
      fileLineJumpRequest.value = FileLineJumpRequest(
        path: path,
        worktree: worktree,
        line: targetLine,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      );
    } else {
      fileLineJumpRequest.value = null;
    }

    activeTabIndex.value = tabCode;
    if (!isVisible.value) isVisible.value = true;
  }

  /// Return the cached content for [path], or null when never loaded.
  /// Keyed by worktree+path so same-relative-path files stay distinct.
  String? cachedContent(String path, {String? worktree}) =>
      _contentCache[fileKey(path, worktree)];

  /// Write loaded file content into the cache so a later editor State
  /// re-creation (IndexedStack lazy build / word-wrap toggle / tab switch)
  /// renders from cache instead of re-downloading. Does not touch [openedFiles].
  void cacheFileContent(String path, String content, {String? worktree}) {
    _contentCache[fileKey(path, worktree)] = content;
  }

  /// Drop the cached content of a path so the next time its tab is (re)created
  /// it re-downloads instead of showing stale cached text. Called on file-change
  /// SSE events so a lazily-built tab never displays out-of-date content.
  void invalidateFileContent(String path, {String? worktree}) {
    _contentCache.remove(fileKey(path, worktree));
  }

  /// Select an already opened file tab. When [worktree] is null, matches the
  /// first tab with [path] (backward-compatible single-worktree behavior).
  void selectFile(String path, {String? worktree}) {
    final idx = openedFiles.indexWhere(
      (f) => f.path == path && (worktree == null || f.worktree == worktree),
    );
    if (idx == -1) return;
    _activate(idx);
    fileLineJumpRequest.value = null;
    activeTabIndex.value = tabCode;
  }

  /// Close a specific file tab. When [worktree] is null, closes the first tab
  /// with [path] (backward-compatible single-worktree behavior).
  void closeFile(String path, {String? worktree}) {
    final idx = openedFiles.indexWhere(
      (f) => f.path == path && (worktree == null || f.worktree == worktree),
    );
    if (idx == -1) return;

    fileLineJumpRequest.value = null;
    final tab = openedFiles[idx];
    openedFiles.removeAt(idx);
    _contentCache.remove(fileKey(tab.path, tab.worktree));

    if (activeFileKey == fileKey(tab.path, tab.worktree)) {
      if (openedFiles.isEmpty) {
        activeFilePath.value = '';
        activeFileWorktree.value = null;
      } else {
        final newIdx = idx.clamp(0, openedFiles.length - 1);
        _activate(newIdx);
      }
    }
  }

  /// Close all opened file tabs.
  void closeAllFiles() {
    fileLineJumpRequest.value = null;
    openedFiles.clear();
    _contentCache.clear();
    activeFilePath.value = '';
    activeFileWorktree.value = null;
  }

  /// Close all files except the specified worktree+path.
  void closeOtherFiles(String path, {String? worktree}) {
    fileLineJumpRequest.value = null;
    openedFiles.removeWhere(
      (f) => f.path != path || (worktree != null && f.worktree != worktree),
    );
    _contentCache.removeWhere((key, _) => key != fileKey(path, worktree));
    if (openedFiles.isNotEmpty) {
      _activate(0);
    } else {
      activeFilePath.value = '';
      activeFileWorktree.value = null;
    }
  }

  /// Open a URL in the Web tab's multi-tab browser.
  ///
  /// - Empty [url]: just switch to the Web tab (does not create a tab), so the
  ///   preview button keeps its "show existing browser" behavior.
  /// - Non-empty [url]: if a tab already shows the same normalized URL, switch
  ///   to that tab; otherwise open a new tab with it. Then focus the Web tab.
  /// - [reloadIfOpen]: when the URL is already open, reload that tab's page
  ///   (used by the preview button to refresh the preview instead of
  ///   duplicating the tab).
  void openUrl(String url, {bool reloadIfOpen = false}) {
    final normalized = normalizeWebUrl(url);
    if (normalized.isNotEmpty) {
      // 入库 URL 均已规范化；用斜杠无关比较键，`host:port` 与 `host:port/` 视为同一标签。
      final key = webUrlDedupKey(normalized);
      final existingIdx = browserTabs.indexWhere(
        (t) => webUrlDedupKey(t.url) == key,
      );
      if (existingIdx != -1) {
        activeBrowserTabIndex.value = existingIdx;
        if (reloadIfOpen) browserReloadTick.value++;
      } else {
        browserTabs.add(BrowserTab(id: nextBrowserTabId(), url: normalized));
        activeBrowserTabIndex.value = browserTabs.length - 1;
      }
    }
    activeTabIndex.value = tabWeb;
    if (!isVisible.value) isVisible.value = true;
  }

  /// Open a new blank tab and focus it.
  void newBrowserTab() {
    browserTabs.add(BrowserTab(id: nextBrowserTabId(), url: ''));
    activeBrowserTabIndex.value = browserTabs.length - 1;
  }

  /// Show the phone-layout browser sheet (the persistent [InAppBrowserView]
  /// layer in HomePage slides up). Does not recreate the WebView.
  void openBrowserSheet() {
    browserSheetVisible.value = true;
  }

  /// Hide the phone-layout browser sheet. The WebView stays alive so the next
  /// open resumes the same page state.
  void closeBrowserSheet() {
    browserSheetVisible.value = false;
  }

  /// Switch to the browser tab at [index].
  void switchBrowserTab(int index) {
    if (index < 0 || index >= browserTabs.length) return;
    activeBrowserTabIndex.value = index;
  }

  /// Close the browser tab at [index], fixing the active index like file tabs.
  void closeBrowserTab(int index) {
    if (index < 0 || index >= browserTabs.length) return;
    final activeIdx = activeBrowserTabIndex.value;
    browserTabs.removeAt(index);
    if (browserTabs.isEmpty) {
      activeBrowserTabIndex.value = 0;
      return;
    }
    if (activeIdx == index) {
      activeBrowserTabIndex.value = index.clamp(0, browserTabs.length - 1);
    } else if (activeIdx > index) {
      activeBrowserTabIndex.value = activeIdx - 1;
    }
  }

  /// Update the URL of the browser tab at [index] (e.g. after navigation).
  void updateBrowserTabUrl(int index, String url) {
    if (index < 0 || index >= browserTabs.length) return;
    final normalized = normalizeWebUrl(url);
    if (normalized.isEmpty) return;
    final tab = browserTabs[index];
    if (tab.url == normalized) return;
    browserTabs[index] = tab.copyWith(url: normalized);
  }

  /// Update the page title of the browser tab at [index] (from `<title>`).
  void updateBrowserTabTitle(int index, String title) {
    if (index < 0 || index >= browserTabs.length) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final tab = browserTabs[index];
    if (tab.title == trimmed) return;
    browserTabs[index] = tab.copyWith(title: trimmed);
  }

  /// Toggle desktop mode for the browser tab at [index].
  void toggleBrowserTabDesktopMode(int index) {
    if (index < 0 || index >= browserTabs.length) return;
    final tab = browserTabs[index];
    browserTabs[index] = tab.copyWith(isDesktopMode: !tab.isDesktopMode);
  }

  /// Switch to the Terminal tab.
  void focusTerminal() {
    activeTabIndex.value = tabTerminal;
    if (!isVisible.value) isVisible.value = true;
  }

  // ── Review tab actions ──

  /// Open the Review tab scoped to a single message's diff.
  /// Always refetches, even when the scope is unchanged.
  void openReviewMessage(
    String sessionId,
    String userMessageId, {
    String? selectFile,
  }) {
    reviewType.value = reviewTypeMessage;
    reviewSessionId.value = sessionId;
    reviewMessageId.value = userMessageId;
    reviewSelectedFile.value = selectFile ?? '';
    reviewReloadTick.value++;
    activeTabIndex.value = tabReview;
    if (!isVisible.value) isVisible.value = true;
  }

  /// File tap from a message diff card: if the Review tab is already scoped to
  /// this message, just switch the file tab locally (no network request).
  /// Otherwise open the message scope and preselect the file.
  /// 同 scope 时也切到 Review tab（若当前不在）并确保面板可见。
  void openReviewMessageFile(
    String sessionId,
    String userMessageId, {
    required String selectFile,
  }) {
    final isSameScope =
        reviewType.value == reviewTypeMessage &&
        reviewSessionId.value == sessionId &&
        reviewMessageId.value == userMessageId;
    if (isSameScope) {
      reviewSelectedFile.value = selectFile;
      activeTabIndex.value = tabReview;
      if (!isVisible.value) isVisible.value = true;
    } else {
      openReviewMessage(sessionId, userMessageId, selectFile: selectFile);
    }
  }

  /// Open the Review tab scoped to the current session's changed files.
  /// Always refetches, even when the scope is unchanged.
  /// [switchTab] 为 false 时只刷新 Review 数据，不把当前 tab 切到 Review
  /// （切换 session 后台预热用）；其余调用保持默认的切 tab 行为。
  void openReviewSession(
    String sessionId, {
    String? selectFile,
    bool switchTab = true,
  }) {
    reviewType.value = reviewTypeSession;
    reviewSessionId.value = sessionId;
    reviewMessageId.value = '';
    reviewSelectedFile.value = selectFile ?? '';
    reviewReloadTick.value++;
    if (switchTab) {
      activeTabIndex.value = tabReview;
      if (!isVisible.value) isVisible.value = true;
    }
  }

  /// File tap from the session changed-files panel: if the Review tab is
  /// already scoped to this session, just switch the file tab locally.
  /// Otherwise open the session scope and preselect the file.
  /// 同 scope 时也切到 Review tab（若当前不在）并确保面板可见。
  void openReviewSessionFile(String sessionId, {required String selectFile}) {
    final isSameScope =
        reviewType.value == reviewTypeSession &&
        reviewSessionId.value == sessionId;
    if (isSameScope) {
      reviewSelectedFile.value = selectFile;
      activeTabIndex.value = tabReview;
      if (!isVisible.value) isVisible.value = true;
    } else {
      openReviewSession(sessionId, selectFile: selectFile);
    }
  }

  /// Switch the Review tab to show all workspace changes.
  void setReviewAll() {
    reviewType.value = reviewTypeAll;
    reviewReloadTick.value++;
  }

  /// Toggle between full diff and changes-only rendering in the Review tab.
  void toggleReviewShowChangesOnly() {
    showChangesOnly.value = !showChangesOnly.value;
    unawaited(_savePrefs());
  }
}

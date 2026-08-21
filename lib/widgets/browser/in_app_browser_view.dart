import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../models/browser_tab.dart';
import '../../utils/app_logger.dart';
import '../../utils/layout_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/translations.dart';
import '../../utils/url_utils.dart';

const String _kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Open a URL in the in-app multi-tab browser.
///
/// - Tablet layout: record the tab in [TabletToolController] and focus the Web tab.
/// - Phone layout: same shared tab state, then show the persistent browser sheet
///   (slides up; WebView state survives closing).
/// - [reloadIfOpen]: when a tab already shows [url], reload it instead of
///   leaving it untouched (preview button refreshes the already-open page).
void openUrlInApp(BuildContext context, String url, {bool reloadIfOpen = false}) {
  Get.find<TabletToolController>().openUrl(url, reloadIfOpen: reloadIfOpen);
  if (!isTabletLayout(context)) {
    Get.find<TabletToolController>().openBrowserSheet();
  }
}

/// In-app multi-tab WebView browser (Chrome-style tab strip) for loading and
/// navigating websites, primarily to preview AI-modified frontend code/tests.
class InAppBrowserView extends StatefulWidget {
  /// Optional close callback. When non-null (phone-layout persistent sheet),
  /// a close button is shown in the tab bar. Null keeps the tablet layout
  /// unchanged (no close button, panel hidden via its own toggle).
  final VoidCallback? onClose;

  const InAppBrowserView({super.key, this.onClose});

  @override
  State<InAppBrowserView> createState() => _InAppBrowserViewState();
}

class _NavState {
  final String url;
  final String title;
  final bool isLoading;
  final int loadingProgress;
  final bool canGoBack;
  final bool canGoForward;
  final String? errorMessage;

  const _NavState({
    this.url = '',
    this.title = '',
    this.isLoading = false,
    this.loadingProgress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.errorMessage,
  });
}

class _InAppBrowserViewState extends State<InAppBrowserView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _urlTextController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final Map<String, GlobalKey<_BrowserTabViewState>> _tabKeys = {};
  final Map<String, _NavState> _navStates = {};
  final List<Worker> _workers = [];
  bool _isToolbarCollapsed = false;

  @override
  bool get wantKeepAlive => true;

  TabletToolController get _toolCtrl => Get.find<TabletToolController>();

  BrowserTab? _activeTab() {
    final tabs = _toolCtrl.browserTabs;
    if (tabs.isEmpty) return null;
    final idx = _activeBrowserIndex();
    return tabs[idx];
  }

  /// Safe index of the active tab (0 when there are no tabs). Never throws,
  /// even when [TabletToolController.browserTabs] is empty.
  int _activeBrowserIndex() {
    final tabs = _toolCtrl.browserTabs;
    if (tabs.isEmpty) return 0;
    return _toolCtrl.activeBrowserTabIndex.value.clamp(0, tabs.length - 1);
  }

  _NavState _activeNavState() {
    final tab = _activeTab();
    if (tab == null) return const _NavState();
    return _navStates[tab.id] ?? const _NavState();
  }

  @override
  void initState() {
    super.initState();
    _urlTextController.text = _activeTab()?.url ?? '';
    _workers.addAll([
      ever(_toolCtrl.activeBrowserTabIndex, (_) => _syncUrlText()),
      ever(_toolCtrl.browserTabs, (_) => _syncUrlText()),
      // 预览按钮对已打开 URL 再次点击时刷新该页，而非新建标签。
      ever(_toolCtrl.browserReloadTick, (_) {
        if (!mounted) return;
        // 等待 active index 同步到目标标签后再刷新。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _activeTabState()?.reload();
        });
      }),
    ]);
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _urlTextController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  /// Keeps the address bar in sync with the active tab, but never clobbers
  /// the field while the user is typing into it.
  void _syncUrlText() {
    if (!mounted) return;
    if (_urlFocusNode.hasFocus) return;
    final tab = _activeTab();
    _urlTextController.text = tab?.url ?? '';
  }

  /// Called by each tab when its WebView navigation state changes.
  void _handleNavState(String tabId, _NavState s) {
    if (!mounted) return;
    _navStates[tabId] = s;
    if (_activeTab()?.id == tabId && !_urlFocusNode.hasFocus) {
      _urlTextController.text = s.url;
    }
    // Keep the model's URL in sync so re-opening the same URL dedupes to this tab.
    final idx = _toolCtrl.browserTabs.indexWhere((t) => t.id == tabId);
    if (idx != -1 && s.url.isNotEmpty) {
      _toolCtrl.updateBrowserTabUrl(idx, s.url);
    }
    // Keep the model's title in sync so the tab strip shows page titles.
    if (idx != -1 && s.title.isNotEmpty) {
      _toolCtrl.updateBrowserTabTitle(idx, s.title);
    }
    setState(() {});
  }

  _BrowserTabViewState? _activeTabState() {
    final tab = _activeTab();
    if (tab == null) return null;
    final key = _tabKeys[tab.id];
    return key?.currentState;
  }

  void _loadUrl(String rawUrl) {
    final normalized = normalizeWebUrl(rawUrl);
    if (normalized.isEmpty) return;
    final tab = _activeTab();
    if (tab == null) {
      // No tab yet: opening a URL creates one.
      _toolCtrl.openUrl(normalized);
      return;
    }
    _urlTextController.text = normalized;
    _activeTabState()?.loadUrl(normalized);
  }

  Future<void> _openExternalBrowser() async {
    final currentUrl = _urlTextController.text.trim();
    if (currentUrl.isEmpty) return;
    final uri = Uri.tryParse(currentUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _toggleDesktopMode() {
    final tab = _activeTab();
    if (tab == null) return;
    final idx = _toolCtrl.browserTabs.indexOf(tab);
    if (idx == -1) return;
    final nextMode = !tab.isDesktopMode;
    _toolCtrl.toggleBrowserTabDesktopMode(idx);
    _activeTabState()?.setDesktopMode(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildTabBar(theme),
        if (!_isToolbarCollapsed) _buildToolbar(theme),
        _buildProgress(theme),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Obx(() {
      final nav = _activeNavState();
      if (nav.isLoading && nav.loadingProgress < 100) {
        return LinearProgressIndicator(
          value: nav.loadingProgress / 100.0,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        );
      }
      if (_isToolbarCollapsed) return const SizedBox.shrink();
      return const Divider(height: 1);
    });
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 40,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          // 标签列表（可横向滚动）
          Expanded(
            child: Obx(() {
              final tabs = _toolCtrl.browserTabs;
              final activeIdx = _activeBrowserIndex();

              return ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(width: 6),
                  for (var i = 0; i < tabs.length; i++) ...[
                    _buildTabItem(theme, tabs[i], i == activeIdx, i),
                    const SizedBox(width: 4),
                  ],
                ],
              );
            }),
          ),
          // 右侧固定操作：新增标签 + 折叠/展开工具栏（不随标签增多移动）
          _buildNewTabButton(theme),
          Obx(() => _buildScreenshotButton(theme)),
          _buildCollapseToggleButton(theme),
          if (widget.onClose != null) _buildCloseButton(theme),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    ThemeData theme,
    BrowserTab tab,
    bool isActive,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => _toolCtrl.switchBrowserTab(index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _tabLabel(tab),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: LocaleKeys.browserCloseTab.tr,
                child: InkWell(
                  onTap: () => _toolCtrl.closeBrowserTab(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 12,
                      color: isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Short label for a tab: prefers the page title, falling back to the
  /// scheme-stripped URL. Blank tabs (new tab button) get "New tab".
  String _tabLabel(BrowserTab tab) {
    if (tab.url.isEmpty) return LocaleKeys.browserNewTab.tr;
    final title = tab.title.trim();
    if (title.isNotEmpty) {
      if (title.length <= 28) return title;
      return '${title.substring(0, 28)}…';
    }
    final stripped = tab.url.replaceFirst(RegExp(r'^https?://'), '');
    if (stripped.length <= 28) return stripped;
    return '${stripped.substring(0, 28)}…';
  }

  Widget _buildNewTabButton(ThemeData theme) {
    return IconButton(
      icon: const Icon(CupertinoIcons.plus, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      tooltip: LocaleKeys.browserNewTab.tr,
      onPressed: () {
        _toolCtrl.newBrowserTab();
        _urlTextController.clear();
      },
    );
  }

  /// 截图当前活动标签页，并把 PNG 图片追加到当前会话的输入草稿（不直接发送）。
  Widget _buildScreenshotButton(ThemeData theme) {
    return IconButton(
      icon: const Icon(CupertinoIcons.photo_camera, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      tooltip: LocaleKeys.browserScreenshot.tr,
      onPressed: _toolCtrl.browserTabs.isEmpty ? null : _captureScreenshot,
    );
  }

  Future<void> _captureScreenshot() async {
    final tab = _activeTabState();
    final bytes = await tab?.capture();
    if (bytes == null || bytes.isEmpty) {
      final reason = tab?.screenshotError;
      if (reason != null && reason.isNotEmpty) {
        AppLogger.e('browser screenshot failed: $reason');
      }
      Snack.error(
        reason == null || reason.isEmpty
            ? LocaleKeys.browserScreenshotFailed.tr
            : LocaleKeys.browserScreenshotFailedReason.trParams({
                'reason': reason,
              }),
      );
      return;
    }
    final ok = await Get.find<SessionController>()
        .attachScreenshotToActiveSession(bytes);
    if (ok) {
      Snack.success(LocaleKeys.browserScreenshotAdded.tr);
    } else {
      Snack.error(LocaleKeys.browserScreenshotNoSession.tr);
    }
  }

  /// Fixed right-edge toggle that collapses/expands the toolbar. Stays pinned
  /// so the user can always expand the toolbar without overlapping the page.
  Widget _buildCollapseToggleButton(ThemeData theme) {
    final collapsed = _isToolbarCollapsed;
    return IconButton(
      icon: Icon(
        collapsed
            ? CupertinoIcons.chevron_compact_down
            : CupertinoIcons.chevron_compact_up,
        size: 18,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      tooltip: collapsed
          ? LocaleKeys.browserExpandToolbar.tr
          : LocaleKeys.browserCollapseToolbar.tr,
      onPressed: () {
        setState(() {
          _isToolbarCollapsed = !_isToolbarCollapsed;
        });
      },
    );
  }

  /// Phone-layout close button: hides the persistent sheet without destroying
  /// the WebView (the layer stays alive, just slides down).
  Widget _buildCloseButton(ThemeData theme) {
    return IconButton(
      icon: const Icon(CupertinoIcons.xmark, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      tooltip: LocaleKeys.browserCloseSheet.tr,
      onPressed: widget.onClose,
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Obx(() {
        final nav = _activeNavState();
        final activeTab = _activeTab();

        return Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.chevron_back, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.browserBack.tr,
              onPressed: nav.canGoBack
                  ? () => _activeTabState()?.goBack()
                  : null,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.chevron_forward, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.browserForward.tr,
              onPressed: nav.canGoForward
                  ? () => _activeTabState()?.goForward()
                  : null,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.refresh, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.browserRefresh.tr,
              onPressed: () => _activeTabState()?.reload(),
            ),
            const SizedBox(width: 2),
            // URL input field
            Expanded(
              child: TextField(
                controller: _urlTextController,
                focusNode: _urlFocusNode,
                decoration: InputDecoration(
                  hintText: LocaleKeys.tabletEnterUrl.tr,
                  prefixIcon: const Icon(CupertinoIcons.globe, size: 14),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                style: const TextStyle(fontSize: 11.5),
                onSubmitted: (url) => _loadUrl(url),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(
                activeTab?.isDesktopMode == true
                    ? CupertinoIcons.desktopcomputer
                    : CupertinoIcons.device_phone_portrait,
                size: 15,
                color: activeTab?.isDesktopMode == true
                    ? theme.colorScheme.primary
                    : null,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: activeTab?.isDesktopMode == true
                  ? LocaleKeys.browserSwitchMobile.tr
                  : LocaleKeys.browserSwitchDesktop.tr,
              onPressed: _toggleDesktopMode,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.compass, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: LocaleKeys.browserOpenExternal.tr,
              onPressed: _openExternalBrowser,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Obx(() {
      final tabs = _toolCtrl.browserTabs;
      final activeIdx = _activeBrowserIndex();

      if (tabs.isEmpty) {
        _navStates.clear();
        return const _EmptyWebPlaceholder();
      }

      // Prune state/keys of closed tabs.
      final ids = {for (final t in tabs) t.id};
      _tabKeys.removeWhere((id, _) => !ids.contains(id));
      _navStates.removeWhere((id, _) => !ids.contains(id));

      return IndexedStack(
        index: activeIdx,
        children: [
          for (final tab in tabs)
            _BrowserTabView(
              key: _tabKeys.putIfAbsent(
                tab.id,
                () => GlobalKey<_BrowserTabViewState>(),
              ),
              tabId: tab.id,
              initialUrl: tab.url,
              initialDesktopMode: tab.isDesktopMode,
              onNavState: _handleNavState,
            ),
        ],
      );
    });
  }
}

/// A single browser tab owning its own WebViewController and navigation state.
class _BrowserTabView extends StatefulWidget {
  final String tabId;
  final String initialUrl;
  final bool initialDesktopMode;
  final void Function(String tabId, _NavState state) onNavState;

  const _BrowserTabView({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.initialDesktopMode,
    required this.onNavState,
  });

  @override
  State<_BrowserTabView> createState() => _BrowserTabViewState();
}

class _BrowserTabViewState extends State<_BrowserTabView>
    with AutomaticKeepAliveClientMixin {
  WebViewController? _controller;
  bool _isDesktopMode = false;
  bool _isLoading = false;
  int _loadingProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _errorMessage;
  String _currentUrl = '';
  String _currentTitle = '';
  Completer<Uint8List?>? _shotCompleter;
  String? _shotError;

  /// Reason for the last failed screenshot, for diagnostics/UI surfacing.
  String? get screenshotError => _shotError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isDesktopMode = widget.initialDesktopMode;
    final startUrl = normalizeWebUrl(widget.initialUrl);
    if (startUrl.isNotEmpty) {
      _controller = _createController()..loadRequest(Uri.parse(startUrl));
      _currentUrl = startUrl;
    }
  }

  WebViewController _createController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'BrowserScreenshotChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _onScreenshotMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
              _errorMessage = null;
              _currentUrl = url;
              _currentTitle = '';
            });
            _emit();
            _updateNavState();
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
            _emit();
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadingProgress = 100;
              _currentUrl = url;
              _errorMessage = null;
            });
            _emit();
            _updateNavState();
            _updateTitle();
          },
          onWebResourceError: (WebResourceError error) {
            // Ignore non-main-frame sub-resource errors (tracking scripts, ads).
            if (error.isForMainFrame ?? true) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
              _emit();
            }
          },
        ),
      );

    if (_isDesktopMode) {
      try {
        controller.setUserAgent(_kDesktopUserAgent);
      } catch (_) {}
    }

    return controller;
  }

  WebViewController _ensureController() {
    return _controller ??= _createController();
  }

  void _emit() {
    widget.onNavState(
      widget.tabId,
      _NavState(
        url: _currentUrl,
        title: _currentTitle,
        isLoading: _isLoading,
        loadingProgress: _loadingProgress,
        canGoBack: _canGoBack,
        canGoForward: _canGoForward,
        errorMessage: _errorMessage,
      ),
    );
  }

  Future<void> _updateTitle() async {
    final c = _controller;
    if (c == null) return;
    try {
      final title = await c.getTitle();
      if (!mounted) return;
      final trimmed = title?.trim() ?? '';
      if (trimmed.isEmpty) return;
      setState(() {
        _currentTitle = trimmed;
      });
      _emit();
    } catch (_) {}
  }

  Future<void> _updateNavState() async {
    final c = _controller;
    if (c == null) return;
    try {
      final back = await c.canGoBack();
      final forward = await c.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
      _emit();
    } catch (_) {}
  }

  void goBack() {
    try {
      _controller?.goBack();
    } catch (_) {}
  }

  void goForward() {
    try {
      _controller?.goForward();
    } catch (_) {}
  }

  void reload() {
    try {
      _controller?.reload();
    } catch (_) {}
  }

  void loadUrl(String rawUrl) {
    final normalized = normalizeWebUrl(rawUrl);
    if (normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    setState(() {
      _currentUrl = normalized;
    });
    try {
      _ensureController().loadRequest(uri);
    } catch (_) {}
  }

  /// Capture the current page as PNG bytes by rendering its DOM to a canvas
  /// (html-to-image) inside the WebView and receiving the result over the
  /// [JavaScriptChannel]. Returns null on failure or timeout; the reason is
  /// exposed via [screenshotError].
  Future<Uint8List?> capture() async {
    final c = _controller;
    _shotError = null;
    if (c == null) {
      _shotError = 'no webview controller';
      return null;
    }
    if (_shotCompleter != null) {
      _shotError = 'a capture is already in progress';
      return null;
    }
    try {
      final source = await _htmlToImageSource();
      final completer = _shotCompleter = Completer<Uint8List?>();
      await c.runJavaScript(
        'if (!window.__browserScreenshotReady) {'
        ' window.__browserScreenshotReady = true;\n$source;\n}'
        '\n$_browserScreenshotSnippet',
      );
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _shotError = 'JS timed out after 20s';
          return null;
        },
      );
    } catch (e) {
      _shotError = 'Dart error: $e';
      return null;
    } finally {
      _shotCompleter = null;
    }
  }

  void _onScreenshotMessage(String raw) {
    final completer = _shotCompleter;
    if (completer == null || completer.isCompleted) return;
    if (raw.startsWith('ERROR:')) {
      _shotError = raw.substring(6);
      completer.complete(null);
      return;
    }
    try {
      final payload = raw.contains(',')
          ? raw.substring(raw.indexOf(',') + 1)
          : raw;
      completer.complete(base64Decode(payload));
    } catch (e) {
      _shotError = 'base64 decode failed: $e';
      completer.complete(null);
    }
  }

  static String? _htmlToImageSourceCache;

  static Future<String> _htmlToImageSource() async {
    return _htmlToImageSourceCache ??= await rootBundle.loadString(
      'assets/browser/html-to-image.min.js',
    );
  }

  /// Renders the full page into a PNG data URL and posts it back on the
  /// [JavaScriptChannel]. Already-broken images are swapped for a transparent
  /// placeholder up front (html-to-image otherwise rejects with a raw `Event`
  /// from `img.onerror` when an image can never load). Errors are reported as
  /// `ERROR:<detail>` so Dart can surface a failure instead of silently
  /// dropping the capture.
  static const String _browserScreenshotSnippet = '''
;(async function () {
  function describe(e) {
    if (e && e.message) return String(e.message);
    if (e && e.target && e.target.tagName) {
      return 'event:' + (e.type || '') + ' <' + String(e.target.tagName).toLowerCase() + '> ' + (e.target.src || e.target.currentSrc || '');
    }
    return String(e);
  }
  var placeholder = 'data:image/gif;base64,R0lGODlhAQABAAAAACw=';
  try {
    var imgs = document.querySelectorAll('img');
    for (var k = 0; k < imgs.length; k++) {
      var img = imgs[k];
      if (/^data:/i.test(img.src)) continue;
      if (img.complete && img.naturalWidth === 0) {
        img.srcset = '';
        img.src = placeholder;
      }
    }
    var dataUrl = await htmlToImage.toPng(document.documentElement, {
      pixelRatio: 1,
      cacheBust: true,
      imagePlaceholder: placeholder
    });
    BrowserScreenshotChannel.postMessage(dataUrl);
  } catch (e) {
    try {
      var dataUrl2 = await htmlToImage.toPng(document.body, {
        pixelRatio: 1,
        cacheBust: true,
        imagePlaceholder: placeholder
      });
      BrowserScreenshotChannel.postMessage(dataUrl2);
    } catch (e2) {
      BrowserScreenshotChannel.postMessage('ERROR:' + describe(e2));
    }
  }
})();
''';

  Future<void> setDesktopMode(bool next) async {
    if (_isDesktopMode == next) return;
    setState(() {
      _isDesktopMode = next;
    });
    final c = _controller;
    if (c == null) return;
    try {
      if (next) {
        await c.setUserAgent(_kDesktopUserAgent);
      } else {
        await c.setUserAgent(null);
      }
      c.reload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Stack(
      children: [
        if (_controller != null)
          WebViewWidget(controller: _controller!)
        else
          const _EmptyWebPlaceholder(),
        if (_controller != null && _errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.browserLoadFailed.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: reload,
                    child: Text(LocaleKeys.retry.tr),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyWebPlaceholder extends StatelessWidget {
  const _EmptyWebPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.globe,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.tabletEnterUrl.tr,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

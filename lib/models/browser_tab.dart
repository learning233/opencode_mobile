/// A single tab of the in-app multi-tab browser.
class BrowserTab {
  /// Stable identity of the tab (survives URL changes / navigation).
  final String id;

  /// Current URL of the tab. Empty means the tab is blank (placeholder shown).
  final String url;

  /// Page `<title>` of the tab, if known. Empty means no title available yet.
  final String title;

  /// Whether this tab renders with the desktop user agent.
  final bool isDesktopMode;

  const BrowserTab({
    required this.id,
    required this.url,
    this.title = '',
    this.isDesktopMode = false,
  });

  BrowserTab copyWith({
    String? id,
    String? url,
    String? title,
    bool? isDesktopMode,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
    );
  }
}

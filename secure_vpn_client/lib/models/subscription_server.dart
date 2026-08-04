/// One selectable entry from a multi-server subscription body.
class SubscriptionServer {
  const SubscriptionServer({
    required this.index,
    required this.name,
    required this.content,
  });

  /// Index among non-decoy servers (0-based).
  final int index;

  /// Display name (`remarks`, URI fragment, or fallback).
  final String name;

  /// Either a JSON config object string or a share link (`vless://` …).
  final String content;
}

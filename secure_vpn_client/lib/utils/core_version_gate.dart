import '../models/transport_preset.dart';
import 'transport_presets.dart';

/// Compares bundled Xray-core against the pin in `scripts/fetch_cores.sh`.
class CoreVersionGate {
  CoreVersionGate._();

  /// Mirrors `DEFAULT_XRAY_VERSION` in `scripts/fetch_cores.sh`.
  static const bundledXrayPin = '26.3.27';

  static bool isOlderThanPin(String? version) {
    if (version == null || version.trim().isEmpty) {
      return false;
    }
    return compareSemver(version.trim(), bundledXrayPin) < 0;
  }

  static String? xhttpCompatibilityWarning({
    required String? actualVersion,
    required String content,
  }) {
    if (!contentUsesXhttp(content) || !isOlderThanPin(actualVersion)) {
      return null;
    }
    final actual = actualVersion?.trim();
    if (actual == null || actual.isEmpty) {
      return 'Bundled Xray version is unknown; expected v$bundledXrayPin '
          '(run scripts/fetch_cores.sh). XHTTP+REALITY may fail.';
    }
    return 'Bundled Xray v$actual is older than v$bundledXrayPin '
        '(run scripts/fetch_cores.sh). XHTTP+REALITY may fail.';
  }

  static bool contentUsesXhttp(String content) {
    final detected = TransportPresets.detectFromContent(content);
    return detected.preset == TransportPresetId.xhttpReality ||
        detected.network == 'xhttp';
  }

  static int compareSemver(String a, String b) {
    final partsA = _parseParts(a);
    final partsB = _parseParts(b);
    final length = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;
    for (var i = 0; i < length; i++) {
      final left = i < partsA.length ? partsA[i] : 0;
      final right = i < partsB.length ? partsB[i] : 0;
      if (left != right) {
        return left.compareTo(right);
      }
    }
    return 0;
  }

  static List<int> _parseParts(String value) {
    final head = value.split(RegExp(r'[-+]')).first;
    return head
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}

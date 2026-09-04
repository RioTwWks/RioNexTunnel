import 'package:v2ray_box/v2ray_box.dart';
import '../models/profile.dart';
import '../utils/link_config_builder.dart';
class ProfileImportCandidate {
  const ProfileImportCandidate({required this.link, required this.type, required this.suggestedName});
  final String link; final ProfileType type; final String suggestedName;
}
class ProfileImportService {
  ProfileImportService({V2rayBox? box}) : _box = box ?? V2rayBox();
  final V2rayBox _box;
  List<ProfileImportCandidate> parseText(String text) {
    final out = <ProfileImportCandidate>[]; final seen = <String>{};
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final t = line.trim(); if (t.isEmpty || seen.contains(t)) continue;
      final type = _detectType(t); if (type == null) continue; seen.add(t);
      out.add(ProfileImportCandidate(link: t, type: type, suggestedName: suggestName(t, type)));
    }
    return out;
  }
  ProfileType? _detectType(String line) {
    if (_box.isValidConfigLink(line) || LinkConfigBuilder.isConfigLink(line)) return ProfileType.link;
    if (isSubscriptionUrl(line)) return ProfileType.subscription; return null;
  }
  static bool isSubscriptionUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }
  static String suggestName(String link, ProfileType type) {
    if (type == ProfileType.subscription) return Uri.tryParse(link)?.host ?? 'Subscription';
    return Uri.tryParse(link)?.host ?? 'Imported profile';
  }
}

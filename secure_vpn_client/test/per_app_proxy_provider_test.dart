import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/providers/per_app_proxy_provider.dart';
import 'package:v2ray_box/v2ray_box.dart';

class _FakeV2rayBox extends V2rayBox {
  _FakeV2rayBox({
    PerAppProxyMode mode = PerAppProxyMode.off,
    List<String> excludeList = const [],
  }) : _mode = mode,
       _excludeList = excludeList;

  PerAppProxyMode _mode;
  List<String> _excludeList;

  @override
  Future<PerAppProxyMode> getPerAppProxyMode() async => _mode;

  @override
  Future<List<String>> getPerAppProxyList(PerAppProxyMode mode) async {
    return mode == PerAppProxyMode.exclude ? _excludeList : [];
  }

  @override
  Future<bool> setPerAppProxyMode(PerAppProxyMode mode) async {
    _mode = mode;
    return true;
  }

  @override
  Future<bool> setPerAppProxyList(
    List<String> packages,
    PerAppProxyMode mode,
  ) async {
    if (mode == PerAppProxyMode.exclude) {
      _excludeList = packages;
    }
    return true;
  }
}

void main() {
  group('PerAppProxyNotifier', () {
    test('setExcludeEnabled switches mode', () async {
      final box = _FakeV2rayBox();
      final notifier = PerAppProxyNotifier(box);
      await Future<void>.delayed(Duration.zero);

      await notifier.setExcludeEnabled(true);
      expect(notifier.state.mode, PerAppProxyMode.exclude);

      await notifier.setExcludeEnabled(false);
      expect(notifier.state.mode, PerAppProxyMode.off);
    });

    test('toggleExcludedApp updates exclude list', () async {
      final box = _FakeV2rayBox(mode: PerAppProxyMode.exclude);
      final notifier = PerAppProxyNotifier(box);
      await Future<void>.delayed(Duration.zero);

      await notifier.toggleExcludedApp(
        'com.example.banking',
        excluded: true,
      );
      expect(
        notifier.state.excludedPackages,
        contains('com.example.banking'),
      );

      await notifier.toggleExcludedApp(
        'com.example.banking',
        excluded: false,
      );
      expect(
        notifier.state.excludedPackages,
        isNot(contains('com.example.banking')),
      );
    });
  });
}

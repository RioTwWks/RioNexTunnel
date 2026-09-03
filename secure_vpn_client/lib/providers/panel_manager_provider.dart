import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/panel_manager.dart';

final panelManagerProvider = Provider<PanelManager>((ref) {
  final manager = PanelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

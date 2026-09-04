
import '../constants/panel_constants.dart';
enum PanelSyncInterval { minutes15(15), minutes30(30), minutes60(60), minutes120(120);
  const PanelSyncInterval(this.minutes); final int minutes;
  static const defaultInterval = PanelSyncInterval.minutes15;
  Duration get duration => Duration(minutes: minutes);
  String get wireValue => minutes.toString();
  String label() => switch (this) { PanelSyncInterval.minutes15 => 'Every 15 minutes', PanelSyncInterval.minutes30 => 'Every 30 minutes', PanelSyncInterval.minutes60 => 'Every hour', PanelSyncInterval.minutes120 => 'Every 2 hours' };
  static PanelSyncInterval fromWire(String? v) { final p=int.tryParse(v??''); if(p==null||p<kPanelMinSyncIntervalMinutes)return defaultInterval; return PanelSyncInterval.values.firstWhere((i)=>i.minutes==p,orElse:()=>defaultInterval);} }

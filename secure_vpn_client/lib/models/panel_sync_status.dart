/// User-visible panel sync state (no secrets in [message]).
enum PanelSyncStatus {
  disabled,
  synced,
  stale,
  offline,
  error,
}

extension PanelSyncStatusX on PanelSyncStatus {
  String label({bool ru = false}) {
    switch (this) {
      case PanelSyncStatus.disabled:
        return ru ? 'Отключено' : 'Disabled';
      case PanelSyncStatus.synced:
        return ru ? 'Синхронизировано' : 'Synced';
      case PanelSyncStatus.stale:
        return ru ? 'Кэш (панель недоступна)' : 'Cached (panel offline)';
      case PanelSyncStatus.offline:
        return ru ? 'Нет сети' : 'Offline';
      case PanelSyncStatus.error:
        return ru ? 'Ошибка' : 'Error';
    }
  }
}

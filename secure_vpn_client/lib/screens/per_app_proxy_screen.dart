import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../l10n/app_localizations.dart';
import '../models/split_tunnel_settings.dart';
import '../providers/per_app_proxy_provider.dart';
import '../providers/vpn_providers.dart';

class PerAppProxyScreen extends ConsumerStatefulWidget {
  const PerAppProxyScreen({super.key, required this.mode});

  final SplitTunnelMode mode;

  @override
  ConsumerState<PerAppProxyScreen> createState() => _PerAppProxyScreenState();
}

class _PerAppProxyScreenState extends ConsumerState<PerAppProxyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _loadingApps = true;
  String? _loadError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final l10n = AppLocalizations.of(context);
    try {
      final apps = await ref.read(vpnServiceProvider).v2rayBox.getInstalledApps();
      if (!mounted) {
        return;
      }
      setState(() {
        _apps = apps;
        _filteredApps = apps;
        _loadingApps = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingApps = false;
        _loadError = l10n.perAppProxyLoadError;
      });
    }
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredApps = _apps;
        return;
      }
      final lower = query.toLowerCase();
      _filteredApps = _apps
          .where(
            (app) =>
                app.name.toLowerCase().contains(lower) ||
                app.packageName.toLowerCase().contains(lower),
          )
          .toList();
    });
  }

  String _title(AppLocalizations l10n) {
    switch (widget.mode) {
      case SplitTunnelMode.include:
        return l10n.perAppProxyTitleInclude;
      case SplitTunnelMode.exclude:
        return l10n.perAppProxyTitleExclude;
      case SplitTunnelMode.off:
        return l10n.perAppProxyTitleOff;
    }
  }

  String _selectionLabel(AppLocalizations l10n) {
    switch (widget.mode) {
      case SplitTunnelMode.include:
        return l10n.perAppProxySelectedForVpn;
      case SplitTunnelMode.exclude:
        return l10n.perAppProxyBypassingVpnLabel;
      case SplitTunnelMode.off:
        return l10n.perAppProxySelectedLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(perAppProxyProvider).selectedPackages;
    final vpnConnected =
        ref.watch(vpnStatusProvider).value == VpnStatus.started;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l10n)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vpnConnected)
            MaterialBanner(
              content: Text(l10n.splitTunnelReconnectAfterChange),
              leading: Icon(Icons.info_outline, color: scheme.primary),
              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
              actions: const [SizedBox(width: 8)],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('per_app_search_field'),
              controller: _searchController,
              onChanged: _filterApps,
              decoration: InputDecoration(
                hintText: l10n.perAppProxySearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.perAppProxyClearSearch,
                        onPressed: () {
                          _searchController.clear();
                          _filterApps('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.perAppProxySelectionSummary(
                selected.length,
                _selectionLabel(l10n),
                _filteredApps.length,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                ? Center(
                    child: Text(
                      _loadError ??
                          (_searchQuery.isEmpty
                              ? l10n.perAppProxyNoAppsFound
                              : l10n.perAppProxyNoAppsMatching(_searchQuery)),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final isSelected = selected.contains(app.packageName);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: CheckboxListTile(
                          key: ValueKey('per_app_tile_${app.packageName}'),
                          title: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            app.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          secondary: Icon(
                            app.isSystemApp
                                ? Icons.android_outlined
                                : Icons.apps_outlined,
                            color: app.isSystemApp
                                ? scheme.outline
                                : scheme.primary,
                          ),
                          value: isSelected,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            ref.read(perAppProxyProvider.notifier).toggleApp(
                              app.packageName,
                              selected: value,
                              mode: widget.mode,
                            );
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

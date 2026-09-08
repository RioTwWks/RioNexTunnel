import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/profile.dart';
import '../models/subscription_refresh_interval.dart';
import '../providers/subscription_refresh_provider.dart';
import '../providers/vpn_providers.dart';
import '../services/app_log.dart';
import '../widgets/socks_auth_mode_strings.dart';
import '../widgets/transport_stack_chip.dart';

class ProfileListTile extends ConsumerWidget {
  const ProfileListTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    required this.onEditCensorship,
    this.onToggleSocksInjection,
    this.onEditTags,
    this.onRefreshSubscription,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onEditCensorship;
  final VoidCallback? onToggleSocksInjection;
  final VoidCallback? onEditTags;
  final Future<void> Function()? onRefreshSubscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final stale = isSubscriptionStale(profile);

    return Card(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      profile.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: profile.isFavorite ? scheme.tertiary : null,
                    ),
                    onPressed: () =>
                        ref.read(profilesProvider.notifier).toggleFavorite(profile.id),
                  ),
                  if (selected) Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
              Text(_subtitle(l10n, profile)),
              if (profile.lastUsedAt != null)
                Text(
                  l10n.profileLastUsed(_formatWhen(profile.lastUsedAt!)),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (stale)
                Text(
                  l10n.profileSubscriptionStale,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.error,
                      ),
                ),
              if (profile.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: profile.tags.map((t) => Chip(label: Text(t))).toList(),
                ),
              if (profile.censorshipModeEnabled)
                TransportStackChip(profile: profile, compact: true),
              if (profile.type == ProfileType.link && profile.disableSocksInjection)
                Text(
                  SocksAuthModeStrings.disableInjectionTitle(locale),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.tertiary,
                      ),
                ),
              if (profile.type == ProfileType.subscription)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => showSubscriptionRefreshPicker(context, ref, profile),
                        child: Text(profile.subscriptionRefreshInterval.label),
                      ),
                    ),
                    if (onRefreshSubscription != null)
                      TextButton.icon(
                        onPressed: onRefreshSubscription,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.actionRefresh),
                      ),
                  ],
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shield_outlined),
                    onPressed: onEditCensorship,
                  ),
                  if (onEditTags != null)
                    IconButton(
                      icon: const Icon(Icons.label_outline_rounded),
                      onPressed: onEditTags,
                    ),
                  if (onToggleSocksInjection != null)
                    IconButton(
                      icon: const Icon(Icons.build_circle_outlined),
                      onPressed: onToggleSocksInjection,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(AppLocalizations l10n, Profile profile) {
    if (profile.type == ProfileType.link) {
      return l10n.configDirectLink;
    }
    if (profile.autoSelectBestServer) {
      return profile.selectedServerName != null
          ? l10n.configAutomaticWithServer(profile.selectedServerName!)
          : l10n.configSubscriptionAutomatic;
    }
    return profile.selectedServerName != null
        ? l10n.configSubscriptionWithServer(profile.selectedServerName!)
        : l10n.configSubscription;
  }

  static String _formatWhen(DateTime when) {
    final local = when.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

Future<void> showProfileTagsEditor(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: profile.tags.join(', '));
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.profileTagsTitle),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.profileTagsHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.actionSave),
        ),
      ],
    ),
  );
  if (saved == true) {
    await ref.read(profilesProvider.notifier).setTags(
          profile.id,
          controller.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
        );
  }
  controller.dispose();
}

Future<void> showSubscriptionRefreshPicker(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final picked = await showModalBottomSheet<SubscriptionRefreshInterval>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: SubscriptionRefreshInterval.values
            .map(
              (interval) => ListTile(
                title: Text(interval.label),
                trailing: profile.subscriptionRefreshInterval == interval
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, interval),
              ),
            )
            .toList(),
      ),
    ),
  );
  if (picked != null) {
    await ref
        .read(profilesProvider.notifier)
        .setSubscriptionRefreshInterval(profile.id, picked);
  }
}

Future<void> refreshProfileSubscription(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.profileRefreshing(profile.name))),
  );
  final result = await ref.read(subscriptionRefreshServiceProvider).refreshProfile(profile);
  if (result.success) {
    await ref.read(profilesProvider.notifier).recordSubscriptionFetch(profile.id);
    AppLog.info(
      'Subscription refreshed profile=${profile.name} servers=${result.serverCount}',
    );
  } else {
    AppLog.error(
      'Subscription refresh failed profile=${profile.name}: ${result.errorMessage}',
    );
  }
  if (!context.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result.success
            ? l10n.profileSubscriptionUpdated(result.serverCount ?? 0)
            : result.errorMessage ?? l10n.profileSubscriptionRefreshFailed,
      ),
    ),
  );
}

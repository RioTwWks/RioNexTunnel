import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';
import '../screens/config_screen.dart';

/// Home profile switcher — shows name and type only (no config links or secrets).
class ProfileQuickPicker extends ConsumerWidget {
  const ProfileQuickPicker({
    super.key,
    required this.selectedProfile,
    this.onProfileSelected,
  });

  final Profile? selectedProfile;
  final VoidCallback? onProfileSelected;

  static Future<void> showSheet(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onProfileSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ProfileQuickPickerSheet(
        onProfileSelected: onProfileSelected,
      ),
    );
  }

  String get _subtitle {
    if (selectedProfile == null) {
      return 'Tap to choose a profile';
    }
    return selectedProfile!.type == ProfileType.subscription
        ? 'Subscription profile'
        : 'Direct config link';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('profile_quick_picker'),
        onTap: () => showSheet(context, ref, onProfileSelected: onProfileSelected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedProfile?.name ?? 'No profile selected',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileQuickPickerSheet extends ConsumerWidget {
  const _ProfileQuickPickerSheet({this.onProfileSelected});

  final VoidCallback? onProfileSelected;

  String _profileTypeLabel(Profile profile) {
    return profile.type == ProfileType.subscription
        ? 'Subscription'
        : 'Config link';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final selected = ref.watch(selectedProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Active profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a profile to connect from Home',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No profiles yet. Add a config link or subscription below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelected = selected?.id == profile.id;
                    return ListTile(
                      key: ValueKey('profile_option_${profile.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off_outlined,
                        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      title: Text(profile.name),
                      subtitle: Text(_profileTypeLabel(profile)),
                      onTap: () async {
                        await ref
                            .read(selectedProfileProvider.notifier)
                            .select(profile);
                        onProfileSelected?.call();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
            const Divider(height: 24),
            ListTile(
              key: const ValueKey('profile_quick_picker_add'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_circle_outline, color: scheme.primary),
              title: const Text('Add profile'),
              subtitle: const Text('Config link or subscription URL'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConfigScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

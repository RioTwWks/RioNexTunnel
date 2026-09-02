import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/transport_preset.dart';
import '../utils/transport_presets.dart';

class TransportStackChip extends StatelessWidget {
  const TransportStackChip({
    super.key,
    required this.profile,
    this.content,
    this.compact = false,
  });

  final Profile profile;
  final String? content;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: compact ? 14 : 16,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _stackSummary(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _stackSummary() {
    if (profile.censorshipModeEnabled) {
      final parts = <String>[
        if (profile.transportPreset != null)
          profile.transportPreset!.shortLabel
        else
          'Custom',
        profile.tlsFingerprint.wireValue,
        if (profile.muxEnabled) 'mux',
        if (profile.ruDirectRouting) 'RU direct',
      ];
      return parts.join(' · ');
    }
    final source = content ?? profile.configLink;
    if (source.trim().isNotEmpty) {
      return TransportPresets.detectFromContent(source).stackSummary;
    }
    return 'Standard';
  }
}

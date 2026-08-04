import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
  });

  final VpnStatus status;

  Color _color(ColorScheme scheme) {
    switch (status) {
      case VpnStatus.started:
        return scheme.primary;
      case VpnStatus.starting:
      case VpnStatus.stopping:
        return scheme.tertiary;
      case VpnStatus.stopped:
        return scheme.error;
    }
  }

  String get _label {
    switch (status) {
      case VpnStatus.started:
        return 'Connected';
      case VpnStatus.starting:
        return 'Connecting';
      case VpnStatus.stopping:
        return 'Disconnecting';
      case VpnStatus.stopped:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

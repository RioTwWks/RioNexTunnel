import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({
    super.key,
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
    this.busy = false,
  });

  final VpnStatus status;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final bool busy;

  bool get _isConnected => status == VpnStatus.started;
  bool get _isTransition =>
      status == VpnStatus.starting || status == VpnStatus.stopping;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = busy || _isTransition;
    final label = _isTransition
        ? 'Please wait…'
        : _isConnected
            ? 'Disconnect'
            : 'Connect';

    final Color ring;
    final Color fill;
    final Color iconColor;
    if (_isConnected) {
      ring = scheme.primary.withValues(alpha: 0.35);
      fill = scheme.primary;
      iconColor = scheme.onPrimary;
    } else if (_isTransition) {
      ring = scheme.tertiary.withValues(alpha: 0.3);
      fill = scheme.surfaceContainerHighest;
      iconColor = scheme.tertiary;
    } else {
      ring = scheme.outlineVariant.withValues(alpha: 0.7);
      fill = scheme.surfaceContainerHighest;
      iconColor = scheme.onSurface;
    }

    return Column(
      children: [
        Semantics(
          button: true,
          enabled: !disabled,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey(
                _isConnected ? 'disconnect_button' : 'connect_button',
              ),
              onTap: disabled
                  ? null
                  : _isConnected
                      ? onDisconnect
                      : onConnect,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: ring, width: 6),
                  boxShadow: _isConnected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _isTransition
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: iconColor,
                          ),
                        )
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: 56,
                          color: iconColor,
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _isConnected
              ? 'Tap to disconnect securely'
              : 'Tap to start protected session',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

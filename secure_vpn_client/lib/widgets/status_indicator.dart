import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/connection_detail.dart';

class StatusIndicator extends StatefulWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    this.detail,
  });

  final VpnStatus status;
  final ConnectionDetail? detail;

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  ConnectionPhase get _phase =>
      widget.detail?.phase ?? ConnectionDetail.fromVpnStatus(widget.status).phase;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.detail?.phase != widget.detail?.phase) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = _phase == ConnectionPhase.connected ||
        _phase == ConnectionPhase.connecting ||
        _phase == ConnectionPhase.reconnecting ||
        _phase == ConnectionPhase.disconnecting;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _color(ColorScheme scheme) {
    switch (_phase) {
      case ConnectionPhase.connected:
        return scheme.primary;
      case ConnectionPhase.connecting:
      case ConnectionPhase.reconnecting:
      case ConnectionPhase.disconnecting:
        return scheme.tertiary;
      case ConnectionPhase.error:
        return scheme.error;
      case ConnectionPhase.disconnected:
        return scheme.onSurfaceVariant;
    }
  }

  String get _label => widget.detail?.displayLabel ?? _fallbackLabel;

  String get _fallbackLabel {
    switch (widget.status) {
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

  IconData get _icon {
    switch (_phase) {
      case ConnectionPhase.connected:
        return Icons.verified_user_rounded;
      case ConnectionPhase.connecting:
        return Icons.sync_rounded;
      case ConnectionPhase.reconnecting:
        return Icons.autorenew_rounded;
      case ConnectionPhase.disconnecting:
        return Icons.sync_disabled_rounded;
      case ConnectionPhase.error:
        return Icons.error_outline_rounded;
      case ConnectionPhase.disconnected:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    final subtitle = widget.detail?.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: 0.35 + _pulse.value * 0.35,
                          ),
                          blurRadius: 4 + _pulse.value * 8,
                          spreadRadius: _pulse.value * 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(_label),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

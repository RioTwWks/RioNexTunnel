import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class StatusIndicator extends StatefulWidget {
  const StatusIndicator({
    super.key,
    required this.status,
  });

  final VpnStatus status;

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

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
    if (oldWidget.status != widget.status) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = widget.status == VpnStatus.started ||
        widget.status == VpnStatus.starting ||
        widget.status == VpnStatus.stopping;
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
    switch (widget.status) {
      case VpnStatus.started:
        return scheme.primary;
      case VpnStatus.starting:
      case VpnStatus.stopping:
        return scheme.tertiary;
      case VpnStatus.stopped:
        return scheme.onSurfaceVariant;
    }
  }

  String get _label {
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
    switch (widget.status) {
      case VpnStatus.started:
        return Icons.verified_user_rounded;
      case VpnStatus.starting:
        return Icons.sync_rounded;
      case VpnStatus.stopping:
        return Icons.sync_disabled_rounded;
      case VpnStatus.stopped:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);

    return AnimatedContainer(
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
              key: ValueKey(widget.status),
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
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class ConnectionButton extends StatefulWidget {
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

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton>
    with TickerProviderStateMixin {
  static const _size = 180.0;

  late final AnimationController _pulseController;
  late final AnimationController _rippleController;
  late final AnimationController _rotateController;
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(ConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    final connected = widget.status == VpnStatus.started;
    final transitioning = widget.status == VpnStatus.starting ||
        widget.status == VpnStatus.stopping;

    if (connected) {
      _pulseController.repeat(reverse: true);
      _rippleController.stop();
      _rotateController.stop();
    } else if (transitioning) {
      _pulseController.stop();
      _rippleController.repeat();
      _rotateController.repeat();
    } else {
      _pulseController.stop();
      _rippleController.stop();
      _rotateController.stop();
      _pulseController.value = 0;
      _rippleController.value = 0;
      _rotateController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isConnected => widget.status == VpnStatus.started;

  bool get _isTransition =>
      widget.status == VpnStatus.starting ||
      widget.status == VpnStatus.stopping;

  Future<void> _onTapDown(TapDownDetails _) async {
    if (!_isTransition && !widget.busy) {
      await _scaleController.forward();
    }
  }

  Future<void> _onTapUp(TapUpDetails _) async {
    await _scaleController.reverse();
  }

  Future<void> _onTapCancel() async {
    await _scaleController.reverse();
  }

  void _onTap() {
    if (widget.busy || _isTransition) {
      return;
    }
    if (_isConnected) {
      widget.onDisconnect();
    } else {
      widget.onConnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.busy || _isTransition;
    final label = _isTransition
        ? 'Please wait…'
        : _isConnected
            ? 'Disconnect'
            : 'Connect';

    final Color ring;
    final Color fill;
    final Color iconColor;
    if (_isConnected) {
      ring = scheme.primary.withValues(alpha: 0.4);
      fill = scheme.primary;
      iconColor = scheme.onPrimary;
    } else if (_isTransition) {
      ring = scheme.tertiary.withValues(alpha: 0.35);
      fill = scheme.surfaceContainerHighest;
      iconColor = scheme.tertiary;
    } else {
      ring = scheme.outlineVariant.withValues(alpha: 0.65);
      fill = scheme.surfaceContainerHighest;
      iconColor = scheme.onSurface;
    }

    return Column(
      children: [
        SizedBox(
          width: _size + 48,
          height: _size + 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isTransition) ...[
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, _) => CustomPaint(
                    size: const Size(_size + 48, _size + 48),
                    painter: _RippleRingsPainter(
                      progress: _rippleController.value,
                      color: scheme.tertiary,
                    ),
                  ),
                ),
              ],
              if (_isConnected)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = 0.25 + _pulseController.value * 0.2;
                    return Container(
                      width: _size + 24,
                      height: _size + 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: glow),
                            blurRadius: 32 + _pulseController.value * 12,
                            spreadRadius: 4 + _pulseController.value * 6,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ScaleTransition(
                scale: _scale,
                child: Semantics(
                  button: true,
                  enabled: !disabled,
                  label: label,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        _isConnected ? 'disconnect_button' : 'connect_button',
                      ),
                      onTap: disabled ? null : _onTap,
                      onTapDown: _onTapDown,
                      onTapUp: _onTapUp,
                      onTapCancel: _onTapCancel,
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isConnected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.primary,
                                    Color.lerp(
                                          scheme.primary,
                                          scheme.secondary,
                                          0.35,
                                        ) ??
                                        scheme.primary,
                                  ],
                                )
                              : null,
                          color: _isConnected ? null : fill,
                          border: Border.all(
                            color: ring,
                            width: _isConnected ? 0 : 5,
                          ),
                          boxShadow: _isConnected
                              ? [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _isTransition
                              ? AnimatedBuilder(
                                  animation: _rotateController,
                                  builder: (context, _) => CustomPaint(
                                    size: const Size(52, 52),
                                    painter: _ArcSpinnerPainter(
                                      progress: _rotateController.value,
                                      color: iconColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 58,
                                  color: iconColor,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          child: Text(
            label,
            key: ValueKey(label),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            _isConnected
                ? 'Tap to disconnect securely'
                : _isTransition
                    ? 'Establishing secure tunnel…'
                    : 'Tap to start protected session',
            key: ValueKey('$_isConnected-$_isTransition'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _RippleRingsPainter extends CustomPainter {
  _RippleRingsPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 90.0;

    for (var i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = baseRadius + phase * 36;
      final opacity = (1 - phase) * 0.45;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RippleRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ArcSpinnerPainter extends CustomPainter {
  _ArcSpinnerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final start = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      math.pi * 0.75,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start + math.pi,
      math.pi * 0.45,
      false,
      paint..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_ArcSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

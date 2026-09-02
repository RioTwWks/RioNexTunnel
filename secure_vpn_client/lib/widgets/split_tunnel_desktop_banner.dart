import 'package:flutter/material.dart';

/// Desktop proxy-mode disclaimer: per-app split tunneling is not available.
class SplitTunnelDesktopBanner extends StatelessWidget {
  const SplitTunnelDesktopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Split tunneling',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Desktop uses proxy mode, not a system TUN VPN. Per-app routing '
              'is controlled by each application (browser proxy settings, '
              'per-app rules, or OS firewall) — not by this app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Local SOCKS/HTTP proxies always require per-session authentication '
              'on 127.0.0.1 only. Split tunneling does not open unauthenticated '
              'ports.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

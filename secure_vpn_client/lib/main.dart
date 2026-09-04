import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants/app_branding.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/panel_providers.dart';
import 'providers/vpn_providers.dart';
import 'screens/config_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_log.dart';
import 'services/quick_settings_tile_coordinator.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.info('App starting');
  runApp(const ProviderScope(child: SecureVpnApp()));
}

class SecureVpnApp extends ConsumerWidget {
  const SecureVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(panelStatsLifecycleProvider);
    ref.watch(panelCommandsLifecycleProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localePreference = ref.watch(localePreferenceProvider);

    return MaterialApp(
      title: kAppName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: localePreference.locale,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quickSettingsTileCoordinatorProvider);
    });
  }

  static const _pages = [
    HomeScreen(),
    ConfigScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.navHome, l10n.navProfiles, l10n.navSettings];
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0A1628),
                      const Color(0xFF112240),
                    ]
                  : [
                      const Color(0xFFF0F4FA),
                      const Color(0xFFE8EEF8),
                    ],
            ),
          ),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'app_logo',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  kAppLogoAsset,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kAppName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      titles[_index],
                      key: ValueKey(titles[_index]),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _pages[_index],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [NavigationDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield), label: l10n.navHome), NavigationDestination(icon: const Icon(Icons.dns_outlined), selectedIcon: const Icon(Icons.dns), label: l10n.navProfiles), NavigationDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune), label: l10n.navSettings)],
      ),
    );
  }
}

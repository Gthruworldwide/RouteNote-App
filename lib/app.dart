import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/home/home_screen.dart';
import 'src/providers/app_providers.dart';

/// Root widget of RouteNote.
///
/// Watches the app lifecycle and triggers a silent, throttled Drive sync
/// whenever the app returns to the foreground (sync on resume).
class RouteNoteApp extends ConsumerStatefulWidget {
  const RouteNoteApp({super.key});

  @override
  ConsumerState<RouteNoteApp> createState() => _RouteNoteAppState();
}

class _RouteNoteAppState extends ConsumerState<RouteNoteApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync on resume is always silent: the user never sees a dialog, and a
      // signed-out device simply skips (SyncOutcome.skippedNotSignedIn).
      ref.read(syncControllerProvider.notifier).syncSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Locale? locale = ref.watch(localeControllerProvider);
    final ThemeMode themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const HomeScreen(),
    );
  }
}
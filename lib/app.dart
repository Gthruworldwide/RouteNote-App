import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'src/core/navigation/app_navigator.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/add_place/add_place_screen.dart';
import 'src/features/home/home_screen.dart';
import 'src/providers/app_providers.dart';
import 'src/services/location_parser.dart';
import 'src/services/share_intent_service.dart';

/// Root widget of RouteNote.
///
/// Watches the app lifecycle and triggers a silent, throttled Drive sync
/// whenever the app returns to the foreground (sync on resume). It also
/// listens for text/links shared into RouteNote from other apps.
class RouteNoteApp extends ConsumerStatefulWidget {
  const RouteNoteApp({super.key});

  @override
  ConsumerState<RouteNoteApp> createState() => _RouteNoteAppState();
}

class _RouteNoteAppState extends ConsumerState<RouteNoteApp>
    with WidgetsBindingObserver {
  static const LocationParser _parser = LocationParser();

  StreamSubscription<String>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForSharedLocations();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync on resume is always silent: the user never sees a dialog, and a
      // signed-out device simply skips (SyncOutcome.skippedNotSignedIn).
      ref.read(syncControllerProvider.notifier).syncSilently();
      // The user may have toggled GPS or granted permission in the system
      // settings while the app was backgrounded.
      ref.read(locationStatusProvider.notifier).refresh();
    }
  }

  /// Handles text/links shared into RouteNote from other apps (share target).
  void _listenForSharedLocations() {
    final ShareIntentService service = ref.read(shareIntentServiceProvider);
    _shareSubscription = service.textStream().listen(_handleSharedText);
    // A cold-start share is delivered before the first frame is rendered.
    service.initialText().then((List<String> texts) {
      for (final String text in texts) {
        _handleSharedText(text);
      }
    });
  }

  Future<void> _handleSharedText(String raw) async {
    ParsedLocation? parsed = _parser.parse(raw);
    if (parsed == null && _parser.looksLikeShortMapLink(raw)) {
      parsed = await _parser.resolveShortLink(raw);
    }
    if (!mounted) return;

    if (parsed == null) {
      _showShareMessage();
      return;
    }

    parsed = ParsedLocation(
      latitude: parsed.latitude,
      longitude: parsed.longitude,
      name: parsed.name ?? _parser.guessName(raw),
    );
    _openSharedLocation(parsed);
  }

  void _openSharedLocation(ParsedLocation location) {
    if (!mounted) return;
    final NavigatorState? navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // The navigator is not mounted yet (very early cold start); try again on
      // the next frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSharedLocation(location),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AddPlaceScreen(
          initialLatitude: location.latitude,
          initialLongitude: location.longitude,
          initialName: location.name,
        ),
      ),
    );
  }

  void _showShareMessage() {
    final BuildContext? context = appNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).shareNoLocation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Locale? locale = ref.watch(localeControllerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
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

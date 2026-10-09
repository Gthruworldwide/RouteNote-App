import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'src/core/config/app_config.dart';
import 'src/data/local/hive_database.dart';
import 'src/providers/app_providers.dart';
import 'src/services/background_sync_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Offline-first storage -------------------------------------------------
  await Hive.initFlutter();
  final HiveDatabase database = HiveDatabase(
    placesBox: await Hive.openBox<dynamic>(AppConfig.placesBoxName),
    settingsBox: await Hive.openBox<dynamic>(AppConfig.settingsBoxName),
  );

  runApp(
    ProviderScope(
      overrides: [hiveDatabaseProvider.overrideWithValue(database)],
      child: const RouteNoteApp(),
    ),
  );

  // --- Background backup (best-effort) ---------------------------------------
  const BackgroundSyncScheduler scheduler = BackgroundSyncScheduler();
  unawaited(
    scheduler.initialize().then((void _) => scheduler.schedulePeriodicBackup()),
  );
}

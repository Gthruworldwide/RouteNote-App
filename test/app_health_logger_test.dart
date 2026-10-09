import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:routenote/src/services/app_health_logger.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routenote_health_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('health_test');
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('aggregates events into a summary', () {
    final AppHealthLogger logger = AppHealthLogger(
      box,
      clock: () => DateTime.utc(2026, 1, 10, 12),
    );

    logger.log(HealthEventType.appLaunch);
    logger.log(HealthEventType.syncFailed, message: 'timeout');
    logger.log(HealthEventType.syncFailed, message: 'timeout');
    logger.log(HealthEventType.syncSucceeded);
    logger.logParseFailure(source: 'clipboard');
    logger.logParseFailure(source: 'share', shortLink: true);
    logger.logUiLatency('home', const Duration(milliseconds: 320));

    final HealthSummary summary = logger.summary();
    expect(summary.totalEvents, 7);
    expect(summary.appLaunches, 1);
    expect(summary.syncFailed, 2);
    expect(summary.syncSucceeded, 1);
    expect(summary.parseFailures, 1);
    expect(summary.shortLinkFailures, 1);
    expect(summary.lastUiLatency, const Duration(milliseconds: 320));
  });

  test('drops events older than the window', () {
    DateTime now = DateTime.utc(2026, 1, 1);
    final AppHealthLogger logger = AppHealthLogger(box, clock: () => now);

    logger.log(HealthEventType.syncFailed);
    now = DateTime.utc(2026, 1, 20);
    logger.log(HealthEventType.syncSucceeded);

    final HealthSummary summary = logger.summary(
      window: const Duration(days: 7),
    );
    expect(summary.syncFailed, 0);
    expect(summary.syncSucceeded, 1);
  });

  test('persists events across logger instances', () async {
    final AppHealthLogger first = AppHealthLogger(box);
    first.log(HealthEventType.placeSaved);
    await pumpEventQueue();

    final AppHealthLogger second = AppHealthLogger(box);
    expect(second.count(HealthEventType.placeSaved), 1);
  });

  test('caps the in-memory log', () {
    final AppHealthLogger logger = AppHealthLogger(box, capacity: 5);
    for (int i = 0; i < 10; i++) {
      logger.log(HealthEventType.appResume);
    }
    expect(logger.recent(limit: 100), hasLength(5));
  });
}

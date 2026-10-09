import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:routenote/src/core/config/app_config.dart';
import 'package:routenote/src/services/app_health_logger.dart';
import 'package:routenote/src/services/app_observer_service.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routenote_observer_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('observer_test');
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('records a sanitized serviceIssue event with its category', () {
    final AppHealthLogger logger = AppHealthLogger(box);
    final AppObserverService observer = AppObserverService(logger);

    observer.logIssue(
      category: AppIssueCategory.parsing,
      error: 'Could not parse the pasted link',
    );

    final HealthEvent event = logger.recent(limit: 1).single;
    expect(event.type, HealthEventType.serviceIssue);
    expect(event.data['category'], 'parsing');
    expect(event.message, 'Could not parse the pasted link');
  });

  test('never persists the stack trace', () {
    final AppHealthLogger logger = AppHealthLogger(box);
    final AppObserverService observer = AppObserverService(logger);

    observer.logIssue(
      category: AppIssueCategory.sync,
      error: 'Silent restore failed',
      stackTrace: 'dart:async  #0 fakeStackFrame (package:app/main.dart:1:1)',
    );

    final HealthEvent event = logger.recent(limit: 1).single;
    expect(event.data.containsKey('stackTrace'), isFalse);
    expect(event.message, isNot(contains('fakeStackFrame')));
    expect(event.message, 'Silent restore failed');
  });

  test('flattens and truncates long error text', () {
    final AppHealthLogger logger = AppHealthLogger(box);
    final AppObserverService observer = AppObserverService(logger);

    final String longError =
        'ProvisionalHeaders: 401 Unauthorized\n'
        'Dart Error: Unhandled exception: Bad state: too many\n'
        '${'x' * 200}';

    observer.logIssue(
      category: AppIssueCategory.performance,
      error: longError,
    );

    final HealthEvent event = logger.recent(limit: 1).single;
    expect(event.message, isNotNull);
    expect(event.message!.length, lessThanOrEqualTo(120));
    expect(event.message!.endsWith('...'), isTrue);
    expect(event.message, isNot(contains('\n')));
  });

  test('merges caller context data', () {
    final AppHealthLogger logger = AppHealthLogger(box);
    final AppObserverService observer = AppObserverService(logger);

    observer.logIssue(
      category: AppIssueCategory.performance,
      error: 'First frame took 900 ms',
      contextData: <String, dynamic>{
        'screen': 'home',
        'retryable': true,
      },
    );

    final HealthEvent event = logger.recent(limit: 1).single;
    expect(event.data['screen'], 'home');
    expect(event.data['retryable'], true);
    expect(event.data['category'], 'performance');
  });

  test('every category is stored under its own coarse name', () {
    final AppHealthLogger logger = AppHealthLogger(box);
    final AppObserverService observer = AppObserverService(logger);

    for (final AppIssueCategory category in AppIssueCategory.values) {
      observer.logIssue(category: category, error: 'issue in $category');
    }

    final Set<Object?> categories = logger
        .recent(limit: AppIssueCategory.values.length)
        .map((HealthEvent e) => e.data['category'])
        .toSet();
    expect(
      categories,
      AppIssueCategory.values.map((AppIssueCategory c) => c.name).toSet(),
    );
  });

  test('respects the bounded health-log capacity', () {
    final AppHealthLogger logger = AppHealthLogger(box, capacity: 5);
    final AppObserverService observer = AppObserverService(logger);

    for (int i = 0; i < 12; i++) {
      observer.logIssue(category: AppIssueCategory.sync, error: 'err $i');
    }

    expect(logger.recent(limit: 100), hasLength(5));
  });

  test('persists across a reload of the Hive box', () async {
    final AppHealthLogger first = AppHealthLogger(box);
    AppObserverService(first).logIssue(
      category: AppIssueCategory.ui,
      error: 'Slow frame on home',
    );

    // The Hive mirror write is fire-and-forget; give it a beat to land.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await box.get(AppConfig.healthLogKey), isNotNull);

    await box.close();
    box = await Hive.openBox<dynamic>('observer_test');

    final HealthEvent event = AppHealthLogger(box).recent(limit: 1).single;
    expect(event.type, HealthEventType.serviceIssue);
    expect(event.data['category'], 'ui');
    expect(event.message, 'Slow frame on home');
  });
}
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/settings_store.dart';
import 'data/tarot_repository.dart';
import 'l10n/strings.dart';
import 'services/grading_service.dart';
import 'services/llm_client.dart';
import 'services/qa_service.dart';
import 'services/study_service.dart';
import 'services/update_service.dart';

/// Everything the widget tree needs, assembled once at startup.
class AppServices {
  AppServices._({
    required this.settings,
    required this.repository,
    required this.study,
    required this.qa,
    required this.grading,
    required this.updates,
  });

  static Future<AppServices> create() async {
    final SettingsStore settings = await SettingsStore.load();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final TarotRepository repository = TarotRepository();
    final LlmClient client = LlmClient();

    return AppServices._(
      settings: settings,
      repository: repository,
      study: StudyService(prefs),
      qa: QaService(repository: repository, client: client),
      grading: GradingService(repository: repository, client: client),
      updates: UpdateService(),
    );
  }

  final SettingsStore settings;
  final TarotRepository repository;
  final StudyService study;
  final QaService qa;
  final GradingService grading;
  final UpdateService updates;
}

/// Exposes [AppServices] to the widget tree and rebuilds dependents whenever
/// [SettingsStore] notifies, so a language or provider change lands everywhere
/// at once.
class AppScope extends InheritedNotifier<SettingsStore> {
  AppScope({super.key, required this.services, required super.child})
      : super(notifier: services.settings);

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.services;
  }

  static SettingsStore settingsOf(BuildContext context) => of(context).settings;

  static Strings stringsOf(BuildContext context) =>
      Strings.of(settingsOf(context).language);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_settings.dart';
import '../../../core/utils/providers.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> update(AppSettings settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(settings);
    state = settings;
  }

  Future<void> updateField(AppSettings Function(AppSettings) updater) async {
    await update(updater(state));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

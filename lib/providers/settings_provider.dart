import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../models/app_settings.dart';
import '../models/business_settings.dart';
import '../models/enums.dart';
import '../repositories/settings_repository.dart';
import 'repository_providers.dart';

/// Configuración del negocio. Se re-resuelve al cambiar la caja Hive.
final businessSettingsProvider = NotifierProvider<BusinessSettingsNotifier,
    BusinessSettings>(BusinessSettingsNotifier.new);

class BusinessSettingsNotifier extends Notifier<BusinessSettings> {
  @override
  BusinessSettings build() =>
      ref.watch(settingsRepositoryProvider).getBusiness();

  Future<void> update({
    String? businessName,
    String? ownerName,
  }) async {
    await ref
        .read(settingsRepositoryProvider)
        .updateBusiness(businessName: businessName, ownerName: ownerName);
    // Copia, no la instancia de la caja: ver AppSettingsNotifier.update.
    state = ref.read(settingsRepositoryProvider).getBusiness().copy();
  }

  Future<void> setLogo(String? path) async {
    await ref.read(settingsRepositoryProvider).setLogo(path);
    state = ref.read(settingsRepositoryProvider).getBusiness().copy();
  }
}

/// Ruta del logo personalizado, o `null` si se usa el de la app (§6).
final businessLogoPathProvider = Provider<String?>((Ref ref) {
  final BusinessSettings settings = ref.watch(businessSettingsProvider);
  return settings.hasCustomLogo ? settings.logoPath : null;
});

/// Preferencias de la app (tema, moneda, formatos, folio).
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).getSettings();

  /// Aplica y persiste un cambio parcial.
  ///
  /// Muta una **copia**: `getSettings()` devuelve la misma instancia que ya
  /// está en `state`, y reasignar el mismo objeto no notifica a Riverpod.
  Future<void> update(AppSettings Function(AppSettings) mutate) async {
    final SettingsRepository repo = ref.read(settingsRepositoryProvider);
    final AppSettings next = mutate(repo.getSettings().copy());
    await repo.saveSettings(next);
    state = next;
  }

  Future<void> setTheme(ThemePreference preference) =>
      update((AppSettings s) => s..themePreference = preference);

  Future<void> setCurrency(String currency) =>
      update((AppSettings s) => s..currency = currency);

  Future<void> setDateFormat(DateFormatPreference format) =>
      update((AppSettings s) => s..dateFormat = format);

  Future<void> setDefaultMinStock(int value) =>
      update((AppSettings s) => s..defaultMinStock = value);

  Future<void> setSalePrefix(String prefix) => update(
    (AppSettings s) => s..salePrefix = prefix.trim().isEmpty
        ? 'V'
        : prefix.trim().toUpperCase(),
  );
}

/// `ThemeMode` derivado de la preferencia. `Sistema` respeta Android (§10).
final themeModeProvider = Provider<ThemeMode>((Ref ref) {
  return switch (ref.watch(appSettingsProvider.select((AppSettings s) => s.themePreference))) {
    ThemePreference.claro => ThemeMode.light,
    ThemePreference.oscuro => ThemeMode.dark,
    ThemePreference.sistema => ThemeMode.system,
  };
});

/// ¿Ya pasó la configuración inicial? (§7)
final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => AppDatabase.onboardingDone;

  Future<void> complete() async {
    await AppDatabase.setOnboardingDone(true);
    state = true;
  }
}

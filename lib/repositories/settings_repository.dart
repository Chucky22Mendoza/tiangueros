import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../../models/app_settings.dart';
import '../../models/business_settings.dart';
import '../../models/enums.dart';

/// Lectura/escritura de la identidad del negocio y de las preferencias.
class SettingsRepository {
  SettingsRepository();

  // --- Negocio ---

  /// Devuelve la configuración del negocio, creándola con defaults si es la
  /// primera vez. Nunca devuelve cadenas vacías (§8).
  BusinessSettings getBusiness() {
    final Box<BusinessSettings> box = AppDatabase.business;
    final BusinessSettings? current = box.get(AppDatabase.businessKey);
    if (current != null) return current;

    final BusinessSettings defaults = BusinessSettings();
    box.put(AppDatabase.businessKey, defaults);
    return defaults;
  }

  Future<void> saveBusiness(BusinessSettings settings) =>
      AppDatabase.business.put(AppDatabase.businessKey, settings);

  /// Guarda sólo si hay contenido; si viene vacío conserva el valor previo.
  /// Así el onboarding nunca persiste cadenas en blanco (§8).
  Future<BusinessSettings> updateBusiness({
    String? businessName,
    String? ownerName,
  }) async {
    final BusinessSettings current = getBusiness();
    if (businessName != null && businessName.trim().isNotEmpty) {
      current.businessName = businessName.trim();
    }
    if (ownerName != null && ownerName.trim().isNotEmpty) {
      current.ownerName = ownerName.trim();
    }
    await saveBusiness(current);
    return current;
  }

  /// Cambia el logo del negocio. `null` lo elimina y se vuelve al logo de la
  /// app (§6).
  Future<void> setLogo(String? path) async {
    final BusinessSettings current = getBusiness();
    current.logoPath = (path == null || path.isEmpty) ? null : path;
    await saveBusiness(current);
  }

  // --- Preferencias ---

  AppSettings getSettings() {
    final Box<AppSettings> box = AppDatabase.settings;
    final AppSettings? current = box.get(AppDatabase.settingsKey);
    if (current != null) return current;

    final AppSettings defaults = AppSettings();
    box.put(AppDatabase.settingsKey, defaults);
    return defaults;
  }

  Future<void> saveSettings(AppSettings settings) =>
      AppDatabase.settings.put(AppDatabase.settingsKey, settings);

  Future<void> setTheme(ThemePreference preference) async {
    final AppSettings s = getSettings();
    s.themePreference = preference;
    await saveSettings(s);
  }

  Future<void> setCurrency(String currency) async {
    final AppSettings s = getSettings();
    s.currency = currency;
    await saveSettings(s);
  }

  Future<void> setDateFormat(DateFormatPreference format) async {
    final AppSettings s = getSettings();
    s.dateFormat = format;
    await saveSettings(s);
  }

  /// Borra todos los datos y deja la app lista para empezar de cero (§46).
  ///
  /// No reinstala la configuración inicial: se conservan los flags para que la
  /// app no vuelva a pedir el nombre del negocio.
  /// Borra todo y deja la app como recién instalada (§36).
  ///
  /// El flag va **después** del wipe: `meta` también se limpia, así que
  /// escribirlo antes lo perdería y la app pediría la bienvenida otra vez.
  /// Volvemos a poner `true` a propósito para no repetir el onboarding, ya que
  /// esto lo elige el usuario desde Ajustes.
  Future<void> wipeEverything() async {
    await AppDatabase.wipeAll();
    await AppDatabase.meta.put(AppConstants.keyOnboardingDone, true);
  }

  Future<void> setDefaultMinStock(int value) async {
    if (value < 0) {
      throw const ValidationException('El stock mínimo no puede ser negativo');
    }
    final AppSettings s = getSettings();
    s.defaultMinStock = value;
    await saveSettings(s);
  }

  Future<void> setSalePrefix(String prefix) async {
    final AppSettings s = getSettings();
    s.salePrefix = prefix.trim().isEmpty ? 'V' : prefix.trim().toUpperCase();
    await saveSettings(s);
  }

  /// Prefijo de folio normalizado: `V` ⇒ `V-000001` (§38).
  String get folioPrefix {
    final String p = getSettings().salePrefix.trim();
    return p.isEmpty ? 'V' : p.toUpperCase();
  }
}

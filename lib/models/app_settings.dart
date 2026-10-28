import 'package:hive_ce/hive.dart';

import '../core/constants/app_constants.dart';
import 'enums.dart';
import 'hive_type_ids.dart';

part 'app_settings.g.dart';

/// Preferencias de la app (§36).
@HiveType(typeId: HiveTypeIds.appSettings)
class AppSettings extends HiveObject {
  AppSettings({
    ThemePreference themePreference = ThemePreference.sistema,
    this.currency = AppConstants.defaultCurrency,
    DateFormatPreference dateFormat = DateFormatPreference.diaMesAnio,
    this.defaultMinStock = AppConstants.defaultMinStock,
    this.salePrefix = AppConstants.defaultSalePrefix,
  })  : themePreferenceIndex = themePreference.index,
        dateFormatIndex = dateFormat.index;

  /// Índices de los enums de preferencias: Hive no serializa enums.
  @HiveField(0)
  int themePreferenceIndex;
  @HiveField(1)
  String currency;
  @HiveField(2)
  int dateFormatIndex;
  @HiveField(3)
  int defaultMinStock;
  @HiveField(4)
  String salePrefix;

  ThemePreference get themePreference => ThemePreference.values[
      themePreferenceIndex >= 0 &&
              themePreferenceIndex < ThemePreference.values.length
          ? themePreferenceIndex
          : ThemePreference.sistema.index];

  set themePreference(ThemePreference value) =>
      themePreferenceIndex = value.index;

  DateFormatPreference get dateFormat => DateFormatPreference.values[
      dateFormatIndex >= 0 && dateFormatIndex < DateFormatPreference.values.length
          ? dateFormatIndex
          : DateFormatPreference.diaMesAnio.index];

  set dateFormat(DateFormatPreference value) => dateFormatIndex = value.index;

  /// Copia con identidad nueva.
  ///
  /// Hive devuelve *la misma instancia* mientras la caja la tenga cargada. Si
  /// un provider muta esa instancia y la reasigna, `identical(previo, nuevo)`
  /// es `true` y Riverpod no notifica: la pantalla no se entera del cambio.
  /// Los notifiers mutan una copia y guardan ésa.
  AppSettings copy() => AppSettings(
        themePreference: themePreference,
        currency: currency,
        dateFormat: dateFormat,
        defaultMinStock: defaultMinStock,
        salePrefix: salePrefix,
      );

  String get safePrefix =>
      salePrefix.trim().isEmpty ? AppConstants.defaultSalePrefix : salePrefix.trim();
}

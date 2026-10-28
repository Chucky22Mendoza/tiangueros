import 'package:hive_ce/hive.dart';

import '../core/constants/app_constants.dart';
import 'hive_type_ids.dart';

part 'business_settings.g.dart';

/// Identidad del negocio: nombre, encargado y logo opcional (§9).
///
/// Regla Hive: todos los campos persistidos deben ser **mutables** y el
/// constructor debe poder invocarse sin argumentos. El generador de adapters
/// depende de eso.
@HiveType(typeId: HiveTypeIds.businessSettings)
class BusinessSettings extends HiveObject {
  BusinessSettings({
    this.businessName = AppConstants.defaultBusinessName,
    this.ownerName = AppConstants.defaultOwnerName,
    this.logoPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @HiveField(0)
  String businessName;
  @HiveField(1)
  String ownerName;

  /// Ruta local del logo personalizado. `null` ⇒ usar logo de la app (§6).
  @HiveField(2)
  String? logoPath;

  @HiveField(3)
  DateTime createdAt;

  /// Copia con identidad nueva: ver `AppSettings.copy`.
  BusinessSettings copy() => BusinessSettings(
        businessName: businessName,
        ownerName: ownerName,
        logoPath: logoPath,
        createdAt: createdAt,
      );

  /// Nunca devolver cadenas vacías: se cae al default (§8).
  String get displayName {
    final String v = businessName.trim();
    return v.isEmpty ? AppConstants.defaultBusinessName : v;
  }

  String get displayOwner {
    final String v = ownerName.trim();
    return v.isEmpty ? AppConstants.defaultOwnerName : v;
  }

  bool get hasCustomLogo => logoPath != null && logoPath!.isNotEmpty;
}

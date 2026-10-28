import 'package:hive_ce/hive.dart';

import 'hive_type_ids.dart';

part 'category.g.dart';

/// Categoría de producto (Ropa, Accesorios, Comida…).
@HiveType(typeId: HiveTypeIds.category)
class Category extends HiveObject {
  Category({
    this.id = '',
    this.name = '',
    this.colorValue = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @HiveField(0)
  String id;
  @HiveField(1)
  String name;

  /// Valor ARGB de `Color`, guardado como int porque Hive no persiste Color.
  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdAt;
}

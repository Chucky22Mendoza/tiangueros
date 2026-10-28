// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_movement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryMovementAdapter extends TypeAdapter<InventoryMovement> {
  @override
  final typeId = 6;

  @override
  InventoryMovement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryMovement(
      id: fields[0] == null ? '' : fields[0] as String,
      productId: fields[1] == null ? '' : fields[1] as String,
      productName: fields[2] == null ? '' : fields[2] as String,
      quantity: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      previousStock: fields[5] == null ? 0 : (fields[5] as num).toDouble(),
      newStock: fields[6] == null ? 0 : (fields[6] as num).toDouble(),
      reason: fields[7] == null ? '' : fields[7] as String,
      referenceId: fields[8] as String?,
      date: fields[9] as DateTime?,
    )..typeIndex = (fields[3] as num).toInt();
  }

  @override
  void write(BinaryWriter writer, InventoryMovement obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.typeIndex)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.previousStock)
      ..writeByte(6)
      ..write(obj.newStock)
      ..writeByte(7)
      ..write(obj.reason)
      ..writeByte(8)
      ..write(obj.referenceId)
      ..writeByte(9)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryMovementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_movement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CashMovementAdapter extends TypeAdapter<CashMovement> {
  @override
  final typeId = 8;

  @override
  CashMovement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CashMovement(
      id: fields[0] == null ? '' : fields[0] as String,
      amount: fields[2] == null ? 0 : (fields[2] as num).toInt(),
      concept: fields[3] == null ? '' : fields[3] as String,
      referenceId: fields[4] as String?,
      date: fields[5] as DateTime?,
    )..typeIndex = (fields[1] as num).toInt();
  }

  @override
  void write(BinaryWriter writer, CashMovement obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.typeIndex)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.concept)
      ..writeByte(4)
      ..write(obj.referenceId)
      ..writeByte(5)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashMovementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

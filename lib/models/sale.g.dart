// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final typeId = 4;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
        id: fields[0] == null ? '' : fields[0] as String,
        folio: fields[1] == null ? '' : fields[1] as String,
        items: (fields[2] as List?)?.cast<SaleItem>(),
        subtotal: fields[3] == null ? 0 : (fields[3] as num).toInt(),
        discount: fields[4] == null ? 0 : (fields[4] as num).toInt(),
        total: fields[5] == null ? 0 : (fields[5] as num).toInt(),
        costTotal: fields[6] == null ? 0 : (fields[6] as num).toInt(),
        profit: fields[7] == null ? 0 : (fields[7] as num).toInt(),
        isQuickSale: fields[9] == null ? false : fields[9] as bool,
        notes: fields[11] == null ? '' : fields[11] as String,
        date: fields[12] as DateTime?,
        voidedAt: fields[13] as DateTime?,
        returnedAt: fields[14] as DateTime?,
      )
      ..paymentMethodIndex = (fields[8] as num).toInt()
      ..statusIndex = (fields[10] as num).toInt();
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.folio)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.subtotal)
      ..writeByte(4)
      ..write(obj.discount)
      ..writeByte(5)
      ..write(obj.total)
      ..writeByte(6)
      ..write(obj.costTotal)
      ..writeByte(7)
      ..write(obj.profit)
      ..writeByte(8)
      ..write(obj.paymentMethodIndex)
      ..writeByte(9)
      ..write(obj.isQuickSale)
      ..writeByte(10)
      ..write(obj.statusIndex)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.date)
      ..writeByte(13)
      ..write(obj.voidedAt)
      ..writeByte(14)
      ..write(obj.returnedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

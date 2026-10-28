// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_closing.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyClosingAdapter extends TypeAdapter<DailyClosing> {
  @override
  final typeId = 9;

  @override
  DailyClosing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyClosing(
      id: fields[0] == null ? '' : fields[0] as String,
      date: fields[1] as DateTime?,
      salesCount: fields[2] == null ? 0 : (fields[2] as num).toInt(),
      itemsSold: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      cashTotal: fields[4] == null ? 0 : (fields[4] as num).toInt(),
      transferTotal: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      cardTotal: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      otherTotal: fields[7] == null ? 0 : (fields[7] as num).toInt(),
      total: fields[8] == null ? 0 : (fields[8] as num).toInt(),
      costTotal: fields[9] == null ? 0 : (fields[9] as num).toInt(),
      grossProfit: fields[10] == null ? 0 : (fields[10] as num).toInt(),
      expensesTotal: fields[11] == null ? 0 : (fields[11] as num).toInt(),
      netProfit: fields[12] == null ? 0 : (fields[12] as num).toInt(),
      countedCash: (fields[13] as num?)?.toInt(),
      closingNote: fields[14] == null ? '' : fields[14] as String,
      createdAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyClosing obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.salesCount)
      ..writeByte(3)
      ..write(obj.itemsSold)
      ..writeByte(4)
      ..write(obj.cashTotal)
      ..writeByte(5)
      ..write(obj.transferTotal)
      ..writeByte(6)
      ..write(obj.cardTotal)
      ..writeByte(7)
      ..write(obj.otherTotal)
      ..writeByte(8)
      ..write(obj.total)
      ..writeByte(9)
      ..write(obj.costTotal)
      ..writeByte(10)
      ..write(obj.grossProfit)
      ..writeByte(11)
      ..write(obj.expensesTotal)
      ..writeByte(12)
      ..write(obj.netProfit)
      ..writeByte(13)
      ..write(obj.countedCash)
      ..writeByte(14)
      ..write(obj.closingNote)
      ..writeByte(15)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyClosingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

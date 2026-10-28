// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessSettingsAdapter extends TypeAdapter<BusinessSettings> {
  @override
  final typeId = 0;

  @override
  BusinessSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessSettings(
      businessName: fields[0] == null
          ? AppConstants.defaultBusinessName
          : fields[0] as String,
      ownerName: fields[1] == null
          ? AppConstants.defaultOwnerName
          : fields[1] as String,
      logoPath: fields[2] as String?,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.businessName)
      ..writeByte(1)
      ..write(obj.ownerName)
      ..writeByte(2)
      ..write(obj.logoPath)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

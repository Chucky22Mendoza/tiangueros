// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
        currency: fields[1] == null
            ? AppConstants.defaultCurrency
            : fields[1] as String,
        defaultMinStock: fields[3] == null
            ? AppConstants.defaultMinStock
            : (fields[3] as num).toInt(),
        salePrefix: fields[4] == null
            ? AppConstants.defaultSalePrefix
            : fields[4] as String,
      )
      ..themePreferenceIndex = (fields[0] as num).toInt()
      ..dateFormatIndex = (fields[2] as num).toInt();
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.themePreferenceIndex)
      ..writeByte(1)
      ..write(obj.currency)
      ..writeByte(2)
      ..write(obj.dateFormatIndex)
      ..writeByte(3)
      ..write(obj.defaultMinStock)
      ..writeByte(4)
      ..write(obj.salePrefix);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

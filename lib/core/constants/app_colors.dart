import 'package:flutter/material.dart';

/// Paleta base inspirada en puestos y mercados mexicanos.
///
/// No usar todos los colores a la vez: el color primario es la combinación
/// naranja + rojo + amarillo, y verde/turquesa quedan como secundarios.
abstract final class TianguisPalette {
  static const Color chile = Color(0xFFC62828);
  static const Color naranja = Color(0xFFEF6C00);
  static const Color amarillo = Color(0xFFF9A825);
  static const Color verde = Color(0xFF2E7D32);
  static const Color turquesa = Color(0xFF00897B);
  static const Color crema = Color(0xFFFFF8E7);
  static const Color cafe = Color(0xFF6D4C41);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color negro = Color(0xFF212121);

  /// Semánticos: se usan en varias pantallas, siempre vía ColorScheme.
  static const Color success = verde;
  static const Color danger = chile;
  static const Color warning = amarillo;
  static const Color info = turquesa;
}

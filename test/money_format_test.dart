import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/utils/money.dart';

/// `formatCompact` se usa en las etiquetas de la gráfica de reportes, en el
/// dashboard y en la ficha de producto. Antes reventaba desde $1,000 en
/// adelante: el escalado se pasaba como `String` a `NumberFormat.format`.
void main() {
  group('Money.formatCompact', () {
    test('montos chicos salen con el formato normal', () {
      expect(Money.formatCompact(0), r'$0.00');
      expect(Money.formatCompact(1500), r'$15.00');
      expect(Money.formatCompact(99999), r'$999.99');
    });

    test('desde \$1,000 usa la escala k sin reventar', () {
      expect(Money.formatCompact(100000), r'$1k');
      expect(Money.formatCompact(250000), r'$2.5k');
      expect(Money.formatCompact(99999999), r'$1M');
    });

    test('desde \$1,000,000 usa la escala M sin reventar', () {
      expect(Money.formatCompact(100000000), r'$1M');
      expect(Money.formatCompact(468750000), r'$4.7M');
    });

    test('el signo va por delante del símbolo', () {
      expect(Money.formatCompact(-1500), r'-$15.00');
      expect(Money.formatCompact(-250000), r'-$2.5k');
      expect(Money.formatCompact(-100000000), r'-$1M');
    });
  });
}

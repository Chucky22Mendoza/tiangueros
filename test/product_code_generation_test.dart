import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/repositories/product_repository.dart';

import 'helpers.dart';

void main() {
  late ProductRepository products;

  setUp(() async {
    await openTestDatabase();
    products = ProductRepository();
  });

  test('generateSku: iniciales + correlativo único', () {
    expect(products.generateSku('Playera básica negra'), 'PBN-001');
    expect(products.generateSku('café con leche'), 'CCL-001');
    expect(products.generateSku('   '), 'PRD-001');
    expect(products.generateSku('Gorra'), 'GOR-001');
    expect(products.generateSku('A'), 'A-001');
  });

  test('generateSku no repite contra los ya guardados', () async {
    await products.create(name: 'Gorra', cost: 1000, price: 2000, sku: 'GOR-001');
    expect(products.generateSku('Gorra'), 'GOR-002');
  });

  test('generateBarcode: 13 dígitos con verificador válido y único', () {
    bool validCheckDigit(String code) {
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        final int d = int.parse(code[i]);
        sum += i.isEven ? d : d * 3;
      }
      return (10 - sum % 10) % 10 == int.parse(code[12]);
    }

    final String a = products.generateBarcode();
    final String b = products.generateBarcode();
    expect(a.length, 13);
    expect(RegExp(r'^\d{13}$').hasMatch(a), isTrue);
    expect(a[0] != '9', isTrue); // EAN-13: el primer dígito va de 0 a 8
    expect(validCheckDigit(a), isTrue, reason: 'dígito verificador de $a');
    expect(a, isNot(b));
  });
}

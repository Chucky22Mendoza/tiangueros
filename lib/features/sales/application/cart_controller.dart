import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../repositories/sales_repository.dart' show CartLine;

/// Estado del carrito de la venta en curso.
///
/// Vive sólo en memoria: si el usuario cierra la pantalla, la venta no se cobra
/// y no se descuenta stock.
///
/// El descuento forma parte del estado (y no un campo aparte del notifier) por
/// una razón concreta: en Riverpod la UI se reconstruye cuando cambia el
/// `state`. Un descuento guardado en un campo privado no dispararía ninguna
/// reconstrucción y la barra de cobro mostraría el total sin descuento.
class CartState {
  const CartState({this.lines = const <CartLine>[], this.discountCents = 0});

  final List<CartLine> lines;

  /// Descuento ya aplicado, en centavos, nunca mayor al subtotal.
  final int discountCents;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get subtotal =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.lineTotal);

  int get total => subtotal - discountCents;

  int get costTotal =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.lineCost);

  int get profit => total - costTotal;

  int get itemCount =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.quantity);

  /// `true` si alguna partida se vendió sin costo capturado: la ganancia que se
  /// muestra es una estimación y la UI lo advierte (§17).
  bool get hasUnknownCost => lines.any((CartLine l) => l.unitCost == 0);

  CartLine? lineOf(String productId) {
    for (final CartLine l in lines) {
      if (l.productId == productId) return l;
    }
    return null;
  }

  CartState copyWith({List<CartLine>? lines, int? discountCents}) => CartState(
    lines: lines ?? this.lines,
    discountCents: discountCents ?? this.discountCents,
  );
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Agrega una unidad. Si el producto ya está en el carrito, suma cantidad
  /// respetando el stock disponible.
  void add(Product product) {
    final CartLine? existing = state.lineOf(product.id);
    if (existing == null) {
      state = state.copyWith(
        lines: <CartLine>[
          ...state.lines,
          CartLine(
            productId: product.id,
            productName: product.name,
            unitCost: product.cost,
            unitPrice: product.price,
            quantity: 1,
            unit: product.unit,
            availableStock: product.stock,
          ),
        ],
      );
      return;
    }
    setQuantity(product.id, existing.quantity + 1);
  }

  void remove(String productId) {
    final List<CartLine> lines = state.lines
        .where((CartLine l) => l.productId != productId)
        .toList(growable: false);
    // Sin partidas el descuento no significaría nada: se limpia con el carrito.
    state = state.copyWith(
      lines: lines,
      discountCents: lines.isEmpty ? 0 : state.discountCents,
    );
  }

  void setQuantity(String productId, int quantity) {
    final CartLine? line = state.lineOf(productId);
    if (line == null) return;
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    _replace(productId, _capped(line, quantity));
  }

  /// Cambia el precio de una partida (precio especial en el mostrador) sin
  /// tocar el catálogo (§15).
  void setPrice(String productId, int price) {
    if (price < 0) return;
    final CartLine? line = state.lineOf(productId);
    if (line == null) return;
    _replace(productId, line.copyWith(unitPrice: price));
  }

  /// Aplica un descuento en centavos, acotado al subtotal.
  void setDiscount(int cents) {
    final int subtotal = state.subtotal;
    state = state.copyWith(
      discountCents: cents < 0 ? 0 : (cents > subtotal ? subtotal : cents),
    );
  }

  void clear() => state = const CartState();

  /// Vuelve a leer precios y stock actuales antes de cobrar (§39, §47).
  ///
  /// Entre que un producto entró al carrito y se cobra, otra pantalla pudo
  /// haber cambiado su precio o haberse vendido existencias. Los datos que se
  /// guardan en la venta son los del momento del cobro, no los del primer toque.
  void refreshFrom(List<Product> products) {
    if (state.lines.isEmpty) return;
    final Map<String, Product> byId = <String, Product>{
      for (final Product p in products) p.id: p,
    };
    final List<CartLine> lines = <CartLine>[];
    for (final CartLine line in state.lines) {
      final Product? fresh = byId[line.productId];
      lines.add(
        fresh == null
            ? line
            : line.copyWith(unitPrice: fresh.price, availableStock: fresh.stock),
      );
    }
    state = state.copyWith(lines: lines);
  }

  void _replace(String productId, CartLine line) {
    state = state.copyWith(
      lines: <CartLine>[
        for (final CartLine l in state.lines)
          if (l.productId == productId) line else l,
      ],
    );
  }

  /// No se puede vender más de lo que hay, ni una unidad de más.
  CartLine _capped(CartLine line, int quantity) {
    final int max = line.availableStock.toInt();
    final int capped = quantity > max ? max : quantity;
    if (capped <= 0) {
      remove(line.productId);
      return line;
    }
    return line.copyWith(quantity: capped);
  }
}

/// Carrito de la venta en curso.
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

/// Vista plana del carrito para la barra de cobro: depende de `cartProvider`,
/// así que se reconstruye con cualquier cambio, incluido el descuento.
final cartSummaryProvider = Provider<CartSummary>((Ref ref) {
  final CartState cart = ref.watch(cartProvider);
  return CartSummary(
    subtotal: cart.subtotal,
    discount: cart.discountCents,
    total: cart.total,
    costTotal: cart.costTotal,
    profit: cart.profit,
    itemCount: cart.itemCount,
    hasUnknownCost: cart.hasUnknownCost,
  );
});

class CartSummary {
  const CartSummary({
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.costTotal = 0,
    this.profit = 0,
    this.itemCount = 0,
    this.hasUnknownCost = false,
  });

  final int subtotal;
  final int discount;
  final int total;
  final int costTotal;
  final int profit;
  final int itemCount;
  final bool hasUnknownCost;

  bool get isEmpty => itemCount == 0;
}

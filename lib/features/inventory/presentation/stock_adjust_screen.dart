import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../models/product.dart';
import '../../../providers/repository_providers.dart';
import 'inventory_screen.dart';

/// Ajuste de stock a un valor absoluto: conteo físico, merma, corrección
/// (§21). Se llega desde el detalle de un producto.
class StockAdjustScreen extends ConsumerWidget {
  const StockAdjustScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Product? product = ref.watch(productRepositoryProvider).byId(productId);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustar stock')),
        body: const EmptyState(
          title: 'Producto no encontrado',
          message: 'Puede que se haya eliminado del catálogo.',
          icon: Icons.search_off,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar stock')),
      body: SingleChildScrollView(
        child: StockEntrySheet(product: product, mode: StockMode.ajuste),
      ),
    );
  }
}

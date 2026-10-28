import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/category.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/product_repository.dart';

/// Categorías de producto. Se usan para organizar y para buscar (§18, §40).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Category? item]) async {
    final ({String name, int color})? result = await showDialog<
      ({String name, int color})
    >(context: context, builder: (BuildContext ctx) => CategoryDialog(category: item));
    if (result == null || !context.mounted) return;
    try {
      final ProductRepository repo = ref.read(productRepositoryProvider);
      if (item == null) {
        await repo.createCategory(result.name, colorValue: result.color);
      } else {
        item
          ..name = result.name
          ..colorValue = result.color;
        await repo.updateCategory(item);
      }
      if (!context.mounted) return;
      showToast(context, item == null ? 'Categoría creada' : 'Categoría actualizada');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category item) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Eliminar "${item.name}"',
      message: 'Los productos de esta categoría quedarán sin categoría. '
          'Los productos no se borran.',
      confirmLabel: 'Eliminar',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(productRepositoryProvider).deleteCategory(item.id);
      if (!context.mounted) return;
      showToast(context, 'Categoría eliminada');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Category>> async = ref.watch(categoriesProvider);
    final AsyncValue<List<dynamic>> products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Categoría'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
        data: (List<Category> list) {
          if (list.isEmpty) {
            return EmptyState(
              title: 'Sin categorías',
              message: 'Agrupa tus productos (Ropa, Comida, Accesorios…) '
                  'para encontrarlos más rápido.',
              icon: Icons.category_outlined,
              actionLabel: 'Crear categoría',
              onAction: () => _edit(context, ref),
            );
          }
          final Map<String, int> countByCategory = <String, int>{};
          for (final dynamic p in products.asData?.value ?? const <dynamic>[]) {
            final String? id = p.categoryId as String?;
            if (id == null) continue;
            countByCategory[id] = (countByCategory[id] ?? 0) + 1;
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (BuildContext context, int i) {
              final Category c = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        c.colorValue == 0
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Color(c.colorValue).withValues(alpha: 0.2),
                    child: Icon(
                      Icons.category_outlined,
                      color:
                          c.colorValue == 0
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Color(c.colorValue),
                      size: 20,
                    ),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    '${countByCategory[c.id] ?? 0} '
                    '${(countByCategory[c.id] ?? 0) == 1 ? 'producto' : 'productos'}',
                  ),
                  onTap: () => _edit(context, ref, c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, c),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Diálogo de alta/edición de categoría. Vive aquí y no dentro de otra
/// pantalla porque el formulario de producto también lo abre para crear una
/// categoría y asignarla sin salir del alta.
class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.category});

  final Category? category;

  @override
  State<CategoryDialog> createState() => CategoryDialogState();
}

class CategoryDialogState extends State<CategoryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  static const List<Color> _palette = <Color>[
    Color(0xFFD32F2F),
    Color(0xFFF57C00),
    Color(0xFF388E3C),
    Color(0xFF1976D2),
    Color(0xFF512DA8),
    Color(0xFF00838F),
  ];
  late Color _color = _palette.first;

  @override
  void initState() {
    super.initState();
    if (widget.category != null && widget.category!.colorValue != 0) {
      _color = Color(widget.category!.colorValue);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: const InputDecoration(labelText: 'Nombre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (final Color c in _palette)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: c == _color
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              _name.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      (name: _name.text.trim(), color: _color.toARGB32()),
                    ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

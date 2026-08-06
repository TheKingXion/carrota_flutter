import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "app_store.dart";
import "models.dart";
import "theme.dart";
import "widgets.dart";

void showProductSheet(BuildContext context, AppStore store, String id) {
  final product = store.productById(id);
  if (product == null) return;
  showCarrotaSheet(
    context,
    _ProductSheet(store: store, product: product),
  );
}

void showShoppingSheet(BuildContext context, AppStore store) {
  showCarrotaSheet(context, _ShoppingSheet(store: store));
}

void showDeliverySheet(
  BuildContext context,
  AppStore store, {
  String? initialProductId,
}) {
  showCarrotaSheet(
    context,
    _DeliverySheet(store: store, initialProductId: initialProductId),
  );
}

void showClosingSheet(BuildContext context, AppStore store) {
  showCarrotaSheet(context, _ClosingSheet(store: store));
}

void showComingSoon(BuildContext context, String feature) {
  showCarrotaSheet(
    context,
    SheetScaffold(
      title: feature,
      child: Column(
        children: [
          const LumoMark(size: 58),
          const SizedBox(height: 18),
          Text(
            "$feature estará disponible próximamente.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            "Por ahora puedes escribirle a Lumo y usar todos los flujos manuales.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Entendido"),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductSheet extends StatelessWidget {
  const _ProductSheet({required this.store, required this.product});

  final AppStore store;
  final Product product;

  Future<void> _changePrice(BuildContext context) async {
    final controller = TextEditingController(
      text: AppStore.number(product.price),
    );
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cambiar precio"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: "\$ "),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(",", ".")),
            ),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
    controller.dispose();
    if (price != null && price > 0) store.updatePrice(product.id, price);
  }

  @override
  Widget build(BuildContext context) {
    final days = product.stock / product.averageDaily;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => SheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [primarySoft, Color(0xFFE7F3F6)],
                ),
              ),
              child: Text(product.emoji, style: const TextStyle(fontSize: 68)),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        "Proveedor · ${product.supplier}",
                        style: const TextStyle(color: mutedInk),
                      ),
                    ],
                  ),
                ),
                Text(
                  AppStore.money(product.price),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SmallMetric(
                    label: "Stock",
                    value: "${AppStore.number(product.stock)} ${product.unit}",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallMetric(
                    label: "Ventas/día",
                    value: AppStore.number(product.averageDaily),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallMetric(
                    label: "Alcance",
                    value: "${days.toStringAsFixed(1)} d",
                    warning: days < 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text("Agregar a compra"),
                  onPressed: () {
                    store.addToShopping(
                      product.id,
                      product.averageDaily * 2,
                      reason: "Reposición manual",
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Agregado a la compra")),
                    );
                  },
                ),
                ActionChip(
                  label: const Text("Cambiar precio"),
                  onPressed: () => _changePrice(context),
                ),
                ActionChip(
                  label: const Text("Registrar llegada"),
                  onPressed: () {
                    Navigator.pop(context);
                    showDeliverySheet(
                      context,
                      store,
                      initialProductId: product.id,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: warning ? amberSoft : surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: warning ? amber : ink,
              ),
            ),
          ],
        ),
      );
}

class _DeliverySheet extends StatefulWidget {
  const _DeliverySheet({required this.store, this.initialProductId});

  final AppStore store;
  final String? initialProductId;

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  final supplier = TextEditingController(text: "Huerto Norte");
  final quantity = TextEditingController();
  late String productId =
      widget.initialProductId ?? widget.store.products.first.id;
  String? error;

  @override
  void dispose() {
    supplier.dispose();
    quantity.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(quantity.text.replaceAll(",", "."));
    if (supplier.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => error = "Completa proveedor y una cantidad válida.");
      return;
    }
    widget.store.receiveDelivery(
      supplier: supplier.text.trim(),
      lines: [SaleLine(productId: productId, quantity: amount)],
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.productById(productId)!;
    return SheetScaffold(
      title: "Recibir mercadería",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumoMark(size: 24),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Registra una llegada manual. El stock cambiará al confirmar.",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: supplier,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: "Proveedor"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: productId,
            decoration: const InputDecoration(labelText: "Producto"),
            items: widget.store.products
                .map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text("${product.emoji}  ${product.name}"),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => productId = value ?? productId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Cantidad",
              suffixText: selected.unit,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text("Agregar al inventario"),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingSheet extends StatelessWidget {
  const _ShoppingSheet({required this.store});

  final AppStore store;

  String _shareText() {
    final lines = store.shopping.where((entry) => entry.selected).map((entry) {
      final product = store.productById(entry.productId)!;
      return "• ${product.name}: ${AppStore.number(entry.quantity)} ${product.unit}";
    });
    return "Compra sugerida para ${store.businessName}\n${lines.join("\n")}";
  }

  Future<void> _editQuantity(
    BuildContext context,
    ShoppingEntry entry,
  ) async {
    final controller = TextEditingController(
      text: AppStore.number(entry.quantity),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cambiar cantidad"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(",", ".")),
            ),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount != null && amount > 0) {
      store.updateShoppingQuantity(entry.productId, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => SheetScaffold(
        title: "Compra sugerida",
        child: Column(
          children: [
            if (store.shopping.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text("La lista está vacía."),
              ),
            ...store.shopping.map((entry) {
              final product = store.productById(entry.productId)!;
              return CheckboxListTile(
                value: entry.selected,
                onChanged: (value) =>
                    store.toggleShopping(entry.productId, value ?? false),
                title: Row(
                  children: [
                    Text(product.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(product.name)),
                  ],
                ),
                subtitle: Text(entry.reason),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                secondary: IconButton(
                  tooltip: "Editar cantidad",
                  onPressed: () => _editQuantity(context, entry),
                  icon: const Icon(Icons.edit_outlined),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      store.saveShoppingList();
                      Navigator.pop(context);
                    },
                    child: const Text("Guardar lista"),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _shareText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Lista copiada")),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text("Copiar"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingSheet extends StatefulWidget {
  const _ClosingSheet({required this.store});

  final AppStore store;

  @override
  State<_ClosingSheet> createState() => _ClosingSheetState();
}

class _ClosingSheetState extends State<_ClosingSheet> {
  final counted = TextEditingController();
  var done = false;

  @override
  void dispose() {
    counted.dispose();
    super.dispose();
  }

  void _close() {
    final amount = double.tryParse(counted.text.replaceAll(",", "."));
    if (amount == null) return;
    widget.store.closeDay(amount);
    setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SheetScaffold(
      title: "Cierre del día",
      child: done
          ? Column(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: primarySoft,
                  child: Icon(Icons.check, size: 30, color: primary),
                ),
                const SizedBox(height: 14),
                Text(
                  "Cierre guardado. Diferencia de caja: "
                  "${AppStore.money(store.cashDifference)}.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Listo"),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LumoMark(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Preparé el cierre de ${store.businessName}.",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SmallMetric(
                        label: "Ventas",
                        value: AppStore.money(store.salesToday),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallMetric(
                        label: "Operaciones",
                        value: "${store.operationsToday}",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SmallMetric(
                        label: "Efectivo",
                        value: AppStore.money(store.expectedCash),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallMetric(
                        label: "Tarjeta",
                        value: AppStore.money(
                          store.paymentTotal(PaymentMethod.tarjeta),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Deberías tener ${AppStore.money(store.expectedCash)} en efectivo. ¿Cuánto contaste?",
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: counted,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(prefixText: "\$ ", hintText: "0"),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: counted.text.trim().isEmpty ? null : _close,
                    child: const Text("Cerrar el día"),
                  ),
                ),
              ],
            ),
    );
  }
}

import "package:flutter/material.dart";

import "ai_service.dart";
import "app_store.dart";
import "models.dart";
import "theme.dart";
import "widgets.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onOpenProduct,
    required this.onOpenDelivery,
    required this.onOpenClosing,
  });

  final AppStore store;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onOpenDelivery;
  final VoidCallback onOpenClosing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              const LumoMark(size: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.businessName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const Text(
                    "Jueves, 30 de julio",
                    style: TextStyle(fontSize: 10.5, color: mutedInk),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: hairline),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Alertas"),
                      content: store.lowStockProducts.isEmpty
                          ? const Text("No hay alertas pendientes.")
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: store.lowStockProducts
                                  .map(
                                    (product) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Text(product.emoji),
                                      title: Text(product.name),
                                      subtitle: Text(
                                        "Stock: ${AppStore.number(product.stock)} ${product.unit}",
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cerrar"),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryDark,
                child: Text(
                  store.ownerName.isEmpty
                      ? "?"
                      : store.ownerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineLarge,
              children: [
                const TextSpan(
                  text: "Buenos días, ",
                  style: TextStyle(
                    color: primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(text: "${store.ownerName}."),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE2F4E9), Color(0xFFF7FBF8)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCFE7D8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 19,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resumen del negocio",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: primaryDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Llevas ${AppStore.money(store.salesToday)} en "
                        "${store.operationsToday} operaciones. Hay "
                        "${store.lowStockProducts.length} productos que necesitan atención.",
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: "Ventas hoy",
                    value: AppStore.money(store.salesToday),
                    subtitle: "${store.operationsToday} operaciones",
                    success: true)),
            const SizedBox(width: 10),
            Expanded(
                child: MetricCard(
                    label: "Caja",
                    value: store.dayClosed ? "Día cerrado" : "Abierta",
                    subtitle:
                        "Efectivo ${AppStore.money(store.expectedCash)}")),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: "Inventario",
                    value: "${store.lowStockProducts.length} productos",
                    subtitle: store.lowStockProducts.isEmpty
                        ? "Stock saludable"
                        : "${store.lowStockProducts.first.name} requiere atención",
                    warning: store.lowStockProducts.isNotEmpty)),
            const SizedBox(width: 10),
            Expanded(
                child: MetricCard(
                    label: "IA",
                    value: store.lastAiProvider ?? store.aiProvider.label,
                    subtitle: store.lastAiModel ?? "Lista para responder",
                    success: store.lastAiProvider != null)),
          ]),
          const SizedBox(height: 20),
          const SectionLabel("Sugerencias"),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _ActionChip(
                  label: "Registrar una venta",
                  onTap: () => store
                      .send("Vendí dos tomates, una lechuga y tres cilantro")),
              _ActionChip(label: "Recibir mercadería", onTap: onOpenDelivery),
              _ActionChip(
                  label: "Ver qué falta",
                  onTap: () => store.send("¿Qué falta?")),
              _ActionChip(label: "Preparar el cierre", onTap: onOpenClosing),
            ]),
          ),
          if (store.chat.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...store.chat.map((message) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChatMessageCard(
                      store: store,
                      message: message,
                      onOpenProduct: onOpenProduct),
                )),
          ],
          if (store.isAiThinking) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                LumoMark(size: 22),
                SizedBox(width: 10),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text("Lumo está pensando…"),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const SectionLabel("Atención"),
          const SizedBox(height: 8),
          if (store.lowStockProducts.isNotEmpty)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onOpenProduct(store.lowStockProducts.first.id),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(children: [
                    Text(store.lowStockProducts.first.emoji,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(store.lowStockProducts.first.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              "Quedan ${AppStore.number(store.lowStockProducts.first.stock)} "
                              "${store.lowStockProducts.first.unit}",
                              style: const TextStyle(
                                  fontSize: 12, color: mutedInk)),
                        ])),
                    const Icon(Icons.chevron_right, color: mutedInk),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              "🌿  Powered by Business OS",
              style: TextStyle(fontSize: 10.5, color: mutedInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
            avatar: const Icon(Icons.auto_awesome, size: 16, color: primary),
            label: Text(label),
            onPressed: onTap),
      );
}

class ChatMessageCard extends StatelessWidget {
  const ChatMessageCard(
      {super.key,
      required this.store,
      required this.message,
      required this.onOpenProduct});
  final AppStore store;
  final ChatMessage message;
  final ValueChanged<String> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(5),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18))),
          child: Text(message.text ?? "",
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
          padding: EdgeInsets.only(top: 4), child: LumoMark(size: 22)),
      const SizedBox(width: 9),
      Expanded(child: _assistantContent(context)),
    ]);
  }

  Widget _assistantContent(BuildContext context) {
    switch (message.type) {
      case MessageType.sale:
        return _saleCard(context);
      case MessageType.impact:
      case MessageType.receipt:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message.text ?? "",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              ...message.items.map((item) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 16, color: primary),
                      const SizedBox(width: 7),
                      Expanded(child: Text(item))
                    ]),
                  )),
            ]),
          ),
        );
      case MessageType.insight:
        return Card(
          child: InkWell(
            onTap: () => onOpenProduct(message.productId ?? "lechuga"),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TagChip("Sugerencia de Lumo", tone: TagTone.ai),
                    const SizedBox(height: 9),
                    Text(message.text ?? ""),
                    ...message.items.map((item) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(item,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, color: primary)))),
                  ]),
            ),
          ),
        );
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text ?? "",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (message.aiProvider != null) ...[
                const SizedBox(height: 6),
                TagChip(
                  "${message.aiProvider} · ${message.aiModel}",
                  tone: TagTone.ai,
                ),
              ],
            ],
          ),
        );
      case MessageType.user:
        return const SizedBox.shrink();
    }
  }

  Widget _saleCard(BuildContext context) {
    final sale = message.sale!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text("Entendí esta venta",
                    style: TextStyle(fontWeight: FontWeight.w700))),
            TagChip(message.confirmed ? "Registrada" : "Por confirmar",
                tone: message.confirmed ? TagTone.ok : TagTone.ai),
          ]),
          const SizedBox(height: 10),
          ...sale.lines.map((line) {
            final product = store.productById(line.productId)!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text(product.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(
                        "${AppStore.number(line.quantity)} ${product.unit} · ${product.name}")),
                Text(AppStore.money(product.price * line.quantity),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            );
          }),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Total", style: TextStyle(color: mutedInk)),
            Text(AppStore.money(sale.total),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          if (!message.confirmed) ...[
            const SizedBox(height: 10),
            const Text("¿Cómo pagó?",
                style: TextStyle(fontSize: 12, color: mutedInk)),
            const SizedBox(height: 6),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: PaymentMethod.values.map((method) {
                  return ActionChip(
                      label: Text(AppStore.paymentLabel(method)),
                      onPressed: () => _choosePayment(context, method));
                }).toList()),
          ],
        ]),
      ),
    );
  }

  Future<void> _choosePayment(
      BuildContext context, PaymentMethod method) async {
    if (method != PaymentMethod.tarjeta) {
      store.confirmSale(message, method);
      return;
    }
    final controller = TextEditingController();
    final authorization = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Código de autorización"),
        content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Ej. 683194")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Registrar")),
        ],
      ),
    );
    controller.dispose();
    if (authorization != null && authorization.isNotEmpty) {
      store.confirmSale(message, method, authorization: authorization);
    }
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen(
      {super.key, required this.store, required this.onOpenClosing});
  final AppStore store;
  final VoidCallback onOpenClosing;

  @override
  Widget build(BuildContext context) {
    const heights = [12.0, 20, 15, 28, 36, 60, 78, 84, 62, 40, 30, 22];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel("Hoy"),
          const SizedBox(height: 6),
          Text("Así va ${store.businessName} hoy",
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            "Vendiste ${AppStore.money(store.salesToday)} en "
            "${store.operationsToday} operaciones.",
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel("Ingresos"),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(AppStore.money(store.salesToday),
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const TagChip("Datos de demo", tone: TagTone.ai)
                    ]),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 96,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: heights
                              .map((height) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: FractionallySizedBox(
                                          heightFactor: height / 84,
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                              decoration: BoxDecoration(
                                                  color: primary.withValues(
                                                      alpha:
                                                          .35 + height / 150),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          6)))),
                                    ),
                                  ))
                              .toList()),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("8:00"),
                          Text("12:00"),
                          Text("16:00"),
                          Text("20:00")
                        ]),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: "Pagos",
                    value: AppStore.money(store.expectedCash),
                    subtitle:
                        "Tarjeta ${AppStore.money(store.paymentTotal(PaymentMethod.tarjeta))}")),
            const SizedBox(width: 10),
            Expanded(
                child: MetricCard(
                    label: "Más vendido",
                    value: "${store.topProduct.emoji} ${store.topProduct.name}",
                    subtitle:
                        "${AppStore.number(store.topProductQuantity())} ${store.topProduct.unit}",
                    success: true)),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      TagChip("Resumen", tone: TagTone.ai),
                      SizedBox(width: 8),
                      Text("Lumo observa",
                          style: TextStyle(fontWeight: FontWeight.w600))
                    ]),
                    const SizedBox(height: 9),
                    Text(
                      "${store.topProduct.name} lidera las ventas. "
                      "${store.lowStockProducts.length} productos necesitan reposición.",
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: onOpenClosing,
              leading: const CircleAvatar(
                  backgroundColor: primarySoft, child: Text("🌙")),
              title: const Text("Preparar el cierre del día"),
              subtitle: const Text("Confirma efectivo y revisa pendientes"),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel("Actividad reciente"),
          const SizedBox(height: 8),
          ...store.timeline.take(5).map((event) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Text(event.time,
                    style: const TextStyle(fontSize: 12, color: mutedInk)),
                title: Text(event.title),
                subtitle: event.detail.isEmpty ? null : Text(event.detail),
                trailing: event.tag.isEmpty ? null : TagChip(event.tag),
              )),
        ],
      ),
    );
  }
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  var query = "";

  Future<void> _editMemory(MemoryEvent memory) async {
    final title = TextEditingController(text: memory.title);
    final detail = TextEditingController(text: memory.detail);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Corregir recuerdo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: "Título")),
            const SizedBox(height: 10),
            TextField(
                controller: detail,
                decoration: const InputDecoration(labelText: "Detalle")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Guardar")),
        ],
      ),
    );
    if (save == true && title.text.trim().isNotEmpty) {
      widget.store
          .updateMemory(memory.id, title.text.trim(), detail.text.trim());
    }
    title.dispose();
    detail.dispose();
  }

  Future<void> _forgetMemory(MemoryEvent memory) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Olvidar este dato"),
        content: const Text("Este recuerdo se eliminará de la demo."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Olvidar")),
        ],
      ),
    );
    if (confirm == true) widget.store.forgetMemory(memory.id);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.store.memories
        .where((memory) =>
            query.isEmpty ||
            "${memory.title} ${memory.detail}"
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();
    final groups = <String, List<MemoryEvent>>{};
    for (final memory in filtered) {
      groups.putIfAbsent(memory.group, () => []).add(memory);
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel("Memoria"),
          const SizedBox(height: 6),
          Text("Lo que Lumo recuerda de ${widget.store.businessName}",
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Pregunta sobre la historia del negocio…"),
          ),
          const SizedBox(height: 16),
          for (final entry in groups.entries) ...[
            SectionLabel(entry.key),
            const SizedBox(height: 8),
            ...entry.value.map((memory) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              TagChip(memory.kind,
                                  tone: memory.kind == "Registrado"
                                      ? TagTone.ok
                                      : TagTone.ai),
                              const SizedBox(width: 8),
                              Text(memory.when,
                                  style: Theme.of(context).textTheme.bodySmall)
                            ]),
                            const SizedBox(height: 7),
                            Text(memory.title),
                            if (memory.detail.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(memory.detail,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                            const SizedBox(height: 7),
                            Wrap(spacing: 4, children: [
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Evidencia"),
                                    content: Text(
                                      "${memory.when}\n\n${memory.detail.isEmpty ? "Registrado manualmente en Carrota." : memory.detail}",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Cerrar"),
                                      ),
                                    ],
                                  ),
                                ),
                                child: const Text("Evidencia"),
                              ),
                              TextButton(
                                onPressed: () => _editMemory(memory),
                                child: const Text("Corregir"),
                              ),
                              TextButton(
                                onPressed: () => _forgetMemory(memory),
                                child: const Text("Olvidar"),
                              ),
                            ]),
                          ]),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (filtered.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text("No encontré recuerdos con esa búsqueda."))),
        ],
      ),
    );
  }
}

class BusinessScreen extends StatelessWidget {
  const BusinessScreen(
      {super.key,
      required this.store,
      required this.onOpenProduct,
      required this.onOpenShopping});
  final AppStore store;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onOpenShopping;

  Future<void> _editProfile(BuildContext context) async {
    final current = store.profile;
    if (current == null) return;
    final owner = TextEditingController(text: current.ownerName);
    final business = TextEditingController(text: current.businessName);
    final type = TextEditingController(text: current.businessType);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Información del negocio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: owner,
                decoration: const InputDecoration(labelText: "Responsable")),
            const SizedBox(height: 9),
            TextField(
                controller: business,
                decoration: const InputDecoration(labelText: "Negocio")),
            const SizedBox(height: 9),
            TextField(
                controller: type,
                decoration: const InputDecoration(labelText: "Tipo")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Guardar")),
        ],
      ),
    );
    if (save == true &&
        owner.text.trim().isNotEmpty &&
        business.text.trim().isNotEmpty &&
        type.text.trim().isNotEmpty) {
      store.updateProfile(
        current.copyWith(
          ownerName: owner.text.trim(),
          businessName: business.text.trim(),
          businessType: type.text.trim(),
        ),
      );
    }
    owner.dispose();
    business.dispose();
    type.dispose();
  }

  void _showInfo(BuildContext context, String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel("Negocio"),
          const SizedBox(height: 6),
          Text(store.businessName,
              style: Theme.of(context).textTheme.headlineMedium),
          Text(store.businessType, style: const TextStyle(color: mutedInk)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(children: [
                Expanded(child: _Info(label: "Moneda", value: store.currency)),
                Expanded(
                  child: _Info(
                    label: "Datos",
                    value: store.persistenceReady ? "SQLite" : "Temporal",
                  ),
                ),
                const Expanded(child: _Info(label: "Memoria", value: "Activa")),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel("Inteligencia artificial"),
          const SizedBox(height: 8),
          _AiSettings(store: store),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const SectionLabel("Productos"),
            TextButton(
                onPressed: onOpenShopping,
                child: const Text("Compra sugerida →")),
          ]),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
                children: store.products.map((product) {
              final low = product.stock <= product.averageDaily;
              return ListTile(
                onTap: () => onOpenProduct(product.id),
                leading:
                    Text(product.emoji, style: const TextStyle(fontSize: 25)),
                title: Text(product.name),
                subtitle: Text(
                    "${AppStore.number(product.stock)} ${product.unit}${low ? " · atención" : ""}",
                    style: TextStyle(color: low ? amber : mutedInk)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(AppStore.money(product.price),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right)
                ]),
              );
            }).toList()),
          ),
          const SizedBox(height: 18),
          const SectionLabel("Proactividad"),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              _SettingSwitch(
                value: store.proactiveSettings["lowStock"] ?? true,
                onChanged: (value) => store.updateSetting("lowStock", value),
                label: "Avísame cuando un producto pueda agotarse.",
              ),
              _SettingSwitch(
                  value: store.proactiveSettings["incompleteSales"] ?? true,
                  onChanged: (value) =>
                      store.updateSetting("incompleteSales", value),
                  label: "Recuérdame ventas incompletas."),
              _SettingSwitch(
                value: store.proactiveSettings["salesChanges"] ?? false,
                onChanged: (value) =>
                    store.updateSetting("salesChanges", value),
                label: "Muéstrame cambios importantes en ventas.",
              ),
              _SettingSwitch(
                  value: store.proactiveSettings["dailySummary"] ?? true,
                  onChanged: (value) =>
                      store.updateSetting("dailySummary", value),
                  label: "Envíame un resumen al cerrar el día."),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionLabel("Ajustes"),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                  onTap: () => _editProfile(context),
                  title: const Text("Información del negocio"),
                  trailing: const Icon(Icons.chevron_right)),
              ListTile(
                  onTap: () => _showInfo(context, "Métodos de pago",
                      "La demo admite efectivo, tarjeta, transferencia y pago combinado."),
                  title: const Text("Métodos de pago"),
                  trailing: const Icon(Icons.chevron_right)),
              ListTile(
                  onTap: () => _showInfo(context, "Colaboradores",
                      "Esta demo usa un único perfil local: ${store.ownerName}."),
                  title: const Text("Colaboradores"),
                  trailing: const Icon(Icons.chevron_right)),
              ListTile(
                  onTap: () => _showInfo(context, "Datos y privacidad",
                      "Los datos del negocio son mock y viven en memoria. Las claves de OpenAI y DeepSeek permanecen en el backend, nunca en la app."),
                  title: const Text("Datos y privacidad"),
                  trailing: const Icon(Icons.chevron_right)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(label),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600))
      ]);
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontSize: 14)));
}

class _AiSettings extends StatefulWidget {
  const _AiSettings({required this.store});

  final AppStore store;

  @override
  State<_AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<_AiSettings> {
  AiHealth? health;
  var checking = false;

  Future<void> _check() async {
    setState(() => checking = true);
    final result = await widget.store.checkAiHealth();
    if (mounted) {
      setState(() {
        health = result;
        checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final status = health == null
        ? "Comprueba el backend antes de la demo."
        : !health!.reachable
            ? "Backend sin conexión"
            : "OpenAI ${health!.openaiConfigured ? "lista" : "sin clave"} · "
                "DeepSeek ${health!.deepseekConfigured ? "lista" : "sin clave"}";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Proveedor de respuestas",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<AiProviderChoice>(
              segments: AiProviderChoice.values
                  .map(
                    (provider) => ButtonSegment(
                      value: provider,
                      label: Text(
                        provider == AiProviderChoice.automatic
                            ? "Auto"
                            : provider.label,
                      ),
                    ),
                  )
                  .toList(),
              selected: {store.aiProvider},
              onSelectionChanged: (selection) =>
                  store.setAiProvider(selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 10),
            Text(status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: checking ? null : _check,
              icon: checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: const Text("Probar conexión"),
            ),
          ],
        ),
      ),
    );
  }
}

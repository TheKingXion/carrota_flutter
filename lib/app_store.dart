import "dart:async";

import "package:flutter/foundation.dart";

import "local_database.dart";
import "local_response_engine.dart";
import "models.dart";

class AppStore extends ChangeNotifier {
  AppStore({
    this.persistence,
    LocalResponseEngine? responseEngine,
  }) : responseEngine = responseEngine ?? const LocalResponseEngine() {
    _seedSales();
    shopping.addAll([
      ShoppingEntry(
        productId: "lechuga",
        quantity: 12,
        reason: "Cubre aproximadamente 2 días",
      ),
      ShoppingEntry(
        productId: "cilantro",
        quantity: 10,
        reason: "Stock actual crítico",
      ),
      ShoppingEntry(
        productId: "tomate",
        quantity: 30,
        reason: "Cubre aproximadamente 3 días",
      ),
    ]);
    addListener(_queuePersistence);
  }

  BusinessProfile? profile;
  final LocalResponseEngine responseEngine;
  final StatePersistence? persistence;
  bool initialized = false;
  bool persistenceReady = false;
  String? persistenceError;
  bool _persistenceEnabled = false;
  Future<void> _saveQueue = Future<void>.value();
  bool isResponding = false;
  bool dayClosed = false;
  final Set<String> likedFeedProducts = {};
  final Set<String> savedFeedProducts = {};
  final Map<String, int> feedLikeCounts = {
    "tomate": 18,
    "lechuga": 31,
    "zanahoria": 24,
    "cilantro": 15,
    "espinaca": 27,
  };
  final Map<String, List<String>> feedCommentsByProduct = {
    "tomate": [
      "¿Tienen entrega disponible hoy?",
      "Me interesa saber el precio por mayor.",
    ],
    "lechuga": ["Se ve muy fresca, ¿cuánto cuesta la caja?"],
    "zanahoria": ["¿Venden por kilo y por saco?"],
    "cilantro": ["¿Hay entrega temprano mañana?"],
    "espinaca": ["¿Cuánto dura refrigerada?"],
  };
  double? countedCash;

  Future<void> initialize() async {
    if (initialized) return;
    try {
      final saved = await persistence?.load();
      if (saved != null) _restoreSnapshot(saved);
      persistenceReady = persistence != null;
      _persistenceEnabled = persistence != null;
    } catch (error) {
      persistenceError = error.toString();
      persistenceReady = false;
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> flushPersistence() => _saveQueue;

  void _queuePersistence() {
    final target = persistence;
    if (!_persistenceEnabled || target == null) return;
    final snapshot = _createSnapshot();
    _saveQueue = _saveQueue.then((_) => target.save(snapshot)).catchError(
      (Object error) {
        persistenceError = error.toString();
        persistenceReady = false;
      },
    );
  }

  final Map<String, bool> proactiveSettings = {
    "lowStock": true,
    "incompleteSales": true,
    "salesChanges": false,
    "dailySummary": true,
  };

  final List<Product> products = [
    Product(
      id: "tomate",
      name: "Tomate saladet",
      unit: "kg",
      price: 30,
      stock: 42,
      emoji: "🍅",
      supplier: "Huerto Norte",
      averageDaily: 12,
    ),
    Product(
      id: "lechuga",
      name: "Lechuga italiana",
      unit: "pieza",
      price: 28,
      stock: 4,
      emoji: "🥬",
      supplier: "Huerto Norte",
      averageDaily: 6,
    ),
    Product(
      id: "zanahoria",
      name: "Zanahoria",
      unit: "kg",
      price: 20,
      stock: 18,
      emoji: "🥕",
      supplier: "Milpa Verde",
      averageDaily: 5,
    ),
    Product(
      id: "cilantro",
      name: "Cilantro",
      unit: "manojo",
      price: 12,
      stock: 3,
      emoji: "🌿",
      supplier: "Milpa Verde",
      averageDaily: 8,
    ),
    Product(
      id: "espinaca",
      name: "Espinaca",
      unit: "bolsa",
      price: 28,
      stock: 14,
      emoji: "🥗",
      supplier: "Huerto Norte",
      averageDaily: 6,
    ),
    Product(
      id: "aguacate",
      name: "Aguacate",
      unit: "kg",
      price: 55,
      stock: 22,
      emoji: "🥑",
      supplier: "Milpa Verde",
      averageDaily: 4,
    ),
    Product(
      id: "limon",
      name: "Limón",
      unit: "kg",
      price: 32,
      stock: 30,
      emoji: "🍋",
      supplier: "Cítricos del Bajío",
      averageDaily: 7,
    ),
    Product(
      id: "mermelada",
      name: "Mermelada artesanal",
      unit: "frasco",
      price: 95,
      stock: 12,
      emoji: "🍯",
      supplier: "Taller La Abeja",
      averageDaily: 2,
    ),
  ];

  final List<Sale> sales = [];
  final List<ChatMessage> chat = [];
  final List<ShoppingEntry> shopping = [];
  final List<CartItem> cart = [];

  final List<MemoryEvent> memories = [
    const MemoryEvent(
      id: "m1",
      group: "Hoy",
      when: "09:20",
      title: "Revisaste el inventario al iniciar el día.",
      detail: "Se encontraron dos productos con stock bajo.",
      kind: "Registrado",
    ),
    const MemoryEvent(
      id: "m2",
      group: "Hace 2 días",
      when: "hace 2 días",
      title: "Cambiaste el precio de la lechuga de \$25 a \$28.",
      detail: "El cambio se aplicó a las ventas siguientes.",
      kind: "Registrado",
    ),
    const MemoryEvent(
      id: "m3",
      group: "La semana pasada",
      when: "la semana pasada",
      title: "Las ventas de cilantro aumentaron 18 %.",
      detail: "Comparado con la semana anterior.",
      kind: "Calculado",
    ),
  ];

  final List<TimelineEvent> timeline = [
    const TimelineEvent(
      id: "t1",
      time: "16:38",
      title: "Venta con tarjeta por \$280.",
      detail: "Autorización: 683194.",
      tag: "Venta",
    ),
    const TimelineEvent(
      id: "t2",
      time: "14:20",
      title: "El precio de la lechuga cambió de \$25 a \$28.",
      tag: "Precio",
    ),
    const TimelineEvent(
      id: "t3",
      time: "11:05",
      title: "El cilantro llegó a nivel crítico.",
      tag: "Alerta",
    ),
  ];

  bool get onboarded => profile != null;
  String get ownerName => profile?.ownerName ?? "Usuario";
  String get businessName => profile?.businessName ?? "Mi negocio";
  String get businessType => profile?.businessType ?? "Negocio";
  String get currency => profile?.currency ?? "MXN";

  double get salesToday => sales.fold(0, (total, sale) => total + sale.total);
  int get operationsToday => sales.length;
  double get expectedCash => paymentTotal(PaymentMethod.efectivo);
  double get cashDifference =>
      countedCash == null ? 0 : countedCash! - expectedCash;

  int get cartItemCount => cart.fold<int>(
        0,
        (total, item) => total + item.quantity.round(),
      );

  double get cartTotal => cart.fold<double>(0, (total, item) {
        final product = productById(item.productId);
        return total + (product?.price ?? 0) * item.quantity;
      });

  List<Product> get lowStockProducts => products
      .where((product) => product.stock <= product.averageDaily)
      .toList();

  Product get topProduct {
    final quantities = <String, double>{};
    for (final sale in sales) {
      for (final line in sale.lines) {
        quantities[line.productId] =
            (quantities[line.productId] ?? 0) + line.quantity;
      }
    }
    return products.reduce((current, product) {
      final currentQty = quantities[current.id] ?? 0;
      final productQty = quantities[product.id] ?? 0;
      return productQty > currentQty ? product : current;
    });
  }

  double topProductQuantity() {
    return sales
        .expand((sale) => sale.lines)
        .where((line) => line.productId == topProduct.id)
        .fold(0, (total, line) => total + line.quantity);
  }

  double paymentTotal(PaymentMethod method) {
    return sales
        .where((sale) => sale.payment == method)
        .fold(0, (total, sale) => total + sale.total);
  }

  void completeOnboarding(BusinessProfile value) {
    profile = value;
    chat
      ..clear()
      ..add(
        ChatMessage(
          id: _id(),
          type: MessageType.text,
          text:
              "¡Listo, ${value.ownerName}! Ya configuré ${value.businessName}. "
              "Puedes registrar una venta, consultar inventario o preparar el cierre.",
        ),
      );
    notifyListeners();
  }

  void updateProfile(BusinessProfile value) {
    profile = value;
    memories.insert(
      0,
      MemoryEvent(
        id: _id(),
        group: "Hoy",
        when: _now(),
        title: "Actualizaste la información de ${value.businessName}.",
        detail: "${value.businessType} · ${value.currency}",
        kind: "Registrado",
      ),
    );
    notifyListeners();
  }

  Product? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    chat.add(ChatMessage(id: _id(), type: MessageType.user, text: text.trim()));
    notifyListeners();
  }

  Future<void> send(String input) async {
    final text = input.trim();
    if (text.isEmpty) return;

    chat.add(ChatMessage(id: _id(), type: MessageType.user, text: text));
    final normalized = _normalize(text);
    final isQuestion = text.contains("?") ||
        RegExp(r"^(como|cuanto|que|cual|dime|hay)\b").hasMatch(normalized);

    if (!isQuestion && RegExp(r"vend|cobr|venta").hasMatch(normalized)) {
      _handleSaleIntent(normalized);
    } else {
      notifyListeners();
      await _answerLocally(text);
      return;
    }

    notifyListeners();
  }

  Future<void> _answerLocally(String message) async {
    isResponding = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final reply = responseEngine.reply(
      message,
      LocalResponseContext(
        ownerName: ownerName,
        businessName: businessName,
        sales: money(salesToday),
        operations: operationsToday,
        expectedCash: money(expectedCash),
        lowStock: lowStockProducts.map((product) => product.name).toList(),
        topProduct: topProduct.name,
        shoppingItems: shopping.where((item) => item.selected).length,
        dayClosed: dayClosed,
      ),
    );
    chat.add(ChatMessage(id: _id(), type: MessageType.text, text: reply));
    isResponding = false;
    notifyListeners();
  }

  Map<String, Object?> businessSnapshot() {
    return {
      "owner": ownerName,
      "business": businessName,
      "business_type": businessType,
      "currency": currency,
      "today": {
        "sales_total": salesToday,
        "operations": operationsToday,
        "expected_cash": expectedCash,
        "day_closed": dayClosed,
      },
      "products": products
          .map(
            (product) => {
              "id": product.id,
              "name": product.name,
              "unit": product.unit,
              "price": product.price,
              "stock": product.stock,
              "supplier": product.supplier,
              "average_daily_sales": product.averageDaily,
            },
          )
          .toList(),
      "low_stock": lowStockProducts.map((product) => product.name).toList(),
      "recent_activity": timeline
          .take(8)
          .map(
            (event) => {
              "time": event.time,
              "title": event.title,
              "detail": event.detail,
            },
          )
          .toList(),
    };
  }

  void _handleSaleIntent(String normalized) {
    final parsed = _parseSale(normalized);
    if (parsed.foundProducts.isEmpty) {
      _reply("¿Qué producto vendiste?");
      return;
    }
    if (parsed.missingQuantity.isNotEmpty) {
      _reply(
        "¿Qué cantidad vendiste de ${parsed.missingQuantity.join(" y ")}?",
      );
      return;
    }

    final unavailable = parsed.lines.where((line) {
      final product = productById(line.productId);
      return product == null || line.quantity > product.stock;
    }).toList();
    if (unavailable.isNotEmpty) {
      final product = productById(unavailable.first.productId)!;
      _reply(
        "Solo hay ${number(product.stock)} ${product.unit} de ${product.name}. "
        "Indica una cantidad menor o registra una llegada.",
      );
      return;
    }

    final total = parsed.lines.fold<double>(
      0,
      (sum, line) =>
          sum + (productById(line.productId)?.price ?? 0) * line.quantity,
    );
    chat.add(
      ChatMessage(
        id: _id(),
        type: MessageType.sale,
        sale: Sale(
          id: _id(),
          lines: parsed.lines,
          total: total,
          time: _now(),
        ),
      ),
    );
  }

  void confirmSale(
    ChatMessage message,
    PaymentMethod method, {
    String? authorization,
  }) {
    final sale = message.sale;
    if (sale == null || message.confirmed) return;

    for (final line in sale.lines) {
      final product = productById(line.productId);
      if (product == null || line.quantity > product.stock) {
        _reply("El inventario cambió. Revisa la venta antes de confirmarla.");
        notifyListeners();
        return;
      }
    }

    sale.payment = method;
    sale.authorization = authorization;
    message.confirmed = true;
    sales.add(sale);

    for (final line in sale.lines) {
      final product = productById(line.productId)!;
      product.stock -= line.quantity;
    }

    timeline.insert(
      0,
      TimelineEvent(
        id: "tl-${sale.id}",
        time: sale.time,
        title: "Venta por ${money(sale.total)} (${paymentLabel(method)}).",
        detail: authorization == null ? "" : "Autorización: $authorization.",
        tag: "Venta",
      ),
    );
    memories.insert(
      0,
      MemoryEvent(
        id: "mem-${sale.id}",
        group: "Hoy",
        when: sale.time,
        title: "Registraste una venta de ${money(sale.total)}.",
        detail: sale.lines
            .map(
              (line) =>
                  "${number(line.quantity)} × ${productById(line.productId)?.name ?? ""}",
            )
            .join(", "),
        kind: "Registrado",
      ),
    );
    chat.add(
      ChatMessage(
        id: _id(),
        type: MessageType.impact,
        text: "La venta quedó registrada.",
        items: [
          "Venta por ${money(sale.total)}",
          "Inventario actualizado",
          "Pago con ${paymentLabel(method)}",
        ],
      ),
    );
    notifyListeners();
  }

  void receiveDelivery({
    required String supplier,
    required List<SaleLine> lines,
  }) {
    if (lines.isEmpty) return;
    for (final line in lines) {
      final product = productById(line.productId);
      if (product != null) product.stock += line.quantity;
    }
    final detail = lines
        .map(
          (line) =>
              "${productById(line.productId)?.name}: +${number(line.quantity)}",
        )
        .join(", ");
    timeline.insert(
      0,
      TimelineEvent(
        id: _id(),
        time: _now(),
        title: "Llegada de mercadería de $supplier.",
        detail: detail,
        tag: "Inventario",
      ),
    );
    memories.insert(
      0,
      MemoryEvent(
        id: _id(),
        group: "Hoy",
        when: _now(),
        title: "Registraste una llegada de $supplier.",
        detail: detail,
        kind: "Registrado",
      ),
    );
    chat.add(
      ChatMessage(
        id: _id(),
        type: MessageType.receipt,
        text: "Mercadería de $supplier agregada al inventario.",
        items: detail.split(", "),
      ),
    );
    notifyListeners();
  }

  void updatePrice(String productId, double price) {
    final product = productById(productId);
    if (product == null || price <= 0) return;
    final oldPrice = product.price;
    product.price = price;
    timeline.insert(
      0,
      TimelineEvent(
        id: _id(),
        time: _now(),
        title:
            "El precio de ${product.name} cambió de ${money(oldPrice)} a ${money(price)}.",
        tag: "Precio",
      ),
    );
    memories.insert(
      0,
      MemoryEvent(
        id: _id(),
        group: "Hoy",
        when: _now(),
        title: "Cambiaste el precio de ${product.name}.",
        detail: "${money(oldPrice)} → ${money(price)}",
        kind: "Registrado",
      ),
    );
    notifyListeners();
  }

  void addToShopping(String productId, double quantity, {String? reason}) {
    if (quantity <= 0 || productById(productId) == null) return;
    for (final entry in shopping) {
      if (entry.productId == productId) {
        entry.quantity = quantity;
        entry.selected = true;
        notifyListeners();
        return;
      }
    }
    shopping.add(
      ShoppingEntry(
        productId: productId,
        quantity: quantity,
        reason: reason ?? "Agregado manualmente",
      ),
    );
    notifyListeners();
  }

  void updateShoppingQuantity(String productId, double quantity) {
    if (quantity <= 0) return;
    final entry = shopping.where((item) => item.productId == productId).first;
    entry.quantity = quantity;
    notifyListeners();
  }

  void toggleShopping(String productId, bool selected) {
    final entry = shopping.where((item) => item.productId == productId).first;
    entry.selected = selected;
    notifyListeners();
  }

  void removeShopping(String productId) {
    shopping.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  double cartQuantityFor(String productId) {
    for (final item in cart) {
      if (item.productId == productId) return item.quantity;
    }
    return 0;
  }

  bool addToCart(String productId, {double quantity = 1}) {
    final product = productById(productId);
    if (product == null || quantity <= 0) return false;
    final next = cartQuantityFor(productId) + quantity;
    if (next > product.stock) return false;
    for (final item in cart) {
      if (item.productId == productId) {
        item.quantity = next;
        notifyListeners();
        return true;
      }
    }
    cart.add(CartItem(productId: productId, quantity: quantity));
    notifyListeners();
    return true;
  }

  bool updateCartQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return true;
    }
    final product = productById(productId);
    if (product == null || quantity > product.stock) return false;
    for (final item in cart) {
      if (item.productId == productId) {
        item.quantity = quantity;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void removeFromCart(String productId) {
    cart.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    if (cart.isEmpty) return;
    cart.clear();
    notifyListeners();
  }

  Sale? checkoutCart(PaymentMethod method) {
    if (cart.isEmpty) return null;
    for (final item in cart) {
      final product = productById(item.productId);
      if (product == null || item.quantity > product.stock) return null;
    }

    final lines = cart
        .map(
          (item) => SaleLine(
            productId: item.productId,
            quantity: item.quantity,
          ),
        )
        .toList();
    final sale = Sale(
      id: _id(),
      lines: lines,
      total: cartTotal,
      time: _now(),
      payment: method,
    );
    sales.add(sale);
    for (final line in lines) {
      productById(line.productId)!.stock -= line.quantity;
    }
    timeline.insert(
      0,
      TimelineEvent(
        id: "cart-${sale.id}",
        time: sale.time,
        title: "Pedido de la tienda por ${money(sale.total)}.",
        detail: "Pago de demostración con ${paymentLabel(method)}.",
        tag: "Tienda",
      ),
    );
    memories.insert(
      0,
      MemoryEvent(
        id: "cart-memory-${sale.id}",
        group: "Hoy",
        when: sale.time,
        title: "Confirmaste un pedido de ${money(sale.total)}.",
        detail: lines
            .map(
              (line) =>
                  "${number(line.quantity)} × ${productById(line.productId)?.name ?? ""}",
            )
            .join(", "),
        kind: "Registrado",
      ),
    );
    cart.clear();
    notifyListeners();
    return sale;
  }

  void saveShoppingList() {
    final selected = shopping.where((item) => item.selected).length;
    timeline.insert(
      0,
      TimelineEvent(
        id: _id(),
        time: _now(),
        title: "Lista de compra guardada con $selected productos.",
        tag: "Compra",
      ),
    );
    notifyListeners();
  }

  void closeDay(double counted) {
    countedCash = counted;
    dayClosed = true;
    timeline.insert(
      0,
      TimelineEvent(
        id: _id(),
        time: _now(),
        title: "Cierre del día completado.",
        detail:
            "Efectivo contado ${money(counted)} · diferencia ${money(cashDifference)}.",
        tag: "Cierre",
      ),
    );
    memories.insert(
      0,
      MemoryEvent(
        id: _id(),
        group: "Hoy",
        when: _now(),
        title: "Cerraste el día con ${money(salesToday)} en ventas.",
        detail: "$operationsToday operaciones · efectivo ${money(counted)}.",
        kind: "Registrado",
      ),
    );
    notifyListeners();
  }

  void updateSetting(String key, bool value) {
    proactiveSettings[key] = value;
    notifyListeners();
  }

  bool isFeedLiked(String productId) => likedFeedProducts.contains(productId);

  bool isFeedSaved(String productId) => savedFeedProducts.contains(productId);

  int feedLikeCountFor(String productId) => feedLikeCounts[productId] ?? 0;

  List<String> feedCommentsFor(String productId) =>
      feedCommentsByProduct.putIfAbsent(productId, () => []);

  void toggleFeedLike(String productId) {
    final liked = likedFeedProducts.remove(productId);
    if (!liked) likedFeedProducts.add(productId);
    feedLikeCounts[productId] =
        (feedLikeCounts[productId] ?? 0) + (liked ? -1 : 1);
    notifyListeners();
  }

  void toggleFeedSaved(String productId) {
    if (!savedFeedProducts.remove(productId)) {
      savedFeedProducts.add(productId);
    }
    notifyListeners();
  }

  void addFeedComment(String productId, String comment) {
    final value = comment.trim();
    if (value.isEmpty) return;
    feedCommentsFor(productId).add(value);
    notifyListeners();
  }

  void forgetMemory(String id) {
    memories.removeWhere((memory) => memory.id == id);
    notifyListeners();
  }

  void updateMemory(String id, String title, String detail) {
    final index = memories.indexWhere((memory) => memory.id == id);
    if (index < 0) return;
    final current = memories[index];
    memories[index] = MemoryEvent(
      id: current.id,
      group: current.group,
      when: current.when,
      title: title,
      detail: detail,
      kind: current.kind,
    );
    notifyListeners();
  }

  Map<String, dynamic> _createSnapshot() {
    Map<String, dynamic> lineToJson(SaleLine line) => {
          "productId": line.productId,
          "quantity": line.quantity,
        };

    Map<String, dynamic> saleToJson(Sale sale) => {
          "id": sale.id,
          "lines": sale.lines.map(lineToJson).toList(),
          "total": sale.total,
          "time": sale.time,
          "payment": sale.payment?.name,
          "authorization": sale.authorization,
        };

    return {
      "snapshotVersion": 2,
      "profile": profile == null
          ? null
          : {
              "ownerName": profile!.ownerName,
              "businessName": profile!.businessName,
              "businessType": profile!.businessType,
              "currency": profile!.currency,
            },
      "dayClosed": dayClosed,
      "likedFeedProducts": likedFeedProducts.toList(),
      "savedFeedProducts": savedFeedProducts.toList(),
      "feedLikeCounts": feedLikeCounts,
      "feedCommentsByProduct": feedCommentsByProduct,
      "countedCash": countedCash,
      "proactiveSettings": proactiveSettings,
      "products": products
          .map(
            (product) => {
              "id": product.id,
              "name": product.name,
              "unit": product.unit,
              "price": product.price,
              "stock": product.stock,
              "emoji": product.emoji,
              "supplier": product.supplier,
              "averageDaily": product.averageDaily,
            },
          )
          .toList(),
      "sales": sales.map(saleToJson).toList(),
      "chat": chat
          .map(
            (message) => {
              "id": message.id,
              "type": message.type.name,
              "text": message.text,
              "sale": message.sale == null ? null : saleToJson(message.sale!),
              "items": message.items,
              "productId": message.productId,
              "confirmed": message.confirmed,
            },
          )
          .toList(),
      "memories": memories
          .map(
            (memory) => {
              "id": memory.id,
              "group": memory.group,
              "when": memory.when,
              "title": memory.title,
              "detail": memory.detail,
              "kind": memory.kind,
            },
          )
          .toList(),
      "timeline": timeline
          .map(
            (event) => {
              "id": event.id,
              "time": event.time,
              "title": event.title,
              "detail": event.detail,
              "tag": event.tag,
            },
          )
          .toList(),
      "shopping": shopping
          .map(
            (entry) => {
              "productId": entry.productId,
              "quantity": entry.quantity,
              "reason": entry.reason,
              "selected": entry.selected,
            },
          )
          .toList(),
      "cart": cart
          .map(
            (item) => {
              "productId": item.productId,
              "quantity": item.quantity,
            },
          )
          .toList(),
    };
  }

  void _restoreSnapshot(Map<String, dynamic> snapshot) {
    final profileData = _asMap(snapshot["profile"]);
    profile = profileData == null
        ? null
        : BusinessProfile(
            ownerName: profileData["ownerName"]?.toString() ?? "Usuario",
            businessName:
                profileData["businessName"]?.toString() ?? "Mi negocio",
            businessType: profileData["businessType"]?.toString() ?? "Negocio",
            currency: profileData["currency"]?.toString() ?? "MXN",
          );

    dayClosed = snapshot["dayClosed"] == true;
    final savedLikedProducts = _asList(snapshot["likedFeedProducts"]);
    final savedSavedProducts = _asList(snapshot["savedFeedProducts"]);
    likedFeedProducts
      ..clear()
      ..addAll(savedLikedProducts.map((value) => value.toString()));
    savedFeedProducts
      ..clear()
      ..addAll(savedSavedProducts.map((value) => value.toString()));

    final savedLikeCounts = _asMap(snapshot["feedLikeCounts"]);
    if (savedLikeCounts != null) {
      feedLikeCounts
        ..clear()
        ..addEntries(
          savedLikeCounts.entries.map(
            (entry) => MapEntry(entry.key, (entry.value as num?)?.toInt() ?? 0),
          ),
        );
    }

    final savedCommentsByProduct = _asMap(
      snapshot["feedCommentsByProduct"],
    );
    if (savedCommentsByProduct != null) {
      feedCommentsByProduct
        ..clear()
        ..addEntries(
          savedCommentsByProduct.entries.map(
            (entry) => MapEntry(
              entry.key,
              _asList(entry.value)
                  .map((value) => value.toString())
                  .where((value) => value.isNotEmpty)
                  .toList(),
            ),
          ),
        );
    } else {
      // Migración del formato anterior, que guardaba una sola interacción.
      if (snapshot["feedLiked"] == true) likedFeedProducts.add("tomate");
      if (snapshot["feedSaved"] == true) savedFeedProducts.add("tomate");
      feedLikeCounts["tomate"] =
          (snapshot["feedLikeCount"] as num?)?.toInt() ?? 18;
      final legacyComments = _asList(snapshot["feedComments"])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();
      if (legacyComments.isNotEmpty) {
        feedCommentsByProduct["tomate"] = legacyComments;
      }
    }
    countedCash = _nullableDouble(snapshot["countedCash"]);

    final settings = _asMap(snapshot["proactiveSettings"]);
    if (settings != null) {
      for (final entry in settings.entries) {
        if (entry.value is bool) proactiveSettings[entry.key] = entry.value;
      }
    }

    final productData = _asList(snapshot["products"]);
    if (productData.isNotEmpty) {
      products
        ..clear()
        ..addAll(
          productData.map((raw) {
            final item = _asMap(raw)!;
            return Product(
              id: item["id"].toString(),
              name: item["name"].toString(),
              unit: item["unit"].toString(),
              price: _toDouble(item["price"]),
              stock: _toDouble(item["stock"]),
              emoji: item["emoji"].toString(),
              supplier: item["supplier"].toString(),
              averageDaily: _toDouble(item["averageDaily"]),
            );
          }),
        );
    }

    SaleLine lineFromJson(Object? raw) {
      final item = _asMap(raw)!;
      return SaleLine(
        productId: item["productId"].toString(),
        quantity: _toDouble(item["quantity"]),
      );
    }

    Sale saleFromJson(Object? raw) {
      final item = _asMap(raw)!;
      final paymentName = item["payment"]?.toString();
      return Sale(
        id: item["id"].toString(),
        lines: _asList(item["lines"]).map(lineFromJson).toList(),
        total: _toDouble(item["total"]),
        time: item["time"].toString(),
        payment: paymentName == null
            ? null
            : _enumByName(
                PaymentMethod.values,
                paymentName,
                PaymentMethod.efectivo,
              ),
        authorization: item["authorization"]?.toString(),
      );
    }

    sales
      ..clear()
      ..addAll(_asList(snapshot["sales"]).map(saleFromJson));

    chat
      ..clear()
      ..addAll(
        _asList(snapshot["chat"]).map((raw) {
          final item = _asMap(raw)!;
          return ChatMessage(
            id: item["id"].toString(),
            type: _enumByName(
              MessageType.values,
              item["type"]?.toString(),
              MessageType.text,
            ),
            text: item["text"]?.toString(),
            sale: item["sale"] == null ? null : saleFromJson(item["sale"]),
            items: _asList(item["items"])
                .map((value) => value.toString())
                .toList(),
            productId: item["productId"]?.toString(),
            confirmed: item["confirmed"] == true,
          );
        }),
      );

    memories
      ..clear()
      ..addAll(
        _asList(snapshot["memories"]).map((raw) {
          final item = _asMap(raw)!;
          return MemoryEvent(
            id: item["id"].toString(),
            group: item["group"].toString(),
            when: item["when"].toString(),
            title: item["title"].toString(),
            detail: item["detail"]?.toString() ?? "",
            kind: item["kind"].toString(),
          );
        }),
      );

    timeline
      ..clear()
      ..addAll(
        _asList(snapshot["timeline"]).map((raw) {
          final item = _asMap(raw)!;
          return TimelineEvent(
            id: item["id"].toString(),
            time: item["time"].toString(),
            title: item["title"].toString(),
            detail: item["detail"]?.toString() ?? "",
            tag: item["tag"]?.toString() ?? "",
          );
        }),
      );

    shopping
      ..clear()
      ..addAll(
        _asList(snapshot["shopping"]).map((raw) {
          final item = _asMap(raw)!;
          return ShoppingEntry(
            productId: item["productId"].toString(),
            quantity: _toDouble(item["quantity"]),
            reason: item["reason"]?.toString() ?? "",
            selected: item["selected"] != false,
          );
        }),
      );

    cart
      ..clear()
      ..addAll(
        _asList(snapshot["cart"]).map((raw) {
          final item = _asMap(raw)!;
          return CartItem(
            productId: item["productId"].toString(),
            quantity: _toDouble(item["quantity"]),
          );
        }).where(
          (item) => productById(item.productId) != null && item.quantity > 0,
        ),
      );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static List<dynamic> _asList(Object? value) =>
      value is List ? value : const [];

  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse("$value") ?? 0;

  static double? _nullableDouble(Object? value) =>
      value == null ? null : _toDouble(value);

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  void _seedSales() {
    const totals = [
      120.0,
      180.0,
      150.0,
      210.0,
      95.0,
      280.0,
      310.0,
      175.0,
      240.0,
      200.0,
      190.0,
      280.0,
    ];
    for (var i = 0; i < totals.length; i++) {
      final product = products[i % products.length];
      sales.add(
        Sale(
          id: "seed-$i",
          lines: [
            SaleLine(
              productId: product.id,
              quantity: i % 3 == 0 ? 2 : 1,
            ),
          ],
          total: totals[i],
          time:
              "${(9 + i ~/ 2).toString().padLeft(2, "0")}:${i.isEven ? "10" : "40"}",
          payment: PaymentMethod.values[i % 3],
          authorization: i % 3 == 1 ? "683${190 + i}" : null,
        ),
      );
    }
  }

  _SaleParse _parseSale(String input) {
    const quantities = {
      "un": 1.0,
      "una": 1.0,
      "uno": 1.0,
      "dos": 2.0,
      "tres": 3.0,
      "cuatro": 4.0,
      "cinco": 5.0,
      "seis": 6.0,
      "siete": 7.0,
      "ocho": 8.0,
      "nueve": 9.0,
      "diez": 10.0,
      "doce": 12.0,
      "quince": 15.0,
      "veinte": 20.0,
      "treinta": 30.0,
    };
    final tokens = input.replaceAll(RegExp(r"[.,]"), " ").split(RegExp(r"\s+"));
    final result = <String, double>{};
    final found = <String>[];
    final missing = <String>[];

    for (var i = 0; i < tokens.length; i++) {
      Product? product;
      for (final candidate in products) {
        if (tokens[i].startsWith(_normalize(candidate.id))) {
          product = candidate;
          break;
        }
      }
      if (product == null) continue;
      found.add(product.name);

      double? quantity;
      final start = i >= 3 ? i - 3 : 0;
      for (var j = start; j < i; j++) {
        quantity =
            double.tryParse(tokens[j]) ?? quantities[tokens[j]] ?? quantity;
      }
      if (quantity == null) {
        missing.add(product.name);
      } else {
        result[product.id] = (result[product.id] ?? 0) + quantity;
      }
    }

    return _SaleParse(
      lines: result.entries
          .map(
            (entry) => SaleLine(
              productId: entry.key,
              quantity: entry.value,
            ),
          )
          .toList(),
      foundProducts: found,
      missingQuantity: missing,
    );
  }

  void _reply(String text) {
    chat.add(ChatMessage(id: _id(), type: MessageType.text, text: text));
  }

  static String money(num value) {
    final fixed = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    final parts = fixed.split(".");
    final digits = parts.first.replaceFirst("-", "");
    final grouped = digits.replaceAllMapped(
      RegExp(r"\B(?=(\d{3})+(?!\d))"),
      (_) => ",",
    );
    final sign = value < 0 ? "-" : "";
    final decimals = parts.length == 2 ? ".${parts.last}" : "";
    return "\$$sign$grouped$decimals";
  }

  static String number(num value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  static String paymentLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.efectivo => "efectivo",
        PaymentMethod.tarjeta => "tarjeta",
        PaymentMethod.transferencia => "transferencia",
        PaymentMethod.combinado => "combinado",
      };

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll("á", "a")
      .replaceAll("é", "e")
      .replaceAll("í", "i")
      .replaceAll("ó", "o")
      .replaceAll("ú", "u");

  String _id() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  String _now() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}";
  }

  @override
  void dispose() {
    removeListener(_queuePersistence);
    unawaited(
      flushPersistence().whenComplete(() => persistence?.close()),
    );
    super.dispose();
  }
}

class _SaleParse {
  const _SaleParse({
    required this.lines,
    required this.foundProducts,
    required this.missingQuantity,
  });

  final List<SaleLine> lines;
  final List<String> foundProducts;
  final List<String> missingQuantity;
}

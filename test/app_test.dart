import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/app.dart";
import "package:carrota_flutter/local_database.dart";
import "package:carrota_flutter/immersive_home.dart";
import "package:carrota_flutter/main.dart";
import "package:carrota_flutter/models.dart";
import "package:carrota_flutter/widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("interpreta y confirma una venta escrita en español", () async {
    final store = AppStore();

    await store.send("Vendí dos tomates y una lechuga");

    final proposal =
        store.chat.lastWhere((message) => message.type == MessageType.sale);
    expect(proposal.sale?.total, 88);

    store.confirmSale(proposal, PaymentMethod.efectivo);
    expect(store.productById("tomate")?.stock, 40);
    expect(store.productById("lechuga")?.stock, 3);
    store.dispose();
  });

  test("responde localmente usando los datos del negocio", () async {
    final store = AppStore();

    await store.send("¿Cómo va mi negocio?");

    expect(store.chat.last.text, contains("12 operaciones"));
    expect(store.chat.last.text, contains(r"$2,430"));
    store.dispose();
  });

  test("restaura perfil, inventario y ventas desde persistencia", () async {
    final persistence = MemoryStatePersistence();
    final first = AppStore(persistence: persistence);
    await first.initialize();
    first.completeOnboarding(
      const BusinessProfile(
        ownerName: "Jorge",
        businessName: "Carrota persistente",
        businessType: "Verdulería",
        currency: "CLP",
      ),
    );
    first.updatePrice("tomate", 45);
    first.toggleFeedLike("zanahoria");
    first.toggleFeedSaved("lechuga");
    first.addFeedComment("zanahoria", "Comentario persistente");
    expect(first.addToCart("lechuga"), isTrue);
    expect(first.addToCart("lechuga"), isTrue);
    await first.send("Vendí dos tomates");
    final proposal =
        first.chat.lastWhere((message) => message.type == MessageType.sale);
    first.confirmSale(proposal, PaymentMethod.efectivo);
    await first.flushPersistence();

    final restored = AppStore(persistence: persistence);
    await restored.initialize();

    expect(restored.businessName, "Carrota persistente");
    expect(restored.currency, "CLP");
    expect(restored.productById("tomate")?.price, 45);
    expect(restored.productById("tomate")?.stock, 40);
    expect(restored.operationsToday, 13);
    expect(restored.isFeedLiked("zanahoria"), isTrue);
    expect(restored.isFeedLiked("tomate"), isFalse);
    expect(restored.isFeedSaved("lechuga"), isTrue);
    expect(restored.isFeedSaved("tomate"), isFalse);
    expect(restored.feedLikeCountFor("zanahoria"), 25);
    expect(
      restored.feedCommentsFor("zanahoria"),
      contains("Comentario persistente"),
    );
    expect(restored.cartItemCount, 2);
    expect(restored.cartTotal, 56);
    first.dispose();
    restored.dispose();
  });

  testWidgets("muestra el onboarding al iniciar", (tester) async {
    await tester.pumpWidget(const CarrotaApp());
    await tester.pumpAndSettle();

    expect(find.text("Hola, soy Lumo."), findsOneWidget);
    expect(find.text("Continuar"), findsOneWidget);
  });

  testWidgets("muestra una carcasa de teléfono solo en escritorio", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PhoneStage(child: SizedBox()))),
    );
    expect(find.text("9:41"), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    expect(find.text("9:41"), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets("muestra el inicio inmersivo después del onboarding", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final store = AppStore();
    store.completeOnboarding(
      const BusinessProfile(
        ownerName: "Jorge",
        businessName: "Carrota",
        businessType: "Verdulería",
        currency: "CLP",
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          store: store,
          onOpenProduct: (_) {},
          onOpenDelivery: () {},
          onOpenClosing: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Tu negocio,\nen movimiento."), findsOneWidget);
    expect(find.text("Agregar"), findsOneWidget);
    expect(find.text("Alertas"), findsOneWidget);
    expect(find.text("Guardar"), findsOneWidget);
    expect(find.text("Compartir"), findsOneWidget);
    expect(find.text("Desliza hacia arriba"), findsOneWidget);
    expect(find.textContaining("Ya configuré"), findsNothing);
    expect(find.text("Tomate saladet"), findsOneWidget);

    await tester.tap(find.text("Agregar"));
    await tester.pump();
    expect(store.cartItemCount, 1);
    expect(find.text("Carrito"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pump();
    expect(store.isFeedLiked("tomate"), isTrue);
    expect(store.isFeedLiked("lechuga"), isFalse);

    await tester.fling(
      find.byType(HomeScreen),
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text("Lechuga italiana"), findsOneWidget);
    expect(store.isFeedLiked("tomate"), isTrue);
    expect(store.isFeedLiked("lechuga"), isFalse);

    await tester.tap(find.byIcon(Icons.mode_comment_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining("Comentarios de"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(null);
  });

  test("confirma un carrito y actualiza inventario", () {
    final store = AppStore();
    expect(store.addToCart("tomate", quantity: 2), isTrue);
    expect(store.addToCart("lechuga"), isTrue);
    expect(store.cartTotal, 88);

    final sale = store.checkoutCart(PaymentMethod.transferencia);

    expect(sale?.total, 88);
    expect(sale?.payment, PaymentMethod.transferencia);
    expect(store.cart, isEmpty);
    expect(store.productById("tomate")?.stock, 40);
    expect(store.productById("lechuga")?.stock, 3);
    expect(store.timeline.first.tag, "Tienda");
    store.dispose();
  });

  testWidgets("mantiene los paneles inferiores dentro del teléfono", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    await tester.pumpWidget(const CarrotaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Continuar"));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey("owner-name")),
      "Jorge",
    );
    await tester.tap(find.text("Continuar"));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey("business-name")),
      "Carrota",
    );
    await tester.tap(find.text("Continuar"));
    await tester.pump();
    await tester.tap(find.text("Empezar"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Recibir"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(const ValueKey("phone-frame")));
    final sheet = tester.getRect(find.byType(SheetScaffold));

    expect(sheet.left, greaterThanOrEqualTo(frame.left));
    expect(sheet.right, lessThanOrEqualTo(frame.right));
    expect(sheet.top, greaterThanOrEqualTo(frame.top));
    expect(sheet.bottom, lessThanOrEqualTo(frame.bottom));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets("abre Lumo como apartado y responde localmente", (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final store = AppStore();
    store.completeOnboarding(
      const BusinessProfile(
        ownerName: "Jorge",
        businessName: "Carrota",
        businessType: "Verdulería",
        currency: "CLP",
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LumoScreen(
          store: store,
          onSend: store.send,
          onOpenProduct: (_) {},
          onCamera: () {},
          onVoice: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("lumo-screen")), findsOneWidget);
    expect(find.text("Respuestas fijas · datos locales"), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      "¿Cuánto vendí hoy?",
    );
    await tester.tap(find.byTooltip("Enviar"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(store.chat.last.text, contains(r"$2,430"));
    expect(find.textContaining(r"$2,430"), findsWidgets);
    store.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

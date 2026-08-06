import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/app.dart";
import "package:carrota_flutter/ai_service.dart";
import "package:carrota_flutter/local_database.dart";
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

  test("envía consultas reales al proveedor de IA seleccionado", () async {
    final store = AppStore(aiService: _FakeAiService());
    store.setAiProvider(AiProviderChoice.deepseek);

    await store.send("¿Cómo va mi negocio?");

    expect(store.chat.last.text, contains("respuesta real"));
    expect(store.chat.last.aiProvider, "deepseek");
    expect(store.lastAiModel, "deepseek-v4-flash");
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

    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
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
}

class _FakeAiService extends AiService {
  @override
  Future<AiReply> ask({
    required String message,
    required AiProviderChoice provider,
    required List<Map<String, String>> history,
    required Map<String, Object?> business,
  }) async {
    return const AiReply(
      text: "Esta es una respuesta real de prueba.",
      provider: "deepseek",
      model: "deepseek-v4-flash",
    );
  }

  @override
  Future<AiHealth> health() async => const AiHealth(
        reachable: true,
        openaiConfigured: true,
        deepseekConfigured: true,
      );

  @override
  void dispose() {}
}

import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/immersive_home.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "support/fake_video.dart";

void main() {
  Future<AppStore> mount(WidgetTester tester,
      {Size size = const Size(390, 844), bool failVideos = false}) async {
    await tester.binding.setSurfaceSize(size);
    final store = AppStore();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeScreen(
      store: store,
      videoControllerFactory:
          failVideos ? (asset) => FakeVideo(asset, fail: true) : null,
      onOpenProduct: (_) {},
      onOpenDelivery: () {},
      onOpenClosing: () {},
    ))));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    return store;
  }

  testWidgets("drag visibly moves both pages and can cancel back to original",
      (tester) async {
    await mount(tester);
    final page0 = find.byKey(const ValueKey("feed-page-0"));
    final start = tester.getTopLeft(page0).dy;
    final gesture = await tester.startGesture(const Offset(200, 230));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -160));
    await tester.pump();
    final top = tester.getTopLeft(page0).dy;
    final next =
        tester.getTopLeft(find.byKey(const ValueKey("feed-page-1"))).dy;
    expect(top, lessThan(start - 100));
    expect(next, greaterThan(0));
    expect(next, lessThan(844));
    await gesture.moveBy(const Offset(0, 160));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(page0).dy, closeTo(start, 1));
  });

  testWidgets("advances, returns and clamps at first and last page",
      (tester) async {
    await mount(tester);
    final feed = find.byKey(const ValueKey("vertical-product-feed"));
    Future<void> swipe(double dy) async {
      await tester.fling(feed, Offset(0, dy), 1000);
      await tester.pumpAndSettle();
    }

    await swipe(500);
    expect(find.text("Tomate saladet"), findsOneWidget);
    await swipe(-500);
    expect(find.text("Lechuga italiana"), findsOneWidget);
    await swipe(500);
    expect(find.text("Tomate saladet"), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await swipe(-500);
    }
    expect(find.text("Espinaca"), findsOneWidget);
    await swipe(500);
    expect(find.text("Cilantro"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("small phone and comments with keyboard have no overflow",
      (tester) async {
    await mount(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.mode_comment_rounded));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "Buen producto");
    await tester.ensureVisible(find.byTooltip("Publicar"));
    await tester.tap(find.byTooltip("Publicar"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("stock limit disables add and keeps the correct cart total",
      (tester) async {
    final store = await mount(tester);
    store.productById("tomate")!.stock = 1;
    await tester.tap(find.text("Agregar"));
    await tester.pump();
    expect(store.cartItemCount, 1);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, "Agregar"))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets("retry remains reachable above product card on a small phone",
      (tester) async {
    await mount(tester, size: const Size(320, 568), failVideos: true);
    expect(find.text("Reintentar"), findsOneWidget);
    expect(find.text("Reintentar").hitTestable(), findsOneWidget);
    await tester.tap(find.text("Reintentar"));
    await tester.pumpAndSettle();
    expect(find.text("Reintentar").hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

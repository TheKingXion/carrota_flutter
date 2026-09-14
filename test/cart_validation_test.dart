import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("rejects invalid quantities without corrupting cart", () {
    final store = AppStore();
    addTearDown(store.dispose);
    for (final value in [double.nan, double.infinity, -1.0, 0.0, 1000.0]) {
      expect(store.addToCart("tomate", quantity: value), isFalse);
    }
    expect(store.addToCart("missing"), isFalse);
    expect(store.cart, isEmpty);
    store.addToCart("tomate");
    expect(store.updateCartQuantity("tomate", double.nan), isFalse);
    expect(store.updateCartQuantity("tomate", double.infinity), isFalse);
    expect(store.cartTotal, 30);
  });
  test("checkout revalidates changed stock atomically and cannot repeat", () {
    final store = AppStore();
    addTearDown(store.dispose);
    store.addToCart("tomate", quantity: 2);
    store.addToCart("lechuga", quantity: 2);
    store.productById("lechuga")!.stock = 1;
    final sales = store.sales.length;
    expect(store.checkoutCart(PaymentMethod.efectivo), isNull);
    expect(store.productById("tomate")!.stock, 42);
    expect(store.sales.length, sales);
    expect(store.cart.length, 2);
    store.updateCartQuantity("lechuga", 1);
    expect(store.checkoutCart(PaymentMethod.efectivo), isNotNull);
    expect(store.checkoutCart(PaymentMethod.efectivo), isNull);
    expect(store.sales.length, sales + 1);
  });
}

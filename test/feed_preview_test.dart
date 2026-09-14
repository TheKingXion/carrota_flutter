import "dart:io";
import "dart:convert";

import "dart:ui" as ui;
import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/immersive_home.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:carrota_flutter/theme.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "support/fake_video.dart";

void main() {
  testWidgets("render feed previews", (tester) async {
    await tester.runAsync(() async {
      final config = File(".dart_tool/package_config.json");
      final packages = (jsonDecode(config.readAsStringSync())
          as Map<String, dynamic>)["packages"] as List<dynamic>;
      final flutter = packages
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p["name"] == "flutter");
      final sdk = Directory.fromUri(
              config.absolute.uri.resolve(flutter["rootUri"] as String))
          .parent
          .parent;
      for (final entry in {
        "Roboto": "roboto-regular.ttf",
        "MaterialIcons": "materialicons-regular.otf"
      }.entries) {
        final uri = File(
                "${sdk.path}/bin/cache/artifacts/material_fonts/${entry.value}")
            .uri;
        final loader = FontLoader(entry.key)
          ..addFont(File.fromUri(uri).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    });
    final store = AppStore();
    final key = GlobalKey();
    for (final width in [390.0, 320.0]) {
      final height = width == 390 ? 844.0 : 568.0;
      await tester.binding.setSurfaceSize(Size(width, height));
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme().copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                      style: buildTheme().filledButtonTheme.style?.copyWith(
                          textStyle: const WidgetStatePropertyAll(TextStyle(
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.w700)))),
                  textTheme:
                      buildTheme().textTheme.apply(fontFamily: "Roboto")),
              home: Scaffold(
                  body: HomeScreen(
                      store: store,
                      videoControllerFactory: FakeVideo.new,
                      onOpenProduct: (_) {},
                      onOpenDelivery: () {},
                      onOpenClosing: () {})))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage("assets/posters/fresh_fruit.jpg"),
          key.currentContext!));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory("build/qa").createSync(recursive: true);
        File("build/qa/feed-${width.toInt()}.png")
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

import "package:carrota_flutter/app_store.dart";
import "package:carrota_flutter/immersive_home.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "support/fake_video.dart";

void main() {
  testWidgets(
      "tab, route, popup and background pause the feed without restarting",
      (tester) async {
    final store = AppStore();
    final players = <FakeVideo>[];
    var active = true;
    final navigator = GlobalKey<NavigatorState>();
    late StateSetter rebuild;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [feedRouteObserver],
        home: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return Scaffold(
              body: HomeScreen(
                  store: store,
                  active: active,
                  videoControllerFactory: (asset) {
                    final video = FakeVideo(asset);
                    players.add(video);
                    return video;
                  },
                  onOpenProduct: (_) {},
                  onOpenDelivery: () {},
                  onOpenClosing: () {}));
        })));
    await tester.pumpAndSettle();
    final first = players.first;
    expect(first.value.isPlaying, isTrue);
    await first.seekTo(const Duration(seconds: 4));
    rebuild(() => active = false);
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isFalse);
    rebuild(() => active = true);
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isTrue);
    expect(first.value.position, const Duration(seconds: 4));

    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text("Otra sección"))));
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isTrue);

    await tester.tap(find.byIcon(Icons.mode_comment_rounded));
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(first.value.isPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(first.value.isPlaying, isTrue);
    expect(players.length, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(players.every((player) => player.disposals == 1), isTrue);
    store.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

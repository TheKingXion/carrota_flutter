import "dart:async";
import "package:carrota_flutter/feed_video_controller.dart";
import "package:flutter_test/flutter_test.dart";
import "package:video_player/video_player.dart";
import "support/fake_video.dart";

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeedVideoController feed;
  late Map<String, List<FakeVideo>> created;
  setUp(() {
    created = {};
    feed =
        FeedVideoController(const ["0", "1", "2", "3", "4"], create: (asset) {
      final video = FakeVideo(asset);
      created.putIfAbsent(asset, () => []).add(video);
      return video;
    });
  });
  tearDown(() async {
    feed.dispose();
    await flush();
  });

  test("warms neighbours, only visible video plays, bounds live players",
      () async {
    feed.select(0);
    await flush();
    expect(created.keys, ["0", "1"]);
    expect(feed.player(0)!.value.isPlaying, isTrue);
    expect(feed.player(1)!.value.isPlaying, isFalse);
    feed.select(2);
    await flush();
    expect(feed.player(0), isNull);
    expect(created["0"]!.single.disposals, 1);
    expect(feed.player(2)!.value.isPlaying, isTrue);
    expect(feed.player(1)!.value.isPlaying, isFalse);
    expect(feed.player(3)!.value.isPlaying, isFalse);
    expect(
        created.values.expand((v) => v).where((v) => v.disposals == 0).length,
        3);
  });

  test("drag, hidden feed and manual pause preserve playback intent", () async {
    feed.select(0);
    await flush();
    feed.setScrolling(true);
    await flush();
    expect(feed.player(0)!.value.isPlaying, isFalse);
    feed.select(1);
    await flush();
    expect(feed.player(1)!.value.isPlaying, isFalse);
    feed.setScrolling(false);
    await flush();
    expect(feed.player(1)!.value.isPlaying, isTrue);
    feed.togglePlayback();
    feed.setActive(false);
    feed.setActive(true);
    await flush();
    expect(feed.player(1)!.value.isPlaying, isFalse);
    feed.togglePlayback();
    await flush();
    expect(feed.player(1)!.value.isPlaying, isTrue);
    feed.setActive(false);
    await flush();
    expect(feed.player(1)!.value.isPlaying, isFalse);
  });

  test("restores distant video position and mute on return", () async {
    feed.select(0);
    await flush();
    await feed.player(0)!.seekTo(const Duration(seconds: 7));
    feed.select(3);
    feed.toggleMute();
    await flush();
    feed.select(0);
    await flush();
    expect(feed.player(0)!.value.position, const Duration(seconds: 7));
    expect(feed.player(0)!.value.volume, 1);
    expect(created["0"]!.length, 2);
  });

  test(
      "rapid direction changes keep the latest page and ignore invalid indexes",
      () async {
    feed.select(0);
    feed.select(4);
    feed.select(2);
    feed.select(-1);
    feed.select(50);
    await flush();
    expect(feed.index, 2);
    for (var i = 0; i < 5; i++) {
      final player = feed.player(i);
      if (player != null) expect(player.value.isPlaying, i == 2);
    }
  });

  test("failed initialization can retry without leaking its player", () async {
    var attempts = 0;
    final players = <FakeVideo>[];
    final broken = FeedVideoController(const ["a"], create: (asset) {
      final player = FakeVideo(asset, fail: attempts++ == 0);
      players.add(player);
      return player;
    });
    broken.select(0);
    await flush();
    expect(broken.failed(0), isTrue);
    expect(players.first.disposals, 1);
    broken.retry(0);
    await flush();
    expect(broken.failed(0), isFalse);
    expect(broken.player(0)!.value.isPlaying, isTrue);
    broken.dispose();
    await flush();
    expect(players.last.disposals, 1);
  });

  test("late initialization after navigation never plays stale page", () async {
    final gate = Completer<void>();
    final delayed = FeedVideoController(const ["a", "b", "c"],
        create: (asset) => FakeVideo(asset, gate: asset == "a" ? gate : null));
    delayed.select(0);
    delayed.select(2);
    delayed.setActive(false);
    gate.complete();
    await flush();
    expect(delayed.player(0), isNull);
    delayed.setActive(true);
    await flush();
    expect(delayed.player(2)!.value.isPlaying, isTrue);
    delayed.dispose();
    await flush();
  });

  test("dispose during initialization closes player exactly once", () async {
    final gate = Completer<void>();
    final video = FakeVideo("a", gate: gate);
    final delayed = FeedVideoController(const ["a"], create: (_) => video);
    delayed.select(0);
    delayed.dispose();
    gate.complete();
    await flush();
    expect(video.disposals, 1);
  });
  test("runtime decoder error pauses, disposes and allows recovery", () async {
    feed.select(0);
    await flush();
    final video = created["0"]!.single;
    video.value = const VideoPlayerValue.erroneous("decoder lost");
    await flush();
    expect(feed.failed(0), isTrue);
    expect(feed.player(0), isNull);
    expect(video.disposals, 1);
    feed.retry(0);
    await flush();
    expect(feed.player(0)!.value.isPlaying, isTrue);
  });

  test("repeated forward and reverse navigation does not accumulate players",
      () async {
    for (var cycle = 0; cycle < 5; cycle++) {
      for (final page in [0, 1, 2, 3, 4, 3, 2, 1, 0]) {
        feed.select(page);
        await flush();
        final live = created.values
            .expand((v) => v)
            .where((v) => v.disposals == 0)
            .toList();
        expect(live.length, lessThanOrEqualTo(3));
        expect(live.where((v) => v.value.isPlaying).length, 1);
        expect(feed.player(page)!.value.isPlaying, isTrue);
      }
    }
  });
  test("slow native disposal after failure cannot block the next video",
      () async {
    final gate = Completer<void>();
    final slow = FeedVideoController(const ["bad", "good"],
        create: (asset) => FakeVideo(asset,
            fail: asset == "bad", disposalGate: asset == "bad" ? gate : null));
    slow.select(0);
    await flush();
    expect(slow.failed(0), isTrue);
    expect(slow.player(1), isNotNull);
    slow.select(1);
    await flush();
    expect(slow.player(1)!.value.isPlaying, isTrue);
    gate.complete();
    slow.dispose();
    await flush();
  });
  test("slow neighbour cannot delay the newly selected video", () async {
    final gate = Completer<void>();
    final loading = FeedVideoController(const ["a", "slow", "c"],
        create: (asset) =>
            FakeVideo(asset, gate: asset == "slow" ? gate : null));
    try {
      loading.select(0);
      await flush();
      expect(loading.player(0)!.value.isPlaying, isTrue);
      loading.select(2);
      await flush();
      expect(loading.player(2), isNotNull);
      expect(loading.player(2)!.value.isPlaying, isTrue);
    } finally {
      gate.complete();
      loading.dispose();
      await flush();
    }
  });
  test("rapid swipes keep at most two unfinished loads", () async {
    final gates = <String, Completer<void>>{};
    final videos = <String, FakeVideo>{};
    final loading =
        FeedVideoController(const ["0", "1", "2", "3", "4"], create: (asset) {
      final gate = gates.putIfAbsent(asset, Completer<void>.new);
      return videos[asset] = FakeVideo(asset, gate: gate);
    });
    try {
      loading.select(0);
      loading.select(3);
      loading.select(4);
      expect(gates.length, 2);
      gates["1"]!.complete();
      await flush();
      expect(gates.keys, ["0", "1", "4"]);
      expect(videos["1"]!.disposals, 1);
      expect(gates.values.where((gate) => !gate.isCompleted).length, 2);
      gates["4"]!.complete();
      await flush();
      expect(loading.player(4)!.value.isPlaying, isTrue);
      expect(gates.values.where((gate) => !gate.isCompleted).length, 2);
    } finally {
      loading.dispose();
      for (final gate in gates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      await flush();
    }
  });

  test("a throwing player factory does not block other pages", () async {
    final loading = FeedVideoController(const ["bad", "good"], create: (asset) {
      if (asset == "bad") throw StateError("platform unavailable");
      return FakeVideo(asset);
    });
    loading.select(0);
    await flush();
    expect(loading.failed(0), isTrue);
    loading.select(1);
    await flush();
    expect(loading.player(1)!.value.isPlaying, isTrue);
    loading.dispose();
    await flush();
  });

  testWidgets("setup timeout releases its slot and late setup cannot resume it",
      (tester) async {
    final gate = Completer<void>();
    final stalled = _SlowSetupVideo("slow", gate);
    final loading = FeedVideoController(const ["slow", "good"],
        create: (asset) => asset == "slow" ? stalled : FakeVideo(asset));
    loading.select(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    expect(loading.failed(0), isTrue);
    expect(stalled.disposals, 1);
    loading.select(1);
    await tester.pump();
    expect(loading.player(1)!.value.isPlaying, isTrue);
    gate.complete();
    await tester.pump();
    expect(stalled.volumeCalls, 0);
    loading.dispose();
    await tester.pump();
  });
}

class _SlowSetupVideo extends FakeVideo {
  _SlowSetupVideo(super.asset, this.setupGate);
  final Completer<void> setupGate;
  int volumeCalls = 0;
  @override
  Future<void> setLooping(bool looping) => setupGate.future;
  @override
  Future<void> setVolume(double volume) async {
    volumeCalls++;
    await super.setVolume(volume);
  }
}

import "dart:async";
import "package:flutter/material.dart";
import "package:video_player/video_player.dart";

class FakeVideo extends VideoPlayerController {
  FakeVideo(super.asset, {this.gate, this.fail = false, this.disposalGate})
      : super.asset();
  final Completer<void>? gate;
  final bool fail;
  final Completer<void>? disposalGate;
  int disposals = 0;
  @override
  Future<void> initialize() async {
    await gate?.future;
    if (fail) throw StateError("decoder failed");
    value = const VideoPlayerValue(
        duration: Duration(seconds: 30),
        size: Size(360, 640),
        isInitialized: true);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await disposalGate?.future;
    await super.dispose();
  }
}

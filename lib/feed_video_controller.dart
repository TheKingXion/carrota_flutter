import "dart:async";

import "package:flutter/foundation.dart";
import "package:video_player/video_player.dart";

/// Owns a bounded window of players; UI changes never recreate the active video.
class FeedVideoController extends ChangeNotifier {
  FeedVideoController(List<String> assets,
      {VideoPlayerController Function(String)? create})
      : assets = List.unmodifiable(assets),
        _create = create ?? VideoPlayerController.asset;

  final List<String> assets;
  final VideoPlayerController Function(String) _create;
  final Map<int, _VideoSlot> _slots = {};
  final Map<int, Duration> _positions = {};
  final Set<int> _paused = {};
  final Set<int> _failed = {};
  int index = 0;
  bool muted = true;
  bool _active = true;
  bool _scrolling = false;
  bool _disposed = false;
  int _initializing = 0;

  VideoPlayerController? player(int page) =>
      _slots[page]?.ready == true ? _slots[page]!.player : null;
  bool failed(int page) => _failed.contains(page);
  bool paused(int page) => _paused.contains(page);

  void select(int page) {
    if (_disposed || page < 0 || page >= assets.length) return;
    index = page;
    _prune();
    _syncAll();
    _warm();
    notifyListeners();
  }

  void setActive(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    _syncAll();
    if (value) _warm();
  }

  void setScrolling(bool value) {
    if (_disposed || value == _scrolling) return;
    _scrolling = value;
    _syncAll();
  }

  void togglePlayback() {
    if (_disposed) return;
    if (!_paused.remove(index)) _paused.add(index);
    _syncAll();
    notifyListeners();
  }

  void toggleMute() {
    if (_disposed) return;
    muted = !muted;
    _syncAll();
    notifyListeners();
  }

  void retry(int page) {
    if (_disposed) return;
    _failed.remove(page);
    _warm();
    notifyListeners();
  }

  void _warm() {
    if (_disposed || !_active) return;
    _prune();
    // Two loading slots let the visible page bypass one slow neighbour.
    // The full window, including pending loads, stays bounded at three.
    for (final page in [index, index + 1, index - 1]) {
      if (page < 0 ||
          page >= assets.length ||
          _slots.containsKey(page) ||
          _failed.contains(page)) {
        continue;
      }
      if (_initializing >= 2 || _slots.length >= 3) break;
      try {
        final slot = _VideoSlot(_create(assets[page]));
        _slots[page] = slot;
        _initializing++;
        unawaited(_load(page, slot));
      } catch (_) {
        _failed.add(page);
      }
    }
  }

  bool _owns(int page, _VideoSlot slot) =>
      !_disposed && !slot.closed && _slots[page] == slot;

  Future<void> _prepare(int page, _VideoSlot slot) async {
    await slot.player.initialize();
    if (!_owns(page, slot)) return;
    await slot.player.setLooping(true);
    if (!_owns(page, slot)) return;
    await slot.player.setVolume(muted ? 0 : 1);
    if (!_owns(page, slot)) return;
    final position = _positions[page];
    if (position != null) await slot.player.seekTo(position);
  }

  Future<void> _load(int page, _VideoSlot slot) async {
    try {
      // The deadline covers setup and seeking as well as native initialization.
      await _prepare(page, slot).timeout(const Duration(seconds: 12));
      if (!_owns(page, slot)) return;
      slot.player.addListener(() {
        if (!_owns(page, slot) || !slot.player.value.hasError) return;
        _failed.add(page);
        _slots.remove(page);
        unawaited(slot.close());
        _warm();
        notifyListeners();
      });
      slot.ready = true;
      _sync(page, slot);
    } catch (_) {
      if (_owns(page, slot)) {
        _failed.add(page);
        _slots.remove(page);
      }
      // Native cleanup must never block loading another page.
      unawaited(slot.close());
    } finally {
      _initializing--;
      if (!_disposed) {
        _prune();
        _warm();
        notifyListeners();
      }
    }
  }

  void _syncAll() {
    for (final entry in _slots.entries) {
      if (entry.value.ready) _sync(entry.key, entry.value);
    }
  }

  void _sync(int page, _VideoSlot slot) {
    // Serial commands evaluate the latest state, so a late play cannot undo pause.
    slot.pending = slot.pending.then((_) async {
      if (_disposed || slot.closed || !slot.ready) return;
      await slot.player.setVolume(muted ? 0 : 1);
      if (_disposed || slot.closed) return;
      final play =
          _active && !_scrolling && page == index && !_paused.contains(page);
      if (play) {
        await slot.player.play();
      } else {
        await slot.player.pause();
      }
    }).catchError((Object error) {
      if (!_disposed && !slot.closed) {
        _failed.add(page);
        _slots.remove(page);
        unawaited(slot.close());
        notifyListeners();
      }
    });
  }

  void _prune() {
    for (final page in _slots.keys.toList()) {
      final slot = _slots[page]!;
      if ((page - index).abs() <= 1 || !slot.ready) continue;
      _positions[page] = slot.player.value.position;
      _slots.remove(page);
      unawaited(slot.close());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final slot in _slots.values) {
      unawaited(slot.close());
    }
    _slots.clear();
    super.dispose();
  }
}

class _VideoSlot {
  _VideoSlot(this.player);
  final VideoPlayerController player;
  bool ready = false;
  bool closed = false;
  Future<void> pending = Future<void>.value();

  Future<void> close() async {
    if (closed) return;
    closed = true;
    await pending;
    try {
      await player.dispose();
    } catch (_) {
      // Platform teardown can race with a failed initialization.
    }
  }
}

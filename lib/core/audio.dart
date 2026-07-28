import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Names of the shipped sound files, without the `sounds/` prefix.
class Sfx {
  static const click = 'UI_click_button_asset.mp3';
  static const menuOpen = 'menu_open_asset.mp3';
  static const menuClose = 'menu_close_asset.mp3';
  static const startRun = 'start_run_asset.mp3';
  static const gameOver = 'Game_Over_asset.mp3';
  static const victory = 'Victory_asset.mp3';
  static const freshMagma = 'Fresh_Magma_Creation_asset.mp3';
  static const pathCracking = 'Path_Cracking_asset.mp3';
  static const pathCollapse = 'Path_Collapse_asset.mp3';
  static const cooling = 'Cooling_Magma_asset.mp3';
  static const resource = 'Resource_Collect_asset.mp3';
  static const rareResource = 'Rare_Resource_Collect_asset.mp3';
  static const combo = 'Combo_Increase_asset.mp3';
  static const highCombo = 'High_Combo_asset.mp3';
  static const milestone = 'Distance_Milestone_asset.mp3';
  static const coreActivation = 'Ancient_Core_Activation_asset.mp3';
  static const crystalMagma = 'Crystal_Magma_asset.mp3';
  static const explosiveMagma = 'Explosive_Magma_asset.mp3';
  static const magneticMagma = 'Magnetic_Magma_asset.mp3';
  static const livingMagma = 'Living_Magma_Activation_asset.mp3';
  static const newBiome = 'New_Biome_asset.mp3';
  static const eruption = 'Lava_Eruption_asset.mp3';
  static const pressure = 'Volcano_Pressure_Rising_asset.mp3';
  static const sharpTurn = 'Sharp_Turn_asset.mp3';
  static const creatureSpawn = 'Fire_Creature_Spawn_asset.mp3';
  static const creatureBuff = 'Fire_Creature_Buff_asset.mp3';
  static const heatWave = 'Heat_Wave_asset.mp3';
  static const growing = 'Growing_Embercrest_asset.mp3';
}

/// Plays music and sound effects, and guarantees everything is silenced when
/// the app leaves the foreground or is closed.
///
/// The asset pack ships only short clips, so the "music" beds are the two
/// longest rumbles looped quietly underneath the game.
class Audio with WidgetsBindingObserver {
  Audio._();
  static final Audio instance = Audio._();

  static const _poolSize = 6;
  final List<AudioPlayer> _pool = [];
  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  final Map<String, double> _lastPlayed = {};

  bool _ready = false;
  bool _disposed = false;
  bool musicEnabled = true;
  bool sfxEnabled = true;
  double musicVolume = 0.45;
  double sfxVolume = 0.85;

  String? _currentTrack;
  int _next = 0;
  final Stopwatch _clock = Stopwatch()..start();

  Future<void> init({required bool music, required bool sfx}) async {
    if (_ready) return;
    musicEnabled = music;
    sfxEnabled = sfx;

    // The clips ship as `sounds/...` asset keys, but AudioCache prepends
    // `assets/` unless the prefix is cleared, and swallows the miss silently.
    AudioCache.instance.prefix = '';

    // A device that refuses one of these calls should still get a playable
    // game, just a quieter one.
    try {
      // Game audio ducks rather than fights other apps, and must never keep
      // the audio session alive in the background.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          // `ambient` already mixes with other apps, respects the ring switch
          // and never plays in the background, which is what a casual game
          // wants. It also rejects an explicit `mixWithOthers` option.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {},
          ),
        ),
      );

      for (var i = 0; i < _poolSize; i++) {
        final p = AudioPlayer(playerId: 'sfx$i');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(p);
      }
      await _music.setReleaseMode(ReleaseMode.loop);
    } catch (_) {
      // Leave whatever players were created; play() tolerates failures.
    }

    WidgetsBinding.instance.addObserver(this);
    _ready = true;
  }

  /// Warms the decoder for the clips used during a run so the first hit of
  /// each does not stutter.
  Future<void> preload(List<String> names) async {
    for (final n in names) {
      try {
        await AudioCache.instance.load(_path(n));
      } catch (e) {
        // A clip failing to pre-cache is never worth breaking startup over,
        // but a silent miss here is how a whole soundtrack goes missing.
        debugPrint('audio: could not preload ${_path(n)} ($e)');
      }
    }
  }

  String _path(String name) => 'sounds/$name';

  void play(String name, {double volume = 1.0, double minGap = 0.05}) {
    if (!_ready || _disposed || !sfxEnabled || _pool.isEmpty) return;

    // Several game events can fire on the same frame; without a small gate the
    // same clip stacks on itself and clips the output.
    final now = _clock.elapsedMicroseconds / 1e6;
    final last = _lastPlayed[name];
    if (last != null && now - last < minGap) return;
    _lastPlayed[name] = now;

    final player = _pool[_next % _pool.length];
    _next = (_next + 1) % _pool.length;
    unawaited(player
        .play(AssetSource(_path(name)), volume: (volume * sfxVolume).clamp(0.0, 1.0))
        .catchError((_) {}));
  }

  Future<void> playMusic(String name) async {
    if (!_ready || _disposed) return;
    if (_currentTrack == name && _music.state == PlayerState.playing) return;
    _currentTrack = name;
    if (!musicEnabled) return;
    try {
      await _music.stop();
      await _music.setVolume(musicVolume);
      await _music.play(AssetSource(_path(name)), volume: musicVolume);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    if (!_ready) return;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    if (!value) {
      try {
        await _music.stop();
      } catch (_) {}
    } else if (_currentTrack != null) {
      final track = _currentTrack!;
      _currentTrack = null;
      await playMusic(track);
    }
  }

  void setSfxEnabled(bool value) {
    sfxEnabled = value;
    if (!value) _stopAllSfx();
  }

  void _stopAllSfx() {
    for (final p in _pool) {
      unawaited(p.stop().catchError((_) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || _disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (musicEnabled && _currentTrack != null) {
          unawaited(_music.resume().catchError((_) {}));
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Leaving the foreground must silence everything immediately,
        // otherwise the loop keeps playing over the home screen.
        unawaited(_music.pause().catchError((_) {}));
        _stopAllSfx();
      case AppLifecycleState.detached:
        unawaited(shutdown());
    }
  }

  /// Stops and releases every player. Safe to call more than once.
  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    _currentTrack = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final p in [..._pool, _music]) {
      try {
        await p.stop();
        await p.release();
        await p.dispose();
      } catch (_) {}
    }
    _pool.clear();
    try {
      AudioCache.instance.clearAll();
    } catch (_) {}
  }
}

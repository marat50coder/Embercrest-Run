import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../core/atlas.dart';
import '../core/audio.dart';
import 'config.dart';
import 'world.dart';

enum RunState { intro, running, dying, over }

/// One piece of the crest. Segments are pooled: a run recycles a few hundred
/// of these instead of allocating on every frame.
class RoadSegment {
  double x = 0, y = 0, angle = 0;
  double age = 0, life = 1;
  int index = 0;
  bool crystallized = false;
  MagmaType? magma;

  double get t => age / life;
  bool get cracking => !crystallized && t > 0.74;
  bool get dead => !crystallized && age >= life;
}

class Particle {
  double x = 0, y = 0, vx = 0, vy = 0;
  double life = 0, maxLife = 1, scale = 1, growth = 0;
  double rotation = 0, spin = 0;
  int color = 0xFFFFFFFF;
  bool fade = true;
  late Sprite sprite;
}

/// Floating "+3" style text that rises off a pickup.
class FloatText {
  double x = 0, y = 0, life = 0;
  String text = '';
  int color = 0xFFFFFFFF;
}

/// The whole run: hero, crest, world streaming, collisions and scoring.
///
/// Rendering never touches the sim; [GameRenderer] only reads these fields.
class Simulation {
  Simulation(this.atlas, {int? seed})
      : world = World(atlas, seed ?? DateTime.now().millisecondsSinceEpoch),
        _rng = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final SpriteAtlas atlas;
  final World world;
  final math.Random _rng;

  // ------------------------------------------------------------ tuning
  static const double segmentSpacing = 26;
  static const double roadWidth = 68;
  static const double heroRadius = 24;
  static const double unitsPerMetre = 10;
  static const double baseSpeed = 255;
  static const double maxSpeed = 470;
  static const double turnRate = 2.9;
  static const double maxEnergy = 100;
  static const int crystalSegments = 16;
  static const double crystalCooldown = 9;

  // ------------------------------------------------------------ hero
  double heroX = 0, heroY = 0;
  double heading = -math.pi / 2;
  double speed = baseSpeed;
  double steer = 0;

  // ------------------------------------------------------------ run stats
  RunState state = RunState.intro;
  double time = 0;
  final Stopwatch _deathClock = Stopwatch();
  double travelled = 0;
  int distance = 0;
  int longestChain = 0;
  int coresActivated = 0;
  int maxCombo = 0;
  int combo = 0;
  double comboTimer = 0;
  bool noCollapse = true;
  double energy = maxEnergy;
  double pressure = 0;
  int biomeIndex = 0;
  Biome biome = Biome.all.first;
  final Map<ResourceKind, int> collected = {
    for (final k in ResourceKind.values) k: 0
  };
  final Set<MagmaType> magmaUsed = {};
  final Set<int> artifactsFound = {};
  String? deathCause;

  // ------------------------------------------------------------ abilities
  MagmaType? activeMagma;
  double magmaTimer = 0;
  double crystalTimer = 0;
  bool get crystalReady => crystalTimer <= 0;

  // ------------------------------------------------------------ crest
  final List<RoadSegment> road = [];
  final List<RoadSegment> _pool = [];
  int _segmentCounter = 0;
  double _sinceSegment = 0;

  // ------------------------------------------------------------ fx
  final List<Particle> particles = [];
  final List<Particle> _particlePool = [];
  final List<FloatText> floats = [];
  final List<FloatText> _floatPool = [];
  double shake = 0;
  bool shakeEnabled = true;
  double flash = 0;
  int flashColor = 0xFFFF7A18;
  double slowMotion = 1;

  // callbacks the screen listens to
  void Function(String message, int color)? onBanner;
  void Function()? onGameOver;

  // ------------------------------------------------------------ derived
  int get chainLength => road.length;
  double get energyFraction => (energy / maxEnergy).clamp(0.0, 1.0);
  double get pressureFraction => (pressure / 100).clamp(0.0, 1.0);
  double get comboMultiplier => 1 + combo * 0.1;
  double get magmaFraction => activeMagma == null
      ? 0
      : (magmaTimer / MagmaInfo.of(activeMagma!).duration).clamp(0.0, 1.0);

  int get score =>
      distance + collected.values.fold(0, (a, b) => a + b) * 12 + coresActivated * 80;

  RunResult get result => RunResult(
        distance: distance,
        longestChain: longestChain,
        coresActivated: coresActivated,
        biomeReached: biomeIndex,
        maxCombo: maxCombo,
        noCollapse: noCollapse,
        collected: Map.of(collected),
        magmaUsed: Set.of(magmaUsed),
        artifactsFound: Set.of(artifactsFound),
      );

  // ------------------------------------------------------------ lifecycle
  void start() {
    state = RunState.intro;
    time = 0;
    _layFirstSegments();
    Audio.instance.play(Sfx.startRun, volume: 0.9);
  }

  void _layFirstSegments() {
    for (var i = 12; i > 0; i--) {
      final s = _take();
      s.x = heroX - math.cos(heading) * segmentSpacing * i;
      s.y = heroY - math.sin(heading) * segmentSpacing * i;
      s.angle = heading;
      s.age = 0;
      s.life = _segmentLife();
      s.index = _segmentCounter++;
      s.crystallized = false;
      s.magma = null;
      road.add(s);
    }
  }

  RoadSegment _take() => _pool.isEmpty ? RoadSegment() : _pool.removeLast();

  // ------------------------------------------------------------ input
  void setSteer(double value) => steer = value.clamp(-1.0, 1.0);

  /// A flick of the thumb snaps the crest to a sharper heading.
  void sharpTurn(int direction) {
    if (state != RunState.running) return;
    heading += direction * 0.62;
    pressure = math.max(0, pressure - 45);
    shake = math.max(shake, 3);
    Audio.instance.play(Sfx.sharpTurn, volume: 0.6, minGap: 0.2);
  }

  void crystallize() {
    if (state != RunState.running || !crystalReady || energy < 10) return;
    crystalTimer = crystalCooldown;
    energy -= 10;
    var n = 0;
    for (var i = road.length - 1; i >= 0 && n < crystalSegments; i--, n++) {
      road[i].crystallized = true;
      road[i].age = 0;
    }
    for (var i = 0; i < 10; i++) {
      _spawnParticle(
        heroX + (_rng.nextDouble() - 0.5) * 90,
        heroY + (_rng.nextDouble() - 0.5) * 90,
        atlas.at('effects_vfx', 36 + _rng.nextInt(4)),
        life: 0.5,
        scale: 0.4,
        growth: 0.9,
        color: 0xFF8FE4FF,
      );
    }
    Audio.instance.play(Sfx.cooling, volume: 0.8);
    onBanner?.call('CRYSTALLISED', 0xFF6FD6FF);
  }

  // ------------------------------------------------------------ update
  void update(double dt) {
    if (state == RunState.over) return;

    dt *= slowMotion;
    time += dt;

    if (state == RunState.intro) {
      if (time > 0.85) state = RunState.running;
    }
    if (state == RunState.dying) {
      slowMotion = math.max(0.25, slowMotion - dt * 1.8);
      _updateFx(dt);
      // Wall clock, not game time: the death beat plays in slow motion, and a
      // scaled timer would leave the player staring at a frozen screen.
      if (_deathClock.elapsedMilliseconds > 900) {
        state = RunState.over;
        onGameOver?.call();
      }
      return;
    }

    _updateBiome();
    _updateMovement(dt);
    _updateCrest(dt);
    if (state != RunState.running && state != RunState.intro) return;
    _updateEnergy(dt);
    if (state != RunState.running && state != RunState.intro) return;
    _updatePressure(dt);
    _updateWorld(dt);
    _updateFx(dt);

    if (activeMagma != null) {
      magmaTimer -= dt;
      if (magmaTimer <= 0) {
        activeMagma = null;
      }
    }
    if (crystalTimer > 0) crystalTimer -= dt;
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 0;
    }
  }

  void _updateBiome() {
    final index = Biome.indexAt(distance);
    if (index != biomeIndex) {
      biomeIndex = index;
      biome = Biome.all[index];
      Audio.instance.play(Sfx.newBiome, volume: 0.9);
      onBanner?.call(biome.name.toUpperCase(), 0xFFFFB43C);
      flash = 0.5;
      flashColor = biome.tint.toARGB32();
    }
  }

  void _updateMovement(double dt) {
    final difficulty = math.min(1.0, distance / 2600);
    final target = baseSpeed + (maxSpeed - baseSpeed) * difficulty;

    var boost = 1.0;
    var pull = 0.0;
    for (final c in _nearbyCurrents) {
      final dx = heroX - c.x, dy = heroY - c.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < c.radius) {
        final w = 1 - d / c.radius;
        boost += 0.35 * w * c.strength;
        pull += _angleDelta(heading, c.angle) * w * c.strength * 1.4;
      }
    }
    _inCurrent = pull.abs() > 0.001;

    speed += (target * boost - speed) * math.min(1, dt * 2.2);
    heading += steer * turnRate * dt + pull * dt;

    final step = speed * dt;
    heroX += math.cos(heading) * step;
    heroY += math.sin(heading) * step;
    travelled += step;

    final metres = travelled ~/ unitsPerMetre;
    if (metres != distance) {
      if (metres ~/ 250 != distance ~/ 250) {
        Audio.instance.play(Sfx.milestone, volume: 0.55);
        flash = math.max(flash, 0.22);
        flashColor = 0xFFFFC24A;
      }
      distance = metres;
    }
  }

  bool _inCurrent = false;
  bool get inCurrent => _inCurrent;

  double _segmentLife() {
    final difficulty = math.min(1.0, distance / 3000);
    final base = 7.4 - difficulty * 3.6;
    final magma = activeMagma == MagmaType.crystalline ? 1.9 : 1.0;
    return base * biome.decayScale * magma;
  }

  void _updateCrest(double dt) {
    _sinceSegment += speed * dt;
    while (_sinceSegment >= segmentSpacing) {
      _sinceSegment -= segmentSpacing;
      final s = _take();
      s.x = heroX;
      s.y = heroY;
      s.angle = heading;
      s.age = 0;
      s.life = _segmentLife();
      s.index = _segmentCounter++;
      s.crystallized = false;
      s.magma = activeMagma;
      road.add(s);
      if (_segmentCounter % 7 == 0) {
        Audio.instance.play(Sfx.freshMagma, volume: 0.14, minGap: 0.4);
      }
    }

    var removed = 0;
    for (var i = 0; i < road.length; i++) {
      final s = road[i];
      if (!s.crystallized) s.age += dt;
      if (s.dead) removed++;
    }
    if (removed > 0) {
      for (var i = 0; i < removed; i++) {
        final s = road[i];
        if (_rng.nextDouble() < 0.25) {
          _spawnParticle(
            s.x,
            s.y,
            atlas.at('effects_vfx', 9 + _rng.nextInt(5)),
            life: 0.9,
            scale: 0.25,
            growth: 0.5,
            color: 0x66FFFFFF,
          );
        }
        _pool.add(s);
      }
      road.removeRange(0, removed);
      Audio.instance.play(Sfx.pathCollapse, volume: 0.18, minGap: 0.7);
    }

    if (road.length > longestChain) longestChain = road.length;
    _checkSelfCollision();
  }

  void _checkSelfCollision() {
    if (activeMagma == MagmaType.obsidian) return;
    // The newest segments are always underfoot, so only the older tail counts.
    final limit = _segmentCounter - 28;
    final hit = roadWidth * 0.40;
    for (final s in road) {
      if (s.index > limit) break;
      if (s.crystallized || !s.cracking) continue;
      final dx = heroX - s.x, dy = heroY - s.y;
      if (dx * dx + dy * dy < hit * hit) {
        noCollapse = false;
        _die('THE CREST GAVE WAY');
        return;
      }
    }
  }

  void _updateEnergy(double dt) {
    var drain = 3.4 + speed * 0.0062;
    if (_inCurrent) drain *= 0.55;
    if (activeMagma == MagmaType.living) drain -= 9;
    energy = (energy - drain * dt).clamp(0.0, maxEnergy);

    if (energy <= 0) {
      _die('THE MAGMA RAN DRY');
    } else if (energy < 22) {
      Audio.instance.play(Sfx.pathCracking, volume: 0.25, minGap: 1.4);
    }
  }

  void _updatePressure(double dt) {
    if (steer.abs() < 0.18) {
      pressure += dt * (7 + speed * 0.03);
    } else {
      pressure -= dt * 55 * steer.abs();
    }
    pressure = pressure.clamp(0.0, 100.0);

    if (pressure >= 100) {
      pressure = 25;
      _erupt();
    } else if (pressure > 78) {
      Audio.instance.play(Sfx.pressure, volume: 0.3, minGap: 2.2);
    }
  }

  /// Pressure release: a geyser bursts across the path ahead.
  void _erupt() {
    final ahead = 260 + _rng.nextDouble() * 140;
    final side = (_rng.nextDouble() - 0.5) * 150;
    final ex = heroX + math.cos(heading) * ahead - math.sin(heading) * side;
    final ey = heroY + math.sin(heading) * ahead + math.cos(heading) * side;

    _eruptions.add(Eruption(ex, ey, time));
    shake = math.max(shake, 9);
    Audio.instance.play(Sfx.eruption, volume: 0.7);
    onBanner?.call('PRESSURE RELEASE', 0xFFFF5A2B);

    for (var i = 0; i < 12; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      _spawnParticle(
        ex, ey,
        atlas.at('effects_vfx', 18 + _rng.nextInt(5)),
        life: 0.8,
        scale: 0.5,
        growth: 0.6,
        vx: math.cos(a) * 120,
        vy: math.sin(a) * 120,
        color: 0xFFFFAA55,
      );
    }
  }

  final List<Eruption> _eruptions = [];
  List<Eruption> get eruptions => _eruptions;

  // ------------------------------------------------------------ world pass
  final List<Current> _nearbyCurrents = [];
  final List<Chunk> visibleChunks = [];

  void collectVisible(double left, double top, double right, double bottom) {
    visibleChunks.clear();
    world.forEachVisible(
        left, top, right, bottom, biome, biomeIndex, visibleChunks.add);
  }

  void _updateWorld(double dt) {
    // Only chunks around the hero matter for physics; the renderer widens this
    // for drawing.
    const pad = World.chunkSize;
    _nearbyCurrents.clear();
    world.forEachVisible(heroX - pad, heroY - pad, heroX + pad, heroY + pad,
        biome, biomeIndex, (chunk) {
      _nearbyCurrents.addAll(chunk.currents);
      _collide(chunk, dt);
    });

    for (var i = _eruptions.length - 1; i >= 0; i--) {
      final e = _eruptions[i];
      final age = time - e.born;
      if (age > 2.6) {
        _eruptions.removeAt(i);
        continue;
      }
      if (age > 0.45 && age < 2.0) {
        final dx = heroX - e.x, dy = heroY - e.y;
        if (dx * dx + dy * dy < 62 * 62 && activeMagma != MagmaType.obsidian) {
          _die('CAUGHT BY AN ERUPTION');
        }
      }
    }
  }

  void _collide(Chunk chunk, double dt) {
    final magnetic = activeMagma == MagmaType.magnetic;
    final grabRange = magnetic ? 240.0 : heroRadius + 26;

    for (final p in chunk.pickups) {
      if (p.taken) continue;
      var dx = heroX - p.drawX, dy = heroY - p.drawY;
      var d2 = dx * dx + dy * dy;

      if (magnetic && d2 < grabRange * grabRange) {
        final d = math.sqrt(d2).clamp(1.0, 1e9);
        final pullSpeed = 520 * dt;
        p.drawX += dx / d * pullSpeed;
        p.drawY += dy / d * pullSpeed;
        dx = heroX - p.drawX;
        dy = heroY - p.drawY;
        d2 = dx * dx + dy * dy;
      }
      final reach = heroRadius + 28;
      if (d2 < reach * reach) _take_(p);
    }

    for (final o in chunk.obstacles) {
      if (o.destroyed) continue;
      final dx = heroX - o.x, dy = heroY - o.y;
      final r = o.radius + heroRadius * 0.6;
      if (dx * dx + dy * dy < r * r) {
        if (activeMagma == MagmaType.explosive) {
          o.destroyed = true;
          shake = math.max(shake, 7);
          Audio.instance.play(Sfx.explosiveMagma, volume: 0.7, minGap: 0.15);
          for (var i = 0; i < 8; i++) {
            final a = _rng.nextDouble() * math.pi * 2;
            _spawnParticle(o.x, o.y, atlas.at('effects_vfx', _rng.nextInt(9)),
                life: 0.55,
                scale: 0.4,
                growth: 0.7,
                vx: math.cos(a) * 190,
                vy: math.sin(a) * 190);
          }
        } else {
          _die('STRUCK A VOLCANIC VENT');
          return;
        }
      }
    }

    for (final c in chunk.cores) {
      if (c.taken) continue;
      final dx = heroX - c.x, dy = heroY - c.y;
      if (dx * dx + dy * dy < 60 * 60) {
        c.taken = true;
        _activateCore(c.type);
      }
    }

    for (final a in chunk.altars) {
      if (a.taken) continue;
      final dx = heroX - a.x, dy = heroY - a.y;
      if (dx * dx + dy * dy < 62 * 62) {
        a.taken = true;
        artifactsFound.add(a.index);
        energy = math.min(maxEnergy, energy + 25);
        Audio.instance.play(Sfx.victory, volume: 0.55);
        onBanner?.call('ARTIFACT FOUND', 0xFFFFD166);
        flash = math.max(flash, 0.35);
        flashColor = 0xFFFFD166;
      }
    }

    for (final cr in chunk.creatures) {
      if (cr.used) continue;
      final cx = cr.drawX(time), cy = cr.drawY(time);
      final dx = heroX - cx, dy = heroY - cy;
      final r = cr.friendly ? 58.0 : cr.sprite.w * cr.scale * 0.28 + heroRadius * 0.5;
      if (dx * dx + dy * dy < r * r) {
        if (cr.friendly) {
          cr.used = true;
          energy = math.min(maxEnergy, energy + 26);
          combo += 1;
          comboTimer = 3.2;
          Audio.instance.play(Sfx.creatureBuff, volume: 0.75);
          onBanner?.call('EMBER ALLY', 0xFF8FD94A);
          for (var i = 0; i < 8; i++) {
            _spawnParticle(cx, cy, atlas.at('effects_vfx', 44 + _rng.nextInt(5)),
                life: 0.6,
                scale: 0.35,
                growth: 0.5,
                vx: (_rng.nextDouble() - 0.5) * 140,
                vy: (_rng.nextDouble() - 0.5) * 140,
                color: 0xFFBFFF7A);
          }
        } else if (activeMagma == MagmaType.explosive) {
          cr.used = true;
          shake = math.max(shake, 6);
        } else {
          _die('A FIRE BEAST BLOCKED THE PATH');
          return;
        }
      }
    }
  }

  void _take_(Pickup p) {
    p.taken = true;
    final info = ResourceInfo.map[p.kind]!;
    collected[p.kind] = collected[p.kind]! + 1;

    combo += 1;
    comboTimer = 3.2;
    if (combo > maxCombo) maxCombo = combo;

    final gain = (5 + info.value * 2.2) * comboMultiplier;
    energy = math.min(maxEnergy, energy + gain);

    Audio.instance.play(info.rare ? Sfx.rareResource : Sfx.resource,
        volume: info.rare ? 0.85 : 0.5, minGap: 0.05);
    if (combo > 0 && combo % 8 == 0) {
      Audio.instance.play(combo >= 24 ? Sfx.highCombo : Sfx.combo, volume: 0.7);
    }

    _spawnFloat(p.drawX, p.drawY, '+${info.value}', info.color.toARGB32());
    for (var i = 0; i < (info.rare ? 8 : 4); i++) {
      _spawnParticle(
        p.drawX, p.drawY,
        atlas.at('effects_vfx', 44 + _rng.nextInt(5)),
        life: 0.45,
        scale: 0.3,
        growth: 0.4,
        vx: (_rng.nextDouble() - 0.5) * 160,
        vy: (_rng.nextDouble() - 0.5) * 160,
        color: info.color.toARGB32(),
      );
    }
  }

  void _activateCore(MagmaType type) {
    activeMagma = type;
    final info = MagmaInfo.of(type);
    magmaTimer = info.duration;
    coresActivated++;
    magmaUsed.add(type);
    energy = math.min(maxEnergy, energy + 30);
    shake = math.max(shake, 5);
    flash = math.max(flash, 0.45);
    flashColor = info.color.toARGB32();

    Audio.instance.play(Sfx.coreActivation, volume: 0.85);
    Audio.instance.play(
        switch (type) {
          MagmaType.magnetic => Sfx.magneticMagma,
          MagmaType.crystalline => Sfx.crystalMagma,
          MagmaType.explosive => Sfx.explosiveMagma,
          MagmaType.living => Sfx.livingMagma,
          MagmaType.obsidian => Sfx.cooling,
        },
        volume: 0.8);
    onBanner?.call(info.label.toUpperCase(), info.color.toARGB32());

    for (var i = 0; i < 14; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      _spawnParticle(heroX, heroY, atlas.at('effects_vfx', 36 + _rng.nextInt(4)),
          life: 0.7,
          scale: 0.3,
          growth: 1.1,
          vx: math.cos(a) * 150,
          vy: math.sin(a) * 150,
          color: info.color.toARGB32());
    }
  }

  void _die(String cause) {
    if (state == RunState.dying || state == RunState.over) return;
    state = RunState.dying;
    deathCause = cause;
    _deathClock
      ..reset()
      ..start();
    shake = 14;
    flash = 0.6;
    flashColor = 0xFFFF3B30;
    Audio.instance.play(Sfx.gameOver, volume: 0.9);
    Audio.instance.play(Sfx.pathCollapse, volume: 0.8);

    for (var i = 0; i < 18; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      _spawnParticle(heroX, heroY, atlas.at('effects_vfx', _rng.nextInt(9)),
          life: 1.0,
          scale: 0.5,
          growth: 0.9,
          vx: math.cos(a) * 230,
          vy: math.sin(a) * 230);
    }
  }

  // ------------------------------------------------------------ fx helpers
  void _spawnParticle(
    double x,
    double y,
    Sprite sprite, {
    double life = 0.6,
    double scale = 0.4,
    double growth = 0.4,
    double vx = 0,
    double vy = 0,
    int color = 0xFFFFFFFF,
  }) {
    if (particles.length > 260) return;
    final p = _particlePool.isEmpty ? Particle() : _particlePool.removeLast();
    p
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..life = life
      ..maxLife = life
      ..scale = scale
      ..growth = growth
      ..rotation = _rng.nextDouble() * math.pi * 2
      ..spin = (_rng.nextDouble() - 0.5) * 2.4
      ..color = color
      ..sprite = sprite;
    particles.add(p);
  }

  void _spawnFloat(double x, double y, String text, int color) {
    final f = _floatPool.isEmpty ? FloatText() : _floatPool.removeLast();
    f
      ..x = x
      ..y = y
      ..life = 0.9
      ..text = text
      ..color = color;
    floats.add(f);
  }

  void _updateFx(double dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particlePool.add(particles.removeAt(i));
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 1 - 2.2 * dt;
      p.vy *= 1 - 2.2 * dt;
      p.rotation += p.spin * dt;
      p.scale += p.growth * dt;
    }
    for (var i = floats.length - 1; i >= 0; i--) {
      final f = floats[i];
      f.life -= dt;
      f.y -= 42 * dt;
      if (f.life <= 0) _floatPool.add(floats.removeAt(i));
    }
    if (shake > 0) shake = math.max(0, shake - dt * 22);
    if (flash > 0) flash = math.max(0, flash - dt * 1.6);
  }

  Offset get shakeOffset => (shake <= 0 || !shakeEnabled)
      ? Offset.zero
      : Offset((_rng.nextDouble() - 0.5) * shake, (_rng.nextDouble() - 0.5) * shake);

  static double _angleDelta(double from, double to) {
    var d = (to - from) % (math.pi * 2);
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    return d;
  }
}

/// A geyser triggered by volcano pressure, lethal while it is spouting.
class Eruption {
  final double x, y, born;
  Eruption(this.x, this.y, this.born);
}

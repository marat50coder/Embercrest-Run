import 'dart:math' as math;

import '../core/atlas.dart';
import 'config.dart';

/// A collectible resource lying on the lava field.
class Pickup {
  final double x, y;
  final ResourceKind kind;
  final Sprite sprite;
  final double phase;
  double drawX, drawY;
  bool taken = false;

  Pickup(this.x, this.y, this.kind, this.sprite, this.phase)
      : drawX = x,
        drawY = y;
}

/// A static hazard. Touching one ends the run unless explosive magma is up.
class Obstacle {
  final double x, y;
  final Sprite sprite;
  final double scale;
  final double radius;
  bool destroyed = false;

  Obstacle(this.x, this.y, this.sprite, this.scale)
      : radius = sprite.w * scale * 0.30;
}

/// An ancient core; driving over it grants a magma type for a while.
class CoreOrb {
  final double x, y;
  final MagmaType type;
  bool taken = false;
  CoreOrb(this.x, this.y, this.type);
}

/// A collectible altar that fills a slot in the artifact collection.
class Altar {
  final double x, y;
  final int index;
  bool taken = false;
  Altar(this.x, this.y, this.index);
}

/// A fire creature. Friendly ones buff the crest, hostile ones behave like a
/// moving obstacle.
class Creature {
  final double x, y;
  final Sprite sprite;
  final bool friendly;
  final double phase;
  final double range;
  final double scale;
  bool used = false;

  Creature(this.x, this.y, this.sprite, this.friendly, this.phase, this.range,
      this.scale);

  double drawX(double t) => x + math.cos(t * 0.8 + phase) * range;
  double drawY(double t) => y + math.sin(t * 0.6 + phase) * range * 0.6;
}

/// A hidden magma stream that speeds the crest up and bends its heading.
class Current {
  final double x, y, radius, angle, strength;
  Current(this.x, this.y, this.radius, this.angle, this.strength);
}

/// Ground dressing drawn beneath the road.
class Decor {
  final double x, y, rotation, scale;
  final Sprite sprite;
  final int color;
  Decor(this.x, this.y, this.sprite, this.scale, this.rotation, this.color);
}

class Chunk {
  final List<Decor> decor = [];
  final List<Pickup> pickups = [];
  final List<Obstacle> obstacles = [];
  final List<CoreOrb> cores = [];
  final List<Altar> altars = [];
  final List<Creature> creatures = [];
  final List<Current> currents = [];
}

/// Builds and caches the endless volcano surface in fixed-size chunks.
///
/// A chunk is generated the first time it comes near the camera and keyed by
/// its grid coordinate, so revisiting an area shows the same content. The
/// biome in force when a chunk is first generated is baked into it.
class World {
  static const double chunkSize = 620;
  static const int _keyBias = 32768;

  final SpriteAtlas atlas;
  final int seed;
  final Map<int, Chunk> _chunks = {};
  final List<int> _order = [];

  World(this.atlas, this.seed);

  static int _key(int cx, int cy) => (cx + _keyBias) * 65536 + (cy + _keyBias);

  Chunk chunkAt(int cx, int cy, Biome biome, int biomeIndex) {
    final k = _key(cx, cy);
    final existing = _chunks[k];
    if (existing != null) return existing;

    final chunk = _generate(cx, cy, biome, biomeIndex);
    _chunks[k] = chunk;
    _order.add(k);

    // Keep memory flat on long runs; distant chunks will simply regenerate.
    if (_order.length > 220) {
      _chunks.remove(_order.removeAt(0));
    }
    return chunk;
  }

  /// Every chunk overlapping the view, generating any that are missing.
  void forEachVisible(
    double left,
    double top,
    double right,
    double bottom,
    Biome biome,
    int biomeIndex,
    void Function(Chunk) fn,
  ) {
    final cx0 = (left / chunkSize).floor();
    final cx1 = (right / chunkSize).floor();
    final cy0 = (top / chunkSize).floor();
    final cy1 = (bottom / chunkSize).floor();
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        fn(chunkAt(cx, cy, biome, biomeIndex));
      }
    }
  }

  Chunk _generate(int cx, int cy, Biome biome, int biomeIndex) {
    final rng = math.Random(Object.hash(seed, cx, cy) & 0x7FFFFFFF);
    final chunk = Chunk();
    final ox = cx * chunkSize;
    final oy = cy * chunkSize;

    double px() => ox + rng.nextDouble() * chunkSize;
    double py() => oy + rng.nextDouble() * chunkSize;

    // The spawn chunk stays clear so the first seconds are never unfair.
    final isSpawn = cx == 0 && cy == 0;

    for (var i = 0; i < 5 + rng.nextInt(4); i++) {
      final name = biome.decorSprites[rng.nextInt(biome.decorSprites.length)];
      chunk.decor.add(Decor(
        px(),
        py(),
        atlas[name],
        0.55 + rng.nextDouble() * 0.75,
        rng.nextDouble() * math.pi * 2,
        0x66FFFFFF,
      ));
    }

    final resourceCount =
        (3 + rng.nextInt(4)) * biome.resourceDensity ~/ 1 + 1;
    for (var i = 0; i < resourceCount; i++) {
      final kind = ResourceInfo.roll(rng, biome.rareBias);
      final info = ResourceInfo.map[kind]!;
      final sprite = atlas[info.sprites[rng.nextInt(info.sprites.length)]];
      chunk.pickups.add(
          Pickup(px(), py(), kind, sprite, rng.nextDouble() * math.pi * 2));
    }

    if (!isSpawn) {
      final obstacleCount = (biome.obstacleDensity * (1 + rng.nextInt(3))).round();
      for (var i = 0; i < obstacleCount; i++) {
        final sprite = atlas['volcanic_obstacles/'
            '${rng.nextInt(16).toString().padLeft(2, '0')}'];
        chunk.obstacles.add(
            Obstacle(px(), py(), sprite, 0.75 + rng.nextDouble() * 0.5));
      }

      if (rng.nextDouble() < 0.20) {
        chunk.cores.add(CoreOrb(
            px(), py(), MagmaType.values[rng.nextInt(MagmaType.values.length)]));
      }
      if (rng.nextDouble() < 0.07) {
        chunk.altars.add(Altar(px(), py(), rng.nextInt(Artifacts.all.length)));
      }
      if (rng.nextDouble() < 0.28) {
        final friendly = rng.nextDouble() < 0.6;
        final pool = friendly
            ? const [0, 1, 2, 3, 4, 15, 16, 17, 18, 19]
            : const [20, 21, 22, 23, 24, 30, 31, 32, 33, 34];
        final id = pool[rng.nextInt(pool.length)];
        chunk.creatures.add(Creature(
          px(),
          py(),
          atlas['enemyes/${id.toString().padLeft(2, '0')}'],
          friendly,
          rng.nextDouble() * math.pi * 2,
          18 + rng.nextDouble() * 26,
          0.55 + rng.nextDouble() * 0.3,
        ));
      }
      if (rng.nextDouble() < 0.22 * biome.currentStrength) {
        chunk.currents.add(Current(
          px(),
          py(),
          130 + rng.nextDouble() * 120,
          rng.nextDouble() * math.pi * 2,
          0.6 + rng.nextDouble() * 0.8,
        ));
      }
    }
    return chunk;
  }
}

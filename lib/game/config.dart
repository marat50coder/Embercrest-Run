import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';

// ---------------------------------------------------------------- resources

enum ResourceKind { amber, obsidian, core, essence, shard }

class ResourceInfo {
  final String label;
  final List<String> sprites;
  final int value;
  final double weight;
  final Color color;
  final bool rare;

  const ResourceInfo(
      this.label, this.sprites, this.value, this.weight, this.color,
      {this.rare = false});

  static const map = <ResourceKind, ResourceInfo>{
    ResourceKind.amber: ResourceInfo('Amber Crystal',
        ['resources/00', 'resources/07'], 1, 0.40, Pal.gold),
    ResourceKind.obsidian:
        ResourceInfo('Obsidian', ['resources/01'], 2, 0.22, Pal.obsidian),
    ResourceKind.essence: ResourceInfo('Fire Essence',
        ['resources/03', 'resources/08'], 3, 0.18, Pal.lava),
    ResourceKind.core: ResourceInfo('Volcanic Core',
        ['resources/02', 'resources/09', 'resources/10'], 5, 0.14, Pal.ember),
    ResourceKind.shard: ResourceInfo(
        'Magma Shard',
        ['resources/05', 'resources/04', 'resources/11', 'resources/06'],
        8,
        0.06,
        Pal.crystal,
        rare: true),
  };

  static ResourceKind roll(math.Random rng, double rareBias) {
    var r = rng.nextDouble();
    for (final entry in map.entries) {
      final w = entry.value.rare
          ? entry.value.weight * (1 + rareBias * 3)
          : entry.value.weight;
      if (r < w) return entry.key;
      r -= w;
    }
    return ResourceKind.amber;
  }
}

// -------------------------------------------------------------- magma types

enum MagmaType { magnetic, crystalline, obsidian, explosive, living }

class MagmaInfo {
  final String label;
  final String description;
  final String roadSprite;
  final String coreSprite;
  final String orbSprite;
  final Color color;
  final double duration;

  const MagmaInfo(this.label, this.description, this.roadSprite,
      this.coreSprite, this.orbSprite, this.color, this.duration);

  static const map = <MagmaType, MagmaInfo>{
    MagmaType.magnetic: MagmaInfo(
        'Magnetic Magma',
        'Pulls every nearby resource onto your crest.',
        'roadmagma/06',
        'ancient_volcanic_cores/05',
        'types_magma/07',
        Color(0xFFFFC94A),
        11),
    MagmaType.crystalline: MagmaInfo(
        'Crystalline Magma',
        'The crest cools slowly and holds far longer.',
        'roadmagma/07',
        'ancient_volcanic_cores/06',
        'types_magma/03',
        Pal.crystal,
        13),
    MagmaType.obsidian: MagmaInfo(
        'Obsidian Magma',
        'Your own path can no longer collapse under you.',
        'roadmagma/05',
        'ancient_volcanic_cores/02',
        'types_magma/05',
        Pal.obsidian,
        11),
    MagmaType.explosive: MagmaInfo(
        'Explosive Magma',
        'Blasts obstacles apart as you drive through them.',
        'roadmagma/03',
        'ancient_volcanic_cores/03',
        'types_magma/02',
        Color(0xFFFF5A2B),
        10),
    MagmaType.living: MagmaInfo(
        'Living Magma',
        'The crest feeds itself — energy regenerates.',
        'roadmagma/04',
        'ancient_volcanic_cores/04',
        'types_magma/06',
        Color(0xFF8FD94A),
        12),
  };

  static MagmaInfo of(MagmaType t) => map[t]!;
}

// ------------------------------------------------------------------- biomes

class Biome {
  final String name;
  final String background;
  final Color tint;
  final double decayScale;
  final double obstacleDensity;
  final double resourceDensity;
  final double currentStrength;
  final double rareBias;
  final List<String> decorSprites;

  const Biome({
    required this.name,
    required this.background,
    required this.tint,
    required this.decayScale,
    required this.obstacleDensity,
    required this.resourceDensity,
    required this.currentStrength,
    required this.rareBias,
    required this.decorSprites,
  });

  /// Distance in metres before the next biome takes over.
  static const span = 850;

  static const all = <Biome>[
    Biome(
      name: 'Ashen Plains',
      background: 'assets/bg_location_1_asset.webp',
      tint: Color(0xFFFFB27A),
      decayScale: 1.25,
      obstacleDensity: 0.55,
      resourceDensity: 1.15,
      currentStrength: 0.5,
      rareBias: 0.0,
      decorSprites: ['decorative_elements/00', 'decorative_elements/04',
          'decorative_elements/02', 'vulcanic_island/00'],
    ),
    Biome(
      name: 'Lava Whirlpools',
      background: 'assets/bg_location_2_asset.webp',
      tint: Color(0xFFFF9A5A),
      decayScale: 1.05,
      obstacleDensity: 0.95,
      resourceDensity: 1.0,
      currentStrength: 1.4,
      rareBias: 0.15,
      decorSprites: ['decorative_elements/06', 'vulcanic_island/04',
          'decorative_elements/12', 'vulcanic_island/10'],
    ),
    Biome(
      name: 'Obsidian Canyons',
      background: 'assets/bg_location_3_asset.webp',
      tint: Color(0xFFB89BFF),
      decayScale: 0.95,
      obstacleDensity: 1.15,
      resourceDensity: 0.95,
      currentStrength: 0.8,
      rareBias: 0.3,
      decorSprites: ['decorative_elements/10', 'decorative_elements/15',
          'vulcanic_island/13', 'decorative_elements/03'],
    ),
    Biome(
      name: 'Magma Lakes',
      background: 'assets/bg_location_4_asset.webp',
      tint: Color(0xFFFF8347),
      decayScale: 0.88,
      obstacleDensity: 1.25,
      resourceDensity: 1.1,
      currentStrength: 1.6,
      rareBias: 0.4,
      decorSprites: ['decorative_elements/06', 'vulcanic_island/02',
          'decorative_elements/17', 'vulcanic_island/08'],
    ),
    Biome(
      name: 'Fire Forests',
      background: 'assets/bg_location_5_asset.webp',
      tint: Color(0xFFFFA24A),
      decayScale: 0.82,
      obstacleDensity: 1.3,
      resourceDensity: 1.2,
      currentStrength: 1.0,
      rareBias: 0.55,
      decorSprites: ['vulcanic_plants/00', 'vulcanic_plants/07',
          'vulcanic_plants/09', 'vulcanic_plants/13', 'vulcanic_plants/02'],
    ),
    Biome(
      name: 'Heart of the Volcano',
      background: 'assets/bg_location_6_asset.webp',
      tint: Color(0xFFFF6A3C),
      decayScale: 0.72,
      obstacleDensity: 1.55,
      resourceDensity: 1.25,
      currentStrength: 1.9,
      rareBias: 0.8,
      decorSprites: ['decorative_elements/01', 'decorative_elements/09',
          'vulcanic_island/14', 'decorative_elements/13'],
    ),
  ];

  static Biome at(int distance) =>
      all[((distance ~/ span) % all.length).clamp(0, all.length - 1)];

  static int indexAt(int distance) => (distance ~/ span) % all.length;
}

// -------------------------------------------------------------------- skins

class Skin {
  final String name;
  final String sprite;
  final int price;
  final String perk;

  const Skin(this.name, this.sprite, this.price, this.perk);

  static const all = <Skin>[
    Skin('Emberguard', 'main_character_with_skins/00', 0, 'The first walker.'),
    Skin('Flamecaller', 'main_character_with_skins/01', 40, 'Born of open fire.'),
    Skin('Cinder Knight', 'main_character_with_skins/02', 60, 'Forged in black ash.'),
    Skin('Crown of Ash', 'main_character_with_skins/03', 90, 'Wears the crest itself.'),
    Skin('Solar Herald', 'main_character_with_skins/04', 130, 'Too bright to look at.'),
    Skin('Runebound', 'main_character_with_skins/05', 170, 'Carved with old marks.'),
    Skin('Living Flame', 'main_character_with_skins/06', 210, 'Never truly cools.'),
    Skin('Basalt Warden', 'main_character_with_skins/07', 260, 'Older than the caldera.'),
    Skin('Goldveined', 'main_character_with_skins/08', 320, 'Molten gold in its seams.'),
    Skin('Frostcore', 'main_character_with_skins/09', 400, 'The impossible one.'),
  ];
}

// ---------------------------------------------------------------- artifacts

class Artifacts {
  static const all = <String>[
    'ancient_altars/00', 'ancient_altars/01', 'ancient_altars/02',
    'ancient_altars/03', 'ancient_altars/04', 'ancient_altars/05',
    'ancient_altars/06', 'ancient_altars/07', 'ancient_altars/08',
    'ancient_altars/09', 'ancient_altars/10', 'ancient_altars/11',
    'ancient_altars/12', 'ancient_altars/13', 'ancient_altars/14',
    'ancient_altars/15', 'ancient_altars/16', 'ancient_altars/17',
  ];

  static const names = <String>[
    'Ember Seal', 'Spire of Dawn', 'Runed Disc', 'Sunwheel', 'Hexstone',
    'Warden Ring', 'Three Pillars', 'Circle of Glyphs', 'Reliquary', 'Deep Dial',
    'Ashen Bloom', 'Obelisk', 'Cross of Coals', 'Twin Runes', 'Flame Cradle',
    'Orb Mount', 'Magma Font', 'Spiral Gate',
  ];
}

// ------------------------------------------------------------------- quests

enum QuestKind { distance, resources, chain, cores, biomes, magma, cleanRun }

class Quest {
  final QuestKind kind;
  final int target;
  final int reward;
  int progress;

  Quest(this.kind, this.target, this.reward, {this.progress = 0});

  bool get done => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0);

  String get label => switch (kind) {
        QuestKind.distance => 'Travel $target m in total',
        QuestKind.resources => 'Collect $target resources',
        QuestKind.chain => 'Hold a crest of $target segments',
        QuestKind.cores => 'Activate $target ancient cores',
        QuestKind.biomes => 'Reach biome $target',
        QuestKind.magma => 'Use $target kinds of magma',
        QuestKind.cleanRun => 'Finish a run without losing the crest',
      };

  int measure(RunResult r) => switch (kind) {
        QuestKind.distance => r.distance,
        QuestKind.resources => r.totalCollected,
        QuestKind.chain => r.longestChain >= target ? target : 0,
        QuestKind.cores => r.coresActivated,
        QuestKind.biomes => r.biomeReached + 1 >= target ? target : 0,
        QuestKind.magma => r.magmaUsed.length,
        QuestKind.cleanRun => r.noCollapse ? 1 : 0,
      };

  Map<String, dynamic> toJson() =>
      {'k': kind.index, 't': target, 'r': reward, 'p': progress};

  static Quest fromJson(Map<String, dynamic> j) => Quest(
      QuestKind.values[j['k'] as int], j['t'] as int, j['r'] as int,
      progress: j['p'] as int);

  static List<Quest> rollDaily(int seed) {
    final rng = math.Random(seed);
    final kinds = List<QuestKind>.from(QuestKind.values)..shuffle(rng);
    return [
      for (final k in kinds.take(3))
        switch (k) {
          QuestKind.distance => Quest(k, 600 + rng.nextInt(5) * 200, 12),
          QuestKind.resources => Quest(k, 25 + rng.nextInt(4) * 10, 10),
          QuestKind.chain => Quest(k, 40 + rng.nextInt(4) * 10, 14),
          QuestKind.cores => Quest(k, 2 + rng.nextInt(3), 16),
          QuestKind.biomes => Quest(k, 2 + rng.nextInt(3), 18),
          QuestKind.magma => Quest(k, 2 + rng.nextInt(2), 15),
          QuestKind.cleanRun => Quest(k, 1, 20),
        }
    ];
  }
}

// --------------------------------------------------------------- run result

class RunResult {
  final int distance;
  final int longestChain;
  final int coresActivated;
  final int biomeReached;
  final int maxCombo;
  final bool noCollapse;
  final Map<ResourceKind, int> collected;
  final Set<MagmaType> magmaUsed;
  final Set<int> artifactsFound;

  const RunResult({
    required this.distance,
    required this.longestChain,
    required this.coresActivated,
    required this.biomeReached,
    required this.maxCombo,
    required this.noCollapse,
    required this.collected,
    required this.magmaUsed,
    required this.artifactsFound,
  });

  int get totalCollected =>
      collected.values.fold(0, (a, b) => a + b);

  int get score => distance + totalCollected * 12 + coresActivated * 80;
}

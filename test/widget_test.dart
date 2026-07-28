import 'package:embercrest_run/game/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every configured sprite name is well formed', () {
    final names = <String>[
      for (final info in ResourceInfo.map.values) ...info.sprites,
      for (final info in MagmaInfo.map.values) ...[
        info.roadSprite,
        info.coreSprite,
        info.orbSprite,
      ],
      for (final biome in Biome.all) ...biome.decorSprites,
      for (final skin in Skin.all) skin.sprite,
      ...Artifacts.all,
    ];
    for (final name in names) {
      expect(RegExp(r'^[A-Za-z_]+/\d{2}$').hasMatch(name), isTrue,
          reason: '"$name" is not a "<group>/<index>" sprite key');
    }
  });

  test('biomes advance and wrap with distance', () {
    expect(Biome.indexAt(0), 0);
    expect(Biome.indexAt(Biome.span - 1), 0);
    expect(Biome.indexAt(Biome.span), 1);
    expect(Biome.indexAt(Biome.span * Biome.all.length), 0);
  });

  test('artifact names cover every artifact sprite', () {
    expect(Artifacts.names.length, Artifacts.all.length);
  });

  test('daily quests are deterministic for a given day', () {
    final a = Quest.rollDaily(4242);
    final b = Quest.rollDaily(4242);
    expect(a.length, 3);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].kind, b[i].kind);
      expect(a[i].target, b[i].target);
    }
  });

  test('a run result scores distance, resources and cores', () {
    const result = RunResult(
      distance: 500,
      longestChain: 40,
      coresActivated: 2,
      biomeReached: 1,
      maxCombo: 5,
      noCollapse: true,
      collected: {ResourceKind.amber: 10},
      magmaUsed: {},
      artifactsFound: {},
    );
    expect(result.totalCollected, 10);
    expect(result.score, 500 + 10 * 12 + 2 * 80);
  });
}

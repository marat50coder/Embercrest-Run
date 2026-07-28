import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/config.dart';

/// Player profile: records, wallet, unlocks and daily quests.
class Save extends ChangeNotifier {
  Save._(this._prefs);

  static late Save instance;
  final SharedPreferences _prefs;

  static Future<Save> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance = Save._(prefs);
    instance._rollQuestsIfNewDay();
    return instance;
  }

  // ---------------------------------------------------------------- records
  int get bestDistance => _prefs.getInt('bestDistance') ?? 0;
  int get bestChain => _prefs.getInt('bestChain') ?? 0;
  int get totalRuns => _prefs.getInt('totalRuns') ?? 0;
  int get totalDistance => _prefs.getInt('totalDistance') ?? 0;

  // ---------------------------------------------------------------- wallet
  int resource(ResourceKind k) => _prefs.getInt('res_${k.name}') ?? 0;

  Map<ResourceKind, int> get wallet =>
      {for (final k in ResourceKind.values) k: resource(k)};

  int get emberShards => resource(ResourceKind.shard);

  // ---------------------------------------------------------------- unlocks
  Set<int> get unlockedSkins =>
      (_prefs.getStringList('skins') ?? ['0']).map(int.parse).toSet();

  int get selectedSkin => _prefs.getInt('skin') ?? 0;

  set selectedSkin(int v) {
    _prefs.setInt('skin', v);
    notifyListeners();
  }

  bool isSkinUnlocked(int i) => i == 0 || unlockedSkins.contains(i);

  bool buySkin(int index) {
    final price = Skin.all[index].price;
    if (isSkinUnlocked(index) || resource(ResourceKind.shard) < price) return false;
    _spend(ResourceKind.shard, price);
    _prefs.setStringList(
        'skins', {...unlockedSkins, index}.map((e) => e.toString()).toList());
    selectedSkin = index;
    return true;
  }

  int get biomesSeen => _prefs.getInt('biomesSeen') ?? 1;
  Set<int> get magmaFound =>
      (_prefs.getStringList('magma') ?? []).map(int.parse).toSet();
  Set<int> get artifacts =>
      (_prefs.getStringList('artifacts') ?? []).map(int.parse).toSet();

  double get collectionPercent =>
      artifacts.length / Artifacts.all.length.clamp(1, 999);

  // ---------------------------------------------------------------- settings
  bool get musicOn => _prefs.getBool('music') ?? true;
  bool get sfxOn => _prefs.getBool('sfx') ?? true;
  bool get shakeOn => _prefs.getBool('shake') ?? true;
  bool get leftHanded => _prefs.getBool('leftHanded') ?? false;

  void setSetting(String key, bool value) {
    _prefs.setBool(key, value);
    notifyListeners();
  }

  // ---------------------------------------------------------------- quests
  List<Quest> _quests = [];
  List<Quest> get quests => _quests;

  void _rollQuestsIfNewDay() {
    final today = DateTime.now().toUtc();
    final stamp = '${today.year}-${today.month}-${today.day}';
    final saved = _prefs.getString('questDay');
    final raw = _prefs.getString('questData');

    if (saved == stamp && raw != null) {
      _quests = (json.decode(raw) as List)
          .map((e) => Quest.fromJson(e as Map<String, dynamic>))
          .toList();
      return;
    }
    _quests = Quest.rollDaily(stamp.hashCode);
    _prefs.setString('questDay', stamp);
    _persistQuests();
  }

  void _persistQuests() {
    _prefs.setString(
        'questData', json.encode([for (final q in _quests) q.toJson()]));
  }

  /// Applies one run's results to records, wallet and quest progress.
  /// Returns the quests that were completed by this run.
  List<Quest> commitRun(RunResult r) {
    _prefs.setInt('totalRuns', totalRuns + 1);
    _prefs.setInt('totalDistance', totalDistance + r.distance);
    if (r.distance > bestDistance) _prefs.setInt('bestDistance', r.distance);
    if (r.longestChain > bestChain) _prefs.setInt('bestChain', r.longestChain);
    if (r.biomeReached + 1 > biomesSeen) {
      _prefs.setInt('biomesSeen', r.biomeReached + 1);
    }

    r.collected.forEach((kind, amount) {
      if (amount > 0) _prefs.setInt('res_${kind.name}', resource(kind) + amount);
    });

    if (r.magmaUsed.isNotEmpty) {
      _prefs.setStringList('magma',
          {...magmaFound, ...r.magmaUsed.map((m) => m.index)}
              .map((e) => e.toString())
              .toList());
    }
    if (r.artifactsFound.isNotEmpty) {
      _prefs.setStringList('artifacts',
          {...artifacts, ...r.artifactsFound}.map((e) => e.toString()).toList());
    }

    final finished = <Quest>[];
    for (final q in _quests) {
      if (q.done) continue;
      q.progress += q.measure(r);
      if (q.done) {
        finished.add(q);
        _prefs.setInt(
            'res_${ResourceKind.shard.name}', resource(ResourceKind.shard) + q.reward);
      }
    }
    _persistQuests();
    notifyListeners();
    return finished;
  }

  void _spend(ResourceKind kind, int amount) {
    _prefs.setInt('res_${kind.name}', (resource(kind) - amount).clamp(0, 1 << 30));
  }
}

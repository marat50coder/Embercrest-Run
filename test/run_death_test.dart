import 'package:embercrest_run/core/atlas.dart';
import 'package:embercrest_run/game/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A run has to end in a game-over hand-off no matter what kills the player, so
/// these drive whole runs headlessly and check the death path all the way to the
/// result the summary panel is built from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpriteAtlas atlas;

  setUpAll(() async {
    atlas = await SpriteAtlas.load();
  });

  /// Steps a run at 60 Hz until the player dies, or gives up.
  RunState runUntilDeath(Simulation sim, {double limit = 240}) {
    var elapsed = 0.0;
    while (elapsed < limit && sim.state != RunState.dying) {
      sim.update(1 / 60);
      elapsed += 1 / 60;
    }
    return sim.state;
  }

  test('every run ends in death rather than running forever', () {
    for (var seed = 0; seed < 12; seed++) {
      final sim = Simulation(atlas, seed: seed)..start();
      expect(runUntilDeath(sim), RunState.dying,
          reason: 'seed $seed never reached a death');
      expect(sim.deathCause, isNotNull);
    }
  });

  test('death hands over a result and stops taking input', () async {
    var overs = 0;
    final sim = Simulation(atlas, seed: 7)
      ..onGameOver = (() { overs++; })
      ..start();
    runUntilDeath(sim);

    final cause = sim.deathCause;
    // The death beat is timed on a wall clock, so real time has to pass.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    sim.update(1 / 60);

    expect(sim.state, RunState.over);
    expect(overs, 1);
    expect(sim.deathCause, cause, reason: 'the cause shown must not be reset');

    final result = sim.result;
    expect(result.distance, greaterThan(0));
    expect(result.score, greaterThanOrEqualTo(result.distance));

    // Updating past the end must stay harmless and must not fire again.
    for (var i = 0; i < 120; i++) {
      sim.update(1 / 60);
    }
    expect(overs, 1);
  });

  test('steering after death cannot revive the run', () {
    final sim = Simulation(atlas, seed: 3)..start();
    runUntilDeath(sim);
    sim.setSteer(-1);
    sim.sharpTurn(1);
    sim.crystallize();
    sim.update(1 / 60);
    expect(sim.state, isNot(RunState.running));
  });
}

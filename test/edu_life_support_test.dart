import 'package:flutter_test/flutter_test.dart';
import 'package:vivited/src/mission/checkpoints.dart';
import 'package:vivited/src/science/edu_life_support.dart';
import 'package:vivited/src/science/provenance.dart';
import 'package:vivited/src/state/app_state.dart';

void main() {
  group('educational life-support sample scenario', () {
    test('matches the brief: 120 × 0.3 = 36, remaining 64, reserve OK', () {
      const edu = EduLifeSupport.sampleScenario;
      expect(edu.missionMinutes, 120);
      expect(edu.oxygenConsumed, closeTo(36, 1e-9));
      expect(edu.oxygenRemaining, closeTo(64, 1e-9));
      expect(edu.oxygenOk, isTrue);
      expect(edu.safe, isTrue);
    });

    test('warns when consumption plus reserve exceeds starting oxygen', () {
      const edu = EduLifeSupport(
        startingOxygen: 100,
        oxygenRatePerMin: 0.3,
        oxygenReserve: 20,
        travelMinutes: 280,
        scienceMinutes: 40,
      );
      // 320 × 0.3 = 96; 96 + 20 = 116 > 100
      expect(edu.oxygenConsumed, closeTo(96, 1e-9));
      expect(edu.oxygenOk, isFalse);
      expect(edu.safe, isFalse);
      expect(EduLifeSupport.returnWarning, 'Return to Habitat / Reduce Mission Time');
    });

    test('energy safety uses the same transparent logic', () {
      const ok = EduLifeSupport(
        startingBattery: 100,
        energyRatePerMin: 0.25,
        batteryReserve: 15,
        travelMinutes: 90,
        scienceMinutes: 30,
      );
      expect(ok.energyConsumed, closeTo(30, 1e-9));
      expect(ok.energyOk, isTrue);

      const fail = EduLifeSupport(
        startingBattery: 50,
        energyRatePerMin: 0.5,
        batteryReserve: 15,
        travelMinutes: 80,
        scienceMinutes: 20,
      );
      expect(fail.energyConsumed, closeTo(50, 1e-9));
      expect(fail.energyOk, isFalse);
    });

    test('syncing from a plan updates travel and science minutes', () {
      const base = EduLifeSupport.sampleScenario;
      final synced = base.syncedToPlan(walkSeconds: 3600, dwellSeconds: 1200);
      expect(synced.travelMinutes, 60);
      expect(synced.scienceMinutes, 20);
      expect(synced.startingOxygen, 100);
    });
  });

  group('mission checkpoints', () {
    test('five educational marks map to real science targets', () {
      expect(MissionCheckpoint.all.length, 5);
      expect(MissionCheckpoint.byCode('H0')!.targetId, 'threeforks');
      expect(MissionCheckpoint.byCode('CP1')!.targetId, 'amalik');
      expect(MissionCheckpoint.byCode('CP2')!.targetId, 'wildcat');
      expect(MissionCheckpoint.byCode('CP3')!.targetId, 'brightangel');
      expect(MissionCheckpoint.byCode('SH')!.targetId, 'oeb');
      expect(MissionCheckpoint.byCode('H0')!.classification, SourceClass.simulation);
      expect(MissionCheckpoint.byCode('CP2')!.classification, SourceClass.interpretation);
    });
  });

  group('educational routes A–D', () {
    test('four lettered routes plus rim stress case', () {
      final letters = EvaPreset.all
          .where((p) => p.routeLetter != null)
          .map((p) => p.routeLetter)
          .toList();
      expect(letters, ['A', 'B', 'C', 'D']);
      expect(EvaPreset.byId('delta-front')?.id, 'route-a');
      expect(EvaPreset.byId('seitah')?.id, 'route-b');
      expect(EvaPreset.byId('neretva')?.id, 'route-c');
      expect(EvaPreset.byId('route-d')!.returnToBase, isFalse);
      expect(EvaPreset.byId('rim'), isNotNull);
    });
  });
}

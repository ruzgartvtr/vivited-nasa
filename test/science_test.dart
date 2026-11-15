import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vivited/src/science/eva_model.dart';
import 'package:vivited/src/science/geodesy.dart';
import 'package:vivited/src/science/hazard.dart';
import 'package:vivited/src/science/mars_constants.dart';
import 'package:vivited/src/science/mars_time.dart';
import 'package:vivited/src/science/radiation.dart';

void main() {
  group('MarsTime (Allison & McEwen 2000)', () {
    // Worked example published with the Mars24 algorithm:
    // 2000-01-06 00:00:00 UTC.
    final t = DateTime.utc(2000, 1, 6);

    test('intermediate quantities match the published worked example', () {
      final dt = MarsTime.deltaJ2000(t);
      expect(dt, closeTo(4.50074, 1e-5));
      expect(MarsTime.meanAnomaly(dt), closeTo(21.74558, 1e-4));
      expect(MarsTime.fictitiousMeanSun(dt), closeTo(272.74566, 1e-4));
      expect(MarsTime.perturbers(dt), closeTo(0.00142, 1e-5));
      expect(MarsTime.equationOfCenter(dt), closeTo(4.44193, 1e-4));
    });

    test('solar longitude, equation of time and clock times', () {
      expect(MarsTime.solarLongitude(t), closeTo(277.18758, 1e-4));
      expect(MarsTime.equationOfTimeDeg(t), closeTo(-5.18774, 1e-4));
      expect(MarsTime.marsSolDate(t), closeTo(44795.99976, 1e-4));
      expect(MarsTime.coordinatedMarsTime(t), closeTo(23.99425, 1e-4));
      expect(MarsTime.localTrueSolarTime(t, 0), closeTo(23.64840, 1e-4));
    });

    test('Perseverance landed in early northern spring (Ls ≈ 5°)', () {
      final ls = MarsTime.solarLongitude(DateTime.utc(2021, 2, 18, 20, 55));
      expect(ls, closeTo(5.6, 0.5));
    });

    test('Ls-only approximations agree with the full ephemeris', () {
      for (var d = 0; d < 700; d += 23) {
        final when = DateTime.utc(2021, 2, 18).add(Duration(days: d));
        final ls = MarsTime.solarLongitude(when);
        expect(
          MarsTime.equationOfTimeFromLs(ls),
          closeTo(MarsTime.equationOfTimeDeg(when), 0.15),
        );
        expect(
          MarsTime.sunDistanceAuFromLs(ls),
          closeTo(MarsTime.sunDistanceAu(when), 0.004),
        );
      }
    });

    test('solar geometry', () {
      // Declination extremes equal the obliquity (25.19°) within the
      // algorithm's small correction term.
      expect(MarsTime.solarDeclination(90), closeTo(25.44, 0.05));
      expect(MarsTime.solarDeclination(270), closeTo(-25.44, 0.05));
      expect(MarsTime.solarDeclination(0), closeTo(0, 1e-9));
      // Equinox on the equator: sun overhead at noon, 12 h day.
      expect(
        MarsTime.sunElevation(ls: 0, latDeg: 0, ltst: 12),
        closeTo(90, 1e-6),
      );
      expect(MarsTime.halfDayHours(ls: 0, latDeg: 40), closeTo(6, 1e-9));
      // Noon elevation = 90 − |lat − declination|.
      final dec = MarsTime.solarDeclination(90);
      expect(
        MarsTime.sunElevation(ls: 90, latDeg: jezeroLat, ltst: 12),
        closeTo(90 - (jezeroLat - dec).abs(), 1e-6),
      );
      // Sun on the horizon at computed sunrise, due-ish east; south at noon
      // when the site is north of the sub-solar latitude.
      final rise = MarsTime.sunriseLtst(ls: 200, latDeg: jezeroLat);
      expect(
        MarsTime.sunElevation(ls: 200, latDeg: jezeroLat, ltst: rise),
        closeTo(0, 1e-6),
      );
      expect(
        MarsTime.sunAzimuth(ls: 200, latDeg: jezeroLat, ltst: rise),
        inInclusiveRange(60, 120),
      );
      expect(
        MarsTime.sunAzimuth(ls: 200, latDeg: jezeroLat, ltst: 12),
        closeTo(180, 1e-6),
      );
      // Summer days are longer than winter days in the north.
      expect(
        MarsTime.halfDayHours(ls: 90, latDeg: jezeroLat),
        greaterThan(MarsTime.halfDayHours(ls: 270, latDeg: jezeroLat)),
      );
    });

    test('solar flux spans perihelion to aphelion', () {
      // 1361 W/m² / r²: ≈ 717 at perihelion (1.381 AU), ≈ 493 at aphelion.
      expect(MarsTime.solarFluxToa(251), closeTo(717, 6));
      expect(MarsTime.solarFluxToa(71), closeTo(493, 6));
    });

    test('clock formatting', () {
      expect(MarsTime.formatClock(9.5), '09:30');
      expect(MarsTime.formatClock(23.9999), '00:00');
      expect(MarsTime.formatClock(-1), '23:00');
    });
  });

  group('Geodesy', () {
    test('one degree of latitude on Mars is 59.27 km', () {
      expect(Geodesy.distanceM(0, 0, 1, 0), closeTo(59274.7, 1));
      expect(Geodesy.metersPerDegLat, closeTo(59274.7, 1));
    });
    test('longitude shrinks with cos(latitude)', () {
      expect(
        Geodesy.distanceM(60, 0, 60, 1),
        closeTo(Geodesy.metersPerDegLon(60), 5),
      );
    });
    test('quarter circumference pole to equator', () {
      expect(
        Geodesy.distanceM(90, 0, 0, 0),
        closeTo(math.pi / 2 * marsRadiusM, 1e-3),
      );
    });
    test('bearings', () {
      expect(Geodesy.bearingDeg(0, 0, 1, 0), closeTo(0, 1e-9));
      expect(Geodesy.bearingDeg(0, 0, 0, 1), closeTo(90, 1e-9));
      expect(Geodesy.bearingDeg(0, 0, -1, 0), closeTo(180, 1e-9));
      expect(Geodesy.bearingDeg(0, 0, 0, -1), closeTo(270, 1e-9));
      expect(Geodesy.compass(44), 'NE');
    });
  });

  group('EvaModel', () {
    test('Marquez speed curve break-points', () {
      expect(EvaModel.marquezSpeed(0), closeTo(1.6, 1e-9));
      expect(EvaModel.marquezSpeed(6), closeTo(0.4, 1e-9));
      expect(EvaModel.marquezSpeed(15), closeTo(0.049, 1e-9));
      expect(EvaModel.marquezSpeed(16), 0.05);
      expect(EvaModel.marquezSpeed(-10), closeTo(1.0, 1e-9));
      expect(EvaModel.marquezSpeed(-25), 0.05);
    });

    test('speed curve is continuous and never exceeds its stated maximum', () {
      for (var s = -19.9; s <= 14.9; s += 0.1) {
        final a = EvaModel.marquezSpeed(s), b = EvaModel.marquezSpeed(s + 0.01);
        expect((a - b).abs(), lessThan(0.01), reason: 'jump near $s°');
        expect(a, lessThanOrEqualTo(EvaModel.marquezMaxSpeed + 1e-12));
        expect(a, greaterThan(0));
      }
    });

    test('Santee metabolic rate: level value and slope ordering', () {
      const m = EvaModel(crewMassKg: 80, suitMassKg: 100, paceFactor: 1);
      // (3.28·180 + 71.1)(0.661·1.6 + 0.115) W
      expect(m.metabolicRateW(0), closeTo(661.5 * (0.661 * 1.6 + 0.115), 1e-6));
      // Per metre, climbing costs more than level, level more than a gentle
      // descent.
      expect(m.energyPerMeter(5), greaterThan(m.energyPerMeter(0)));
      expect(m.energyPerMeter(0), greaterThan(m.energyPerMeter(-3)));
      // Metabolic rate stays positive across the walkable range.
      for (var s = -20.0; s <= 20; s += 0.5) {
        expect(m.metabolicRateW(s), greaterThan(0), reason: 'slope $s');
      }
      expect(m.minEnergyPerMeter, lessThanOrEqualTo(m.energyPerMeter(0)));
    });

    test('lower gravity lowers the cost of climbing', () {
      const mars = EvaModel(paceFactor: 1);
      const earth = EvaModel(paceFactor: 1, gravity: 9.81);
      expect(mars.metabolicRateW(10), lessThan(earth.metabolicRateW(10)));
      expect(mars.metabolicRateW(0), closeTo(earth.metabolicRateW(0), 1e-9));
    });

    test('pace factor scales speed', () {
      const m = EvaModel(paceFactor: 0.5);
      expect(m.speed(0), closeTo(0.8, 1e-12));
      expect(m.maxSpeed, closeTo(0.8, 1e-12));
    });

    test('oxygen consumption', () {
      // 300 W for one hour ≈ 77 g O₂.
      expect(EvaModel.oxygenRateKgPerHour(300), closeTo(0.0768, 0.0005));
      expect(EvaModel.kcal(4184), 1);
      const lss = LifeSupport(primaryO2Kg: 0.55, reserveFraction: 0.2);
      expect(lss.usableO2Kg, closeTo(0.44, 1e-12));
    });
  });

  group('Radiation (MSL RAD)', () {
    test('dose scales linearly with exposure time', () {
      expect(Radiation.doseEquivalentUsv(86400), closeTo(640, 1e-9));
      expect(Radiation.doseEquivalentUsv(3600), closeTo(640 / 24, 1e-9));
      expect(Radiation.doseEquivalentSigmaUsv(86400), closeTo(120, 1e-9));
      expect(Radiation.perSolUsv, closeTo(640 * solSeconds / 86400, 1e-9));
    });
  });

  group('HazardClass', () {
    test('class boundaries', () {
      expect(HazardClass.fromSlope(0), HazardClass.nominal);
      expect(HazardClass.fromSlope(5.99), HazardClass.nominal);
      expect(HazardClass.fromSlope(6), HazardClass.caution);
      expect(HazardClass.fromSlope(-12), HazardClass.difficult);
      expect(HazardClass.fromSlope(19.9), HazardClass.severe);
      expect(HazardClass.fromSlope(20), HazardClass.noGo);
    });
  });
}

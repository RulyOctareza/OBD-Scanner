import 'package:autocare/core/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nb = Fmt.nbsp;

  group('number', () {
    test('groups thousands with a dot', () {
      expect(Fmt.number(161420), '161.420');
      expect(Fmt.number(1000000), '1.000.000');
      expect(Fmt.number(999), '999');
      expect(Fmt.number(0), '0');
    });

    test('uses a decimal comma and rounds', () {
      expect(Fmt.number(14.24, decimals: 1), '14,2');
      expect(Fmt.number(14.25, decimals: 1), '14,3');
      expect(Fmt.number(1234.5, decimals: 1), '1.234,5');
    });

    test('drops the minus sign when the value rounds to zero', () {
      expect(Fmt.number(-0.04, decimals: 1), '0,0');
      expect(Fmt.number(-2.5, decimals: 1), '-2,5');
      expect(Fmt.number(-1500), '-1.500');
    });
  });

  group('units', () {
    test('join value and unit with a non-breaking space', () {
      expect(Fmt.km(161420), '161.420${nb}km');
      expect(Fmt.kmPerLiter(14.2), '14,2${nb}km/\u2060L');
      expect(Fmt.speed(52), '52${nb}km/\u2060jam');
      expect(Fmt.celsius(86), '86$nb°C');
      expect(Fmt.volts(13.9), '13,9${nb}V');
      expect(Fmt.liters(25.3), '25,3${nb}L');
      expect(Fmt.rpm(2063), '2.063${nb}rpm');
    });

    test('a unit with a slash never wraps at it', () {
      expect(Fmt.speed(52).contains('/\u2060'), isTrue);
    });

    test('percent attaches directly', () {
      expect(Fmt.percent(72), '72%');
    });

    test('rupiah has no space and no decimals', () {
      expect(Fmt.rupiah(637000), 'Rp637.000');
      expect(Fmt.rupiah(252000.4), 'Rp252.000');
    });
  });

  group('duration', () {
    test('reads in minutes and hours', () {
      expect(Fmt.minutes(12), '12${nb}menit');
      expect(Fmt.minutes(65), '1${nb}jam 5${nb}menit');
      expect(Fmt.minutes(120), '2${nb}jam');
      expect(Fmt.duration(const Duration(seconds: 30)), '<${nb}1${nb}menit');
    });
  });

  group('dates', () {
    final time = DateTime(2026, 11, 23, 14, 5, 9);

    test('use Indonesian month names and a dot in times', () {
      expect(Fmt.date(time), '23 Nov 2026');
      expect(Fmt.date(DateTime(2026, 5, 1)), '1 Mei 2026');
      expect(Fmt.date(DateTime(2026, 8, 17)), '17 Agu 2026');
      expect(Fmt.time(time), '14.05');
      expect(Fmt.timeWithSeconds(time), '14.05.09');
      expect(Fmt.dateTime(time), '23 Nov 2026, 14.05');
    });

    test('relative day names', () {
      final now = DateTime(2026, 11, 23, 20);
      expect(Fmt.relative(time, now: now), 'Hari ini, 14.05');
      expect(Fmt.relative(DateTime(2026, 11, 22, 9, 30), now: now),
          'Kemarin, 09.30');
      // 2026-11-20 is a Friday.
      expect(Fmt.relative(DateTime(2026, 11, 20, 8, 15), now: now),
          'Jumat, 08.15');
      expect(Fmt.relative(DateTime(2026, 11, 10, 8, 15), now: now),
          '10 Nov 2026, 08.15');
    });
  });
}

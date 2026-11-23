/// Indonesian number, unit, duration and date formatting.
///
/// Written by hand instead of through intl's `id_ID` locale data, so no
/// locale initialisation is needed at startup or in tests. Decimal comma,
/// thousands dot: 14,2 km/L · 161.420 km · Rp637.000.
abstract final class Fmt {
  /// Non-breaking space between a value and its unit, so they never wrap apart.
  static const String nbsp = ' ';

  /// Placeholder for a value that has not arrived yet.
  static const String pending = '—';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const List<String> _weekdays = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  /// `161420` → `161.420`; `14.25` with 1 decimal → `14,3`.
  static String number(num value, {int decimals = 0}) {
    final fixed = value.abs().toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    final whole = dot < 0 ? fixed : fixed.substring(0, dot);
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('.');
      buffer.write(whole[i]);
    }
    if (dot >= 0) buffer.write(',${fixed.substring(dot + 1)}');
    final text = buffer.toString();
    // A value that rounds to zero is shown without a minus sign.
    final isZero = double.parse(fixed) == 0;
    return value < 0 && !isZero ? '-$text' : text;
  }

  /// Word joiner: keeps "km/jam" from breaking after its slash.
  static const String _joiner = '\u2060';

  /// Value and unit with a non-breaking space; `%` attaches directly. A unit
  /// with a slash never wraps at it.
  static String unit(String value, String unit) => unit == '%'
      ? '$value%'
      : '$value$nbsp${unit.replaceAll('/', '/$_joiner')}';

  static String km(num value, {int decimals = 0}) =>
      unit(number(value, decimals: decimals), 'km');

  static String kmPerLiter(num value) => unit(number(value, decimals: 1), 'km/L');

  static String liters(num value) => unit(number(value, decimals: 1), 'L');

  static String speed(num value) => unit(number(value), 'km/jam');

  static String celsius(num value) => unit(number(value), '°C');

  static String volts(num value) => unit(number(value, decimals: 1), 'V');

  static String percent(num value) => unit(number(value), '%');

  static String rpm(num value) => unit(number(value), 'rpm');

  /// `Rp637.000`: no space after Rp, no decimals.
  static String rupiah(num value) => 'Rp${number(value.round())}';

  /// `12 menit`, `1 jam 5 menit`, `2 jam`; under a minute is `< 1 menit`.
  static String duration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '<${nbsp}1${nbsp}menit';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$minutes${nbsp}menit';
    if (rest == 0) return '$hours${nbsp}jam';
    return '$hours${nbsp}jam $rest${nbsp}menit';
  }

  static String minutes(int minutes) => duration(Duration(minutes: minutes));

  /// `23 Nov 2026`.
  static String date(DateTime time) =>
      '${time.day} ${_months[time.month - 1]} ${time.year}';

  /// `14.05` (Indonesian time separator is a dot).
  static String time(DateTime time) =>
      '${_two(time.hour)}.${_two(time.minute)}';

  /// `14.05.09`, for chart axes.
  static String timeWithSeconds(DateTime time) =>
      '${Fmt.time(time)}.${_two(time.second)}';

  /// `23 Nov 2026, 14.05`.
  static String dateTime(DateTime time) => '${date(time)}, ${Fmt.time(time)}';

  /// `Hari ini, 14.05`, `Kemarin, 09.30`, `Senin, 08.15` within a week,
  /// otherwise the full date.
  static String relative(DateTime time, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final day = _day(time);
    final days = today.difference(day).inDays;
    final clock = Fmt.time(time);
    if (days == 0) return 'Hari ini, $clock';
    if (days == 1) return 'Kemarin, $clock';
    if (days > 1 && days < 7) return '${_weekdays[time.weekday - 1]}, $clock';
    return dateTime(time);
  }

  static DateTime _day(DateTime time) => DateTime(time.year, time.month, time.day);

  static String _two(int value) => value.toString().padLeft(2, '0');
}

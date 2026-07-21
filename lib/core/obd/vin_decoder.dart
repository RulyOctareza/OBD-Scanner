/// Decodes a Vehicle Identification Number into a friendly display name.
///
/// Standard OBD-II does not expose "car model name" as a PID. Mode 09 PID 02
/// returns the VIN; we derive manufacturer + model year (and a few local
/// model hints) for the Settings "Nama Mobil" field.
class VinDecoder {
  VinDecoder._();

  static final RegExp _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  /// Returns true when [vin] looks like a valid 17-char VIN.
  static bool isValidVin(String? vin) {
    if (vin == null) return false;
    final cleaned = vin.trim().toUpperCase();
    return _vinPattern.hasMatch(cleaned);
  }

  /// Builds a short vehicle label from [vin], e.g. `Toyota Agya (2019)`.
  static String? displayNameFromVin(String? vin) {
    final cleaned = vin?.trim().toUpperCase();
    if (cleaned == null || !isValidVin(cleaned)) return null;

    final make = _makeFromWmi(cleaned.substring(0, 3));
    final model = _modelHint(cleaned);
    final year = _modelYear(cleaned[9]);

    final buffer = StringBuffer(make);
    if (model != null) buffer.write(' $model');
    if (year != null) buffer.write(' ($year)');
    return buffer.toString();
  }

  static String _makeFromWmi(String wmi) {
    const map = <String, String>{
      // Indonesia / ASEAN
      'MHK': 'Toyota',
      'MHF': 'Toyota',
      'MHR': 'Honda',
      'MH1': 'Honda',
      'MH8': 'Suzuki',
      'MHY': 'Suzuki',
      'MK2': 'Daihatsu',
      'MMB': 'Mitsubishi',
      'MMC': 'Mitsubishi',
      'MPA': 'Isuzu',
      'ML3': 'Mitsubishi',
      // Japan
      'JTD': 'Toyota',
      'JT2': 'Toyota',
      'JT3': 'Toyota',
      'JT4': 'Toyota',
      'JT6': 'Toyota',
      'JT8': 'Toyota',
      'JTE': 'Toyota',
      'JTH': 'Lexus',
      'JHM': 'Honda',
      'JH4': 'Acura',
      'JF1': 'Subaru',
      'JF2': 'Subaru',
      'JM1': 'Mazda',
      'JM3': 'Mazda',
      'JN1': 'Nissan',
      'JN8': 'Nissan',
      'JS2': 'Suzuki',
      'JS3': 'Suzuki',
      'JA3': 'Mitsubishi',
      'JA4': 'Mitsubishi',
      // Korea
      'KMH': 'Hyundai',
      'KNA': 'Kia',
      'KND': 'Kia',
      // Europe
      'WBA': 'BMW',
      'WBS': 'BMW',
      'WDB': 'Mercedes-Benz',
      'WDD': 'Mercedes-Benz',
      'WAU': 'Audi',
      'WVW': 'Volkswagen',
      'WF0': 'Ford',
      'VF1': 'Renault',
      'VF3': 'Peugeot',
      'VF7': 'Citroën',
      'ZFA': 'Fiat',
      'ZFF': 'Ferrari',
      'SAL': 'Land Rover',
      'SAJ': 'Jaguar',
      // US
      '1G1': 'Chevrolet',
      '1FA': 'Ford',
      '1FT': 'Ford',
      '1HG': 'Honda',
      '1N4': 'Nissan',
      '2T1': 'Toyota',
      '3VW': 'Volkswagen',
      '5YJ': 'Tesla',
      // China common export WMIs
      'LGB': 'Dongfeng',
      'LSV': 'Volkswagen',
      'LVS': 'Ford',
    };

    if (map.containsKey(wmi)) return map[wmi]!;
    // Broader first-letter region fallbacks when WMI unknown.
    switch (wmi[0]) {
      case 'J':
        return 'Jepang';
      case 'K':
        return 'Korea';
      case 'W':
        return 'Jerman';
      case 'L':
        return 'China';
      case 'M':
        return 'Asia Tenggara';
      case '1':
      case '4':
      case '5':
        return 'Amerika';
      default:
        return 'Kendaraan';
    }
  }

  /// Best-effort model hints for common Indonesian market VDS patterns.
  static String? _modelHint(String vin) {
    final vds = vin.substring(3, 8);
    const hints = <String, String>{
      'M1502': 'Agya',
      'M1501': 'Agya',
      'B150A': 'Calya',
      'B150B': 'Calya',
      'F650E': 'Innova',
      'F650F': 'Innova',
      'GUN15': 'Fortuner',
      'GUN16': 'Fortuner',
      'NCP15': 'Vios',
      'NSP15': 'Vios',
      'NGC10': 'Raize',
      'A350A': 'Brio',
      'A350B': 'Brio',
      'RU1': 'HR-V',
      'RU2': 'HR-V',
      'GK5': 'Jazz',
      'GE8': 'Jazz',
    };
    for (final entry in hints.entries) {
      if (vds.startsWith(entry.key) || vin.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _modelYear(String code) {
    const years = <String, int>{
      'A': 2010,
      'B': 2011,
      'C': 2012,
      'D': 2013,
      'E': 2014,
      'F': 2015,
      'G': 2016,
      'H': 2017,
      'J': 2018,
      'K': 2019,
      'L': 2020,
      'M': 2021,
      'N': 2022,
      'P': 2023,
      'R': 2024,
      'S': 2025,
      'T': 2026,
      'V': 2027,
      'W': 2028,
      'X': 2029,
      'Y': 2030,
      '1': 2001,
      '2': 2002,
      '3': 2003,
      '4': 2004,
      '5': 2005,
      '6': 2006,
      '7': 2007,
      '8': 2008,
      '9': 2009,
    };
    return years[code.toUpperCase()];
  }
}

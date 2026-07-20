class ObdParser {
  /// Parses ELM327 battery voltage from "AT RV" response (e.g. "12.8V" or "13.4V\r\r>")
  static double? parseVoltage(String response) {
    try {
      final cleaned = response.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleaned.isNotEmpty) {
        return double.parse(cleaned);
      }
    } catch (_) {}
    return null;
  }

  /// Parses PID 010C (RPM) response: usually "41 0C XX YY"
  /// Formula: ((XX * 256) + YY) / 4
  static double? parseRpm(String response) {
    final bytes = _extractPayloadBytes(response, '0C');
    if (bytes != null && bytes.length >= 2) {
      return ((bytes[0] * 256) + bytes[1]) / 4.0;
    }
    return null;
  }

  /// Parses PID 010D (Speed) response: usually "41 0D XX"
  /// Formula: XX
  static double? parseSpeed(String response) {
    final bytes = _extractPayloadBytes(response, '0D');
    if (bytes != null && bytes.isNotEmpty) {
      return bytes[0].toDouble();
    }
    return null;
  }

  /// Parses PID 0105 (Coolant Temp) response: "41 05 XX"
  /// Formula: XX - 40
  static double? parseCoolant(String response) {
    final bytes = _extractPayloadBytes(response, '05');
    if (bytes != null && bytes.isNotEmpty) {
      return (bytes[0] - 40).toDouble();
    }
    return null;
  }

  /// Parses PID 010B (MAP) response: "41 0B XX"
  /// Formula: XX
  static double? parseMap(String response) {
    final bytes = _extractPayloadBytes(response, '0B');
    if (bytes != null && bytes.isNotEmpty) {
      return bytes[0].toDouble();
    }
    return null;
  }

  /// Parses PID 0111 (Throttle Position) response: "41 11 XX"
  /// Formula: XX * 100 / 255
  static double? parseThrottle(String response) {
    final bytes = _extractPayloadBytes(response, '11');
    if (bytes != null && bytes.isNotEmpty) {
      return bytes[0] * 100.0 / 255.0;
    }
    return null;
  }

  /// Parses PID 0104 (Calculated Engine Load) response: "41 04 XX"
  /// Formula: XX * 100 / 255
  static double? parseEngineLoad(String response) {
    final bytes = _extractPayloadBytes(response, '04');
    if (bytes != null && bytes.isNotEmpty) {
      if (bytes[0] == 0xFF) return null; // 0xFF = unsupported/error by ELM327 clone
      return bytes[0] * 100.0 / 255.0;
    }
    return null;
  }

  /// Parses PID 012F (Fuel Level) response: "41 2F XX"
  /// Formula: XX * 100 / 255
  static double? parseFuelLevel(String response) {
    final bytes = _extractPayloadBytes(response, '2F');
    if (bytes != null && bytes.isNotEmpty) {
      return bytes[0] * 100.0 / 255.0;
    }
    return null;
  }

  /// Parses PID 01A6 (Odometer / Distance accumulation) response: "41 A6 AA BB CC DD"
  /// Formula: ((A * 16777216) + (B * 65536) + (C * 256) + D) / 10.0
  static double? parseOdometer(String response) {
    final bytes = _extractPayloadBytes(response, 'A6');
    if (bytes != null && bytes.length >= 4) {
      final value = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      return value / 10.0;
    }
    return null;
  }

  /// Parses PID 010F (Intake Air Temp) response: "41 0F XX"
  /// Formula: A - 40
  static double? parseIntakeAirTemp(String response) {
    final bytes = _extractPayloadBytes(response, '0F');
    if (bytes != null && bytes.isNotEmpty) {
      return (bytes[0] - 40).toDouble();
    }
    return null;
  }

  /// Parses PID 0110 (MAF) response: "41 10 AA BB"
  /// Formula: ((A * 256) + B) / 100
  static double? parseMaf(String response) {
    final bytes = _extractPayloadBytes(response, '10');
    if (bytes != null && bytes.length >= 2) {
      return ((bytes[0] * 256) + bytes[1]) / 100.0;
    }
    return null;
  }

  /// Parses PID 010E (Timing Advance) response: "41 0E XX"
  /// Formula: (A / 2) - 64
  static double? parseTimingAdvance(String response) {
    final bytes = _extractPayloadBytes(response, '0E');
    if (bytes != null && bytes.isNotEmpty) {
      return (bytes[0] / 2.0) - 64;
    }
    return null;
  }

  /// Parses OBD DTC response from Mode 03 (Active DTCs)
  /// Returns a list of DTC codes like ["P0138", "P0115"]
  static List<String> parseDtc(String response) {
    return parseDtcFromMode(response, '43');
  }

  /// Parses OBD Pending DTC response from Mode 07
  static List<String> parsePendingDtc(String response) {
    return parseDtcFromMode(response, '47');
  }

  /// Parses OBD Permanent DTC response from Mode 0A
  static List<String> parsePermanentDtc(String response) {
    return parseDtcFromMode(response, '4A');
  }

  /// Generic DTC parser given expected mode header ('43', '47', '4A')
  static List<String> parseDtcFromMode(String response, String modeHeader) {
    final codes = <String>[];
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').replaceAll('>', '').toUpperCase();
    
    final index = cleaned.lastIndexOf(modeHeader);
    if (index == -1 || cleaned.length < index + 6) return codes;
    
    final payload = cleaned.substring(index + 4); // Skip header (2 chars) and count byte (2 chars)
    for (int i = 0; i < payload.length - 3; i += 4) {
      if (i + 4 > payload.length) break;
      final codeHex = payload.substring(i, i + 4);
      if (codeHex == '0000') continue; // padding
      
      final dtc = _hexToDtc(codeHex);
      if (dtc != null && !codes.contains(dtc)) {
        codes.add(dtc);
      }
    }
    return codes;
  }

  /// Parses PID 0101 (I/M Readiness) response: "41 01 AA BB CC DD"
  /// Returns map of monitor statuses and MIL indicator
  static Map<String, bool>? parseImReadiness(String response) {
    final bytes = _extractPayloadBytes(response, '01');
    if (bytes == null || bytes.length < 4) return null;

    final byteA = bytes[0]; // Bit 7 = MIL state, Bit 0-6 = DTC Count
    final byteB = bytes[1]; // Continuous tests (Misfire, Fuel, Components)
    final byteC = bytes[2]; // Non-continuous tests ready status
    final byteD = bytes[3]; // Non-continuous tests enabled status

    final isMilOn = (byteA & 0x80) != 0;
    final dtcCount = byteA & 0x7F;

    // Bit tests for continuous readiness (0 = Complete/Passed)
    final misfireReady = (byteB & 0x11) == 0;
    final fuelSystemReady = (byteB & 0x22) == 0;
    final componentsReady = (byteB & 0x44) == 0;

    // Non-continuous readiness
    final catalystReady = (byteC & 0x01) == 0;
    final evapReady = (byteC & 0x04) == 0;
    final o2SensorReady = (byteC & 0x20) == 0;
    final o2HeaterReady = (byteC & 0x40) == 0;
    final egrReady = (byteC & 0x80) == 0;

    return {
      'mil': isMilOn,
      'misfire': misfireReady,
      'fuelSystem': fuelSystemReady,
      'components': componentsReady,
      'catalyst': catalystReady,
      'evap': evapReady,
      'o2Sensor': o2SensorReady,
      'o2Heater': o2HeaterReady,
      'egr': egrReady,
    };
  }

  static String? _hexToDtc(String hex) {
    if (hex.length != 4) return null;
    final firstChar = hex[0];
    String category = '';
    switch (firstChar) {
      case '0': case '1': case '2': case '3':
        category = 'P'; // Powertrain
        break;
      case '4': case '5': case '6': case '7':
        category = 'C'; // Chassis
        break;
      case '8': case '9': case 'A': case 'B':
        category = 'B'; // Body
        break;
      case 'C': case 'D': case 'E': case 'F':
        category = 'U'; // Network
        break;
      default:
        return null;
    }
    
    final secondDigit = int.tryParse(firstChar, radix: 16);
    if (secondDigit == null) return null;
    final displayFirstDigit = secondDigit & 3;
    
    return '$category$displayFirstDigit${hex.substring(1)}';
  }

  static List<int>? _extractPayloadBytes(String response, String pidHex) {
    try {
      final cleaned = response.replaceAll(RegExp(r'\s+'), '').replaceAll('>', '').toUpperCase();
      // Look for standard response header "41" + PID
      final header = '41$pidHex';
      final index = cleaned.lastIndexOf(header);
      if (index == -1) return null;
      
      final payloadHex = cleaned.substring(index + header.length);
      final bytes = <int>[];
      for (int i = 0; i < payloadHex.length - 1; i += 2) {
        final byteStr = payloadHex.substring(i, i + 2);
        final byteVal = int.tryParse(byteStr, radix: 16);
        if (byteVal != null) {
          bytes.add(byteVal);
        } else {
          break;
        }
      }
      return bytes;
    } catch (_) {}
    return null;
  }
}

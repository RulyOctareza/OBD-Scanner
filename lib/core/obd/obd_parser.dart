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

  /// Parses OBD DTC response from Mode 03
  /// Returns a list of DTC codes like ["P0138", "P0115"]
  static List<String> parseDtc(String response) {
    final codes = <String>[];
    // Clean response (remove spaces, prompt characters, echo)
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').replaceAll('>', '');
    
    // Typically Mode 03 response starts with 43
    // E.g., 43 02 01 38 01 15 -> 430201380115
    // Here: 43 is mode, 02 is count of codes. Then 01 38 -> P0138, 01 15 -> P0115
    if (!cleaned.startsWith('43') || cleaned.length < 6) return codes;
    
    // Each code is 4 hex digits (2 bytes). Let's extract them starting at index 4 (skip 43 and the count byte)
    // Actually, sometimes ELM327 returns multiple lines or raw hex
    final payload = cleaned.substring(4); // Skip '43' and the count byte
    for (int i = 0; i < payload.length - 3; i += 4) {
      if (i + 4 > payload.length) break;
      final codeHex = payload.substring(i, i + 4);
      if (codeHex == '0000') continue; // padding
      
      final dtc = _hexToDtc(codeHex);
      if (dtc != null) {
        codes.add(dtc);
      }
    }
    return codes;
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
    
    // Convert first hex digit to its DTC numeric equivalent
    // The first digit of the DTC represents:
    // P0xxx, P1xxx, P2xxx, P3xxx etc.
    // In OBD-II standard, the first two bits represent category, next two represent first digit.
    // Let's simplify: hex 0138 -> P0138
    final secondDigit = int.tryParse(firstChar, radix: 16);
    if (secondDigit == null) return null;
    final displayFirstDigit = secondDigit & 3; // Bitmask to get first digit (0, 1, 2, 3)
    
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

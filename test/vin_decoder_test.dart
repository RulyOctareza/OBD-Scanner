import 'package:flutter_test/flutter_test.dart';
import 'package:autocare/core/obd/vin_decoder.dart';

void main() {
  group('VinDecoder', () {
    test('decodes Indonesian Toyota Agya VIN', () {
      // 17-char VIN: WMI MHK, VDS M1502X, year K (2019)
      const vin = 'MHKM1502XK0198421';
      expect(VinDecoder.isValidVin(vin), isTrue);
      expect(
        VinDecoder.displayNameFromVin(vin),
        'Toyota Agya (2019)',
      );
    });

    test('rejects short or invalid VIN', () {
      expect(VinDecoder.isValidVin('ABC'), isFalse);
      expect(VinDecoder.isValidVin(null), isFalse);
      expect(VinDecoder.displayNameFromVin('ABC'), isNull);
    });

    test('decodes known WMI Honda', () {
      // WMI MHR, VDS 123456, year K (2019)
      const vin = 'MHR123456K0123456';
      expect(VinDecoder.displayNameFromVin(vin), 'Honda (2019)');
    });
  });
}

import '../domain/dtc_model.dart';

class DtcRepository {
  static const Map<String, DtcCode> _dtcDatabase = {
    // POWERTRAIN (P0xxx - Generic Engine & Transmission)
    'P0100': DtcCode(
      code: 'P0100',
      title: 'Mass or Volume Air Flow Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Sirkuit sensor aliran udara (MAF) mengalami gangguan sinyal.',
      symptoms: ['Mesin sulit dihidupkan', 'Stasioner/idle tidak stabil', 'Asap knalpot hitam'],
      possibleCauses: ['Sensor MAF kotor atau rusak', 'Kabel/konektor MAF kendur/putus', 'Kebocoran udara setelah sensor'],
      recommendations: ['Bersihkan sensor MAF menggunakan MAF cleaner khusus', 'Periksa soket kabel sensor MAF', 'Ganti sensor MAF jika pembersihan gagal'],
    ),
    'P0101': DtcCode(
      code: 'P0101',
      title: 'Mass Air Flow Circuit Range/Performance Problem',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Kinerja sensor MAF di luar rentang parameter normal.',
      symptoms: ['Tarikan mesin lemot', 'Konsumsi BBM boros', 'Check Engine menyala'],
      possibleCauses: ['Filter udara sangat kotor', 'Sensor MAF tersumbat debu', 'Selang vakum retak'],
      recommendations: ['Ganti filter udara', 'Bersihkan elemen sensor MAF', 'Cek kebocoran vakum di intake'],
    ),
    'P0110': DtcCode(
      code: 'P0110',
      title: 'Intake Air Temperature Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sensor suhu udara masuk (IAT) membaca sinyal tidak wajar.',
      symptoms: ['Konsumsi BBM meningkat', 'Mesin susah di-start saat dingin'],
      possibleCauses: ['Sensor IAT rusak', 'Kabel IAT terputus atau korslet', 'Soket kendor'],
      recommendations: ['Periksa hambatan sensor IAT dengan multimeter', 'Perbaiki pengkabelan IAT', 'Ganti sensor IAT/MAF assembly'],
    ),
    'P0115': DtcCode(
      code: 'P0115',
      title: 'Engine Coolant Temperature Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Gangguan pada sirkuit sensor suhu cairan pendingin mesin (ECT).',
      symptoms: ['Kipas radiator berputar terus atau tidak berputar', 'Indikator suhu ngaco', 'Mesin susah hidup saat panas'],
      possibleCauses: ['Sensor ECT rusak', 'Termostat macet', 'Kabel sensor ECT korosi atau putus'],
      recommendations: ['Periksa kelistrikan sensor ECT', 'Periksa kondisi air radiator', 'Ganti sensor ECT'],
    ),
    'P0117': DtcCode(
      code: 'P0117',
      title: 'Engine Coolant Temperature Sensor Circuit Low',
      category: 'Powertrain',
      severity: DtcSeverity.critical,
      descriptionIndo: 'Sinyal sensor ECT terlalu rendah (membaca suhu sangat panas).',
      symptoms: ['Warning overheat menyala', 'Mesin pincang', 'Kipas berputar maksimal'],
      possibleCauses: ['Mesin benar-benar overheat', 'Kabel sensor ECT korslet ke ground', 'Sensor ECT rusak'],
      recommendations: ['Stop mobil segera dan dinginkan mesin', 'Periksa level air radiator', 'Cek kelistrikan sensor ECT'],
    ),
    'P0120': DtcCode(
      code: 'P0120',
      title: 'Throttle Position Sensor (TPS) Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Sirkuit sensor posisi bukaan gas (TPS) bermasalah.',
      symptoms: ['Gas tersendat-sendat', 'Mesin meraung sendiri saat idle', 'Respons pedal gas terlambat'],
      possibleCauses: ['Sensor TPS aus/rusak', 'Throttle body kotor parah', 'Kabel TPS bermasalah'],
      recommendations: ['Bersihkan throttle body', 'Cek nilai tegangan TPS', 'Ganti sensor TPS'],
    ),
    'P0130': DtcCode(
      code: 'P0130',
      title: 'O2 Sensor Circuit Malfunction (Bank 1 Sensor 1)',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sirkuit Sensor Oksigen depan (sebelum katalis) bermasalah.',
      symptoms: ['BBM boros', 'Emisi gas buang tinggi', 'Bau bensin menyengat dari knalpot'],
      possibleCauses: ['Sensor O2 tercemar oli/bensin', 'Kabel pemanas O2 putus', 'Kebocoran manifold knalpot'],
      recommendations: ['Periksa fisik sensor O2', 'Cek kebocoran manifold knalpot', 'Ganti sensor O2 Bank 1 Sensor 1'],
    ),
    'P0138': DtcCode(
      code: 'P0138',
      title: 'O2 Sensor Circuit High Voltage (Bank 1 Sensor 2)',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Tegangan tinggi terdeteksi pada sensor Oksigen belakang (setelah katalis).',
      symptoms: ['Check Engine menyala', 'Campuran bahan bakar terlalu kaya'],
      possibleCauses: ['Kabel sensor O2 korslet ke positif', 'Sensor O2 rusak', 'Injektor bocor'],
      recommendations: ['Cek pengkabelan sensor O2 belakang', 'Uji resistansi pemanas O2', 'Ganti sensor O2 belakang'],
    ),
    'P0171': DtcCode(
      code: 'P0171',
      title: 'System Too Lean (Bank 1)',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Campuran bahan bakar dan udara terlalu irit / terlalu banyak udara.',
      symptoms: ['Mesin bergetar saat idle', 'Tenaga ngedrop di tanjakan', 'Suara meletup dari intake'],
      possibleCauses: ['Kebocoran vakum intake', 'Tekanan pompa bensin lemah', 'Injektor tersumbat', 'MAF kotor'],
      recommendations: ['Cek selang vakum dari kebocoran', 'Uji tekanan fuel pump', 'Bersihkan injektor dan MAF'],
    ),
    'P0172': DtcCode(
      code: 'P0172',
      title: 'System Too Rich (Bank 1)',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Campuran bahan bakar dan udara terlalu kaya / terlalu banyak bensin.',
      symptoms: ['Knalpot ngebul hitam', 'Bau bensin menyengat', 'BBM sangat boros'],
      possibleCauses: ['Injektor menetes/bocor', 'Tekanan bensin terlalu tinggi', 'Sensor MAF/O2 rusak'],
      recommendations: ['Cek regulasi tekanan bensin', 'Uji kebersihan injektor', 'Cek sensor MAF & O2'],
    ),

    // MISFIRE CODES (P0300 - P0304)
    'P0300': DtcCode(
      code: 'P0300',
      title: 'Random/Multiple Cylinder Misfire Detected',
      category: 'Powertrain',
      severity: DtcSeverity.critical,
      descriptionIndo: 'Pengapian hilang (misfire) secara acak pada beberapa silinder mesin.',
      symptoms: ['Mesin pincang dan bergetar hebat', 'Tenaga hilang drastis', 'Lampu Check Engine berkedip'],
      possibleCauses: ['Busi aus/kotor', 'Koil pengapian lemah', 'Tekanan BBM rendah', 'Kompresi silinder bocor'],
      recommendations: ['Ganti seluruh busi', 'Cek tegangan koil pengapian', 'Uji tekanan kompresi silinder'],
    ),
    'P0301': DtcCode(
      code: 'P0301',
      title: 'Cylinder 1 Misfire Detected',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Pengapian hilang (misfire) khusus pada Silinder 1.',
      symptoms: ['Mesin bergetar saat stasioner', 'Suara mesin kasar', 'Akselerasi berat'],
      possibleCauses: ['Busi silinder 1 mati/aus', 'Koil silinder 1 rusak', 'Injektor 1 mampet'],
      recommendations: ['Tukar koil silinder 1 ke silinder 2 untuk pengujian', 'Ganti busi silinder 1', 'Bersihkan injektor 1'],
    ),
    'P0302': DtcCode(
      code: 'P0302',
      title: 'Cylinder 2 Misfire Detected',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Pengapian hilang (misfire) khusus pada Silinder 2.',
      symptoms: ['Mesin pincang', 'Getaran terasa sampai kabin', 'Check Engine aktif'],
      possibleCauses: ['Busi silinder 2 mati', 'Koil silinder 2 rusak', 'Masalah kompresi silinder 2'],
      recommendations: ['Cek dan ganti busi silinder 2', 'Uji koil silinder 2', 'Cek injektor silinder 2'],
    ),
    'P0303': DtcCode(
      code: 'P0303',
      title: 'Cylinder 3 Misfire Detected',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Pengapian hilang (misfire) khusus pada Silinder 3.',
      symptoms: ['Mesin berebet', 'Performa mesin menurun', 'Konsumsi BBM meningkat'],
      possibleCauses: ['Busi silinder 3 kotor/aus', 'Koil silinder 3 mati', 'Kabel koil rusak'],
      recommendations: ['Periksa busi & koil silinder 3', 'Ganti suku cadang pengapian bermasalah'],
    ),
    'P0304': DtcCode(
      code: 'P0304',
      title: 'Cylinder 4 Misfire Detected',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Pengapian hilang (misfire) khusus pada Silinder 4.',
      symptoms: ['Mesin pincang', 'Getaran berlebih', 'Tenaga drop'],
      possibleCauses: ['Busi silinder 4 aus', 'Koil silinder 4 rusak', 'Injektor 4 tersumbat'],
      recommendations: ['Cek busi & koil silinder 4', 'Lakukan tune up sistem pengapian'],
    ),

    // SENSOR POSISI CRANK & CAM (P0335 - P0340)
    'P0335': DtcCode(
      code: 'P0335',
      title: 'Crankshaft Position Sensor A Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.critical,
      descriptionIndo: 'Sensor posisi poros engkol (CKP) tidak mengirim sinyal ke ECU.',
      symptoms: ['Mesin mendadak mati saat jalan', 'Mesin diputar starter tapi tidak mau hidup', 'RPM meter mati'],
      possibleCauses: ['Sensor CKP rusak', 'Gigi reluctor kotor/rusak', 'Kabel CKP putus/korslet'],
      recommendations: ['Periksa soket & kabel sensor CKP', 'Ganti sensor Crankshaft (CKP)'],
    ),
    'P0340': DtcCode(
      code: 'P0340',
      title: 'Camshaft Position Sensor A Circuit Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Sensor posisi poros bubungan (CMP) bermasalah.',
      symptoms: ['Starter panjang baru hidup', 'Mesin kurang bertenaga', 'Waktu pengapian ngaco'],
      possibleCauses: ['Sensor CMP rusak', 'Timing chain/belt loncat', 'Kabel CMP korosi'],
      recommendations: ['Uji sinyal sensor CMP', 'Periksa kepresisian timing belt/chain', 'Ganti sensor CMP'],
    ),

    // EMISION & CATALYST (P0420 - P0455)
    'P0420': DtcCode(
      code: 'P0420',
      title: 'Catalyst System Efficiency Below Threshold (Bank 1)',
      category: 'Powertrain',
      severity: DtcSeverity.info,
      descriptionIndo: 'Efisiensi konverter katalitik (Catalytic Converter) di bawah ambang batas.',
      symptoms: ['Check Engine menyala tanpa keluhan mesin yang nyata', 'Bau tidak sedap dari knalpot'],
      possibleCauses: ['Katalis tersumbat/aus', 'Sensor O2 belakang rusak', 'Kebocoran knalpot'],
      recommendations: ['Uji kinerja sensor O2 belakang', 'Cek kelayakan fisik catalytic converter', 'Ganti catalytic converter'],
    ),
    'P0440': DtcCode(
      code: 'P0440',
      title: 'Evaporative Emission Control System Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.info,
      descriptionIndo: 'Sistem pengontrol uap bensin (EVAP) mengalami kebocoran atau gangguan.',
      symptoms: ['Bau bensin di sekitar tangki', 'Check Engine aktif'],
      possibleCauses: ['Tutup tangki bensin kendur/bocor', 'Selang kanister EVAP retak', 'Purge valve EVAP macet'],
      recommendations: ['Kencangkan atau ganti tutup tangki bensin', 'Periksa selang vakum EVAP', 'Uji solenoid purge valve'],
    ),

    // SPEED & IDLE CONTROL (P0500 - P0505)
    'P0500': DtcCode(
      code: 'P0500',
      title: 'Vehicle Speed Sensor (VSS) Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sensor kecepatan kendaraan (VSS) bermasalah.',
      symptoms: ['Spedometer mati atau melompat-lompat', 'Pindahan gigi matic tidak mulus', 'ABS warning menyala'],
      possibleCauses: ['Sensor VSS rusak', 'Kabel VSS terputus', 'Gigi penggerak VSS aus'],
      recommendations: ['Periksa sambungan kabel VSS', 'Ganti sensor VSS'],
    ),
    'P0505': DtcCode(
      code: 'P0505',
      title: 'Idle Air Control System Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sistem pengatur stasioner / IACV tidak dapat menjaga RPM idle.',
      symptoms: ['Mesin gampang mati saat lepas gas', 'RPM idle terlalu tinggi atau terlalu rendah'],
      possibleCauses: ['Katup IACV tersumbat kerak karbon', 'Motor katup IACV rusak', 'Kebocoran vakum'],
      recommendations: ['Lepas dan bersihkan katup IACV dengan karburator cleaner', 'Ganti katup IACV jika terbakar'],
    ),

    // TRANSMISSION (P0700 - P0750)
    'P0700': DtcCode(
      code: 'P0700',
      title: 'Transmission Control System Malfunction',
      category: 'Powertrain',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Modul kontrol transmisi (TCM) mengindikasikan adanya kerusakan internal transmisi.',
      symptoms: ['Transmisi otomatis mengunci di gigi 3 (Limp Mode)', 'Pindahan gigi menghentak keras'],
      possibleCauses: ['Oli matic kurang/kotor', 'Solenoid transmisi rusak', 'Modul TCM bermasalah'],
      recommendations: ['Cek level dan warna oli transmisi (ATF/CVTF)', 'Pindai modul TCM secara mendalam', 'Kunjungi spesialis transmisi matic'],
    ),

    // CHASSIS (C0035 - C0200)
    'C0035': DtcCode(
      code: 'C0035',
      title: 'Left Front Wheel Speed Sensor Circuit',
      category: 'Chassis',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sensor kecepatan roda depan kiri (ABS) bermasalah.',
      symptoms: ['Lampu indikator ABS & Traction Control menyala', 'Fitur rem ABS nonaktif'],
      possibleCauses: ['Sensor ABS depan kiri kotor terhalang lumpur/gram besi', 'Kabel sensor ABS terputus', 'Bearing roda aus'],
      recommendations: ['Bersihkan sensor ABS roda depan kiri', 'Periksa kelistrikan sensor', 'Ganti sensor ABS jika rusak'],
    ),
    'C0040': DtcCode(
      code: 'C0040',
      title: 'Right Front Wheel Speed Sensor Circuit',
      category: 'Chassis',
      severity: DtcSeverity.warning,
      descriptionIndo: 'Sensor kecepatan roda depan kanan (ABS) bermasalah.',
      symptoms: ['Lampu ABS menyala', 'Sistem pengereman kembali ke rem konvensional'],
      possibleCauses: ['Kabel sensor ABS putus', 'Sensor ABS kotor/rusak'],
      recommendations: ['Bersihkan & cek sensor ABS depan kanan'],
    ),

    // BODY (B0001 - B1000)
    'B0001': DtcCode(
      code: 'B0001',
      title: 'Driver Airbag Control Stage 1 Circuit',
      category: 'Body',
      severity: DtcSeverity.critical,
      descriptionIndo: 'Sirkuit kantong udara (Airbag) pengemudi mengalami gangguan.',
      symptoms: ['Indikator lampu Airbag SRS di meter cluster menyala terus'],
      possibleCauses: ['Spiral cable / clockspring stir putus', 'Soket airbag lepas', 'Modul SRS rusak'],
      recommendations: ['Periksa kelistrikan clockspring stir', 'Ganti spiral cable / clockspring'],
    ),

    // NETWORK / CAN-BUS (U0100 - U0400)
    'U0100': DtcCode(
      code: 'U0100',
      title: 'Lost Communication With ECM/PCM A',
      category: 'Network',
      severity: DtcSeverity.critical,
      descriptionIndo: 'Komunikasi jalur CAN-Bus ke Komputer Utama (ECU/ECM) terputus.',
      symptoms: ['Mobil tidak bisa di-start sama sekali', 'Seluruh indikator instrumen berkedip/mati'],
      possibleCauses: ['Fuse / sekering ECU putus', 'Kabel ground ECU kendur', 'Aki drop parah', 'ECU rusak'],
      recommendations: ['Cek sekering ECU & Main Fuse', 'Periksa kekencangan klem aki dan kabel ground ECU', 'Cek jalur kabel CAN-Bus'],
    ),
    'U0121': DtcCode(
      code: 'U0121',
      title: 'Lost Communication With Anti-Lock Brake System (ABS)',
      category: 'Network',
      severity: DtcSeverity.danger,
      descriptionIndo: 'Komunikasi jaringan CAN-Bus ke Modul ABS terputus.',
      symptoms: ['Lampu ABS, Handbrake, & Spedometer mati'],
      possibleCauses: ['Sekering modul ABS putus', 'Soket modul ABS kendur/kemasukan air'],
      recommendations: ['Cek sekering ABS', 'Keringkan & kencangkan soket modul ABS'],
    ),
  };

  static DtcCode getCodeInfo(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (_dtcDatabase.containsKey(cleanCode)) {
      return _dtcDatabase[cleanCode]!;
    }

    String category = 'Powertrain';
    if (cleanCode.startsWith('C')) category = 'Chassis';
    if (cleanCode.startsWith('B')) category = 'Body';
    if (cleanCode.startsWith('U')) category = 'Network';

    return DtcCode(
      code: cleanCode,
      title: 'Kode Kerusakan Otomotif ($cleanCode)',
      category: category,
      severity: DtcSeverity.warning,
      descriptionIndo: 'Kode Diagnostic Trouble Code ($cleanCode) terdeteksi pada sistem $category kendaraan.',
      symptoms: ['Lampu Check Engine / peringatan indikator menyala', 'Performa kendaraan mungkin terpengaruh'],
      possibleCauses: ['Gangguan pada kelistrikan atau sensor terkait sistem $category', 'Kabel/konektor sensor kendur'],
      recommendations: ['Lakukan konsultasi dengan mekanik atau bengkel resmi untuk pemeriksaan fisik sensor $cleanCode.'],
    );
  }

  static List<DtcCode> getAllCodes() {
    return _dtcDatabase.values.toList();
  }

  static List<DtcCode> searchCodes(String query, {String? categoryFilter}) {
    final cleanQuery = query.trim().toLowerCase();
    return _dtcDatabase.values.where((dtc) {
      final matchesQuery = cleanQuery.isEmpty ||
          dtc.code.toLowerCase().contains(cleanQuery) ||
          dtc.title.toLowerCase().contains(cleanQuery) ||
          dtc.descriptionIndo.toLowerCase().contains(cleanQuery);
      
      final matchesCategory = categoryFilter == null || categoryFilter == 'Semua' || dtc.category.toLowerCase() == categoryFilter.toLowerCase();
      
      return matchesQuery && matchesCategory;
    }).toList();
  }
}

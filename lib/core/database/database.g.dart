// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, odometer];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final int id;
  final String name;
  final double odometer;
  const Vehicle({required this.id, required this.name, required this.odometer});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['odometer'] = Variable<double>(odometer);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      name: Value(name),
      odometer: Value(odometer),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      odometer: serializer.fromJson<double>(json['odometer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'odometer': serializer.toJson<double>(odometer),
    };
  }

  Vehicle copyWith({int? id, String? name, double? odometer}) => Vehicle(
    id: id ?? this.id,
    name: name ?? this.name,
    odometer: odometer ?? this.odometer,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('odometer: $odometer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, odometer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.name == this.name &&
          other.odometer == this.odometer);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> odometer;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.odometer = const Value.absent(),
  });
  VehiclesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.odometer = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Vehicle> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? odometer,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (odometer != null) 'odometer': odometer,
    });
  }

  VehiclesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? odometer,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      odometer: odometer ?? this.odometer,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('odometer: $odometer')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta(
    'distance',
  );
  @override
  late final GeneratedColumn<double> distance = GeneratedColumn<double>(
    'distance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _fuelEconomyMeta = const VerificationMeta(
    'fuelEconomy',
  );
  @override
  late final GeneratedColumn<double> fuelEconomy = GeneratedColumn<double>(
    'fuel_economy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _avgSpeedMeta = const VerificationMeta(
    'avgSpeed',
  );
  @override
  late final GeneratedColumn<double> avgSpeed = GeneratedColumn<double>(
    'avg_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _maxCoolantMeta = const VerificationMeta(
    'maxCoolant',
  );
  @override
  late final GeneratedColumn<int> maxCoolant = GeneratedColumn<int>(
    'max_coolant',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxRpmMeta = const VerificationMeta('maxRpm');
  @override
  late final GeneratedColumn<int> maxRpm = GeneratedColumn<int>(
    'max_rpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tripHealthScoreMeta = const VerificationMeta(
    'tripHealthScore',
  );
  @override
  late final GeneratedColumn<int> tripHealthScore = GeneratedColumn<int>(
    'trip_health_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _idleMinutesMeta = const VerificationMeta(
    'idleMinutes',
  );
  @override
  late final GeneratedColumn<int> idleMinutes = GeneratedColumn<int>(
    'idle_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startTime,
    endTime,
    distance,
    fuelEconomy,
    avgSpeed,
    maxCoolant,
    maxRpm,
    tripHealthScore,
    durationMinutes,
    idleMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('distance')) {
      context.handle(
        _distanceMeta,
        distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta),
      );
    }
    if (data.containsKey('fuel_economy')) {
      context.handle(
        _fuelEconomyMeta,
        fuelEconomy.isAcceptableOrUnknown(
          data['fuel_economy']!,
          _fuelEconomyMeta,
        ),
      );
    }
    if (data.containsKey('avg_speed')) {
      context.handle(
        _avgSpeedMeta,
        avgSpeed.isAcceptableOrUnknown(data['avg_speed']!, _avgSpeedMeta),
      );
    }
    if (data.containsKey('max_coolant')) {
      context.handle(
        _maxCoolantMeta,
        maxCoolant.isAcceptableOrUnknown(data['max_coolant']!, _maxCoolantMeta),
      );
    }
    if (data.containsKey('max_rpm')) {
      context.handle(
        _maxRpmMeta,
        maxRpm.isAcceptableOrUnknown(data['max_rpm']!, _maxRpmMeta),
      );
    }
    if (data.containsKey('trip_health_score')) {
      context.handle(
        _tripHealthScoreMeta,
        tripHealthScore.isAcceptableOrUnknown(
          data['trip_health_score']!,
          _tripHealthScoreMeta,
        ),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('idle_minutes')) {
      context.handle(
        _idleMinutesMeta,
        idleMinutes.isAcceptableOrUnknown(
          data['idle_minutes']!,
          _idleMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      distance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance'],
      )!,
      fuelEconomy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_economy'],
      )!,
      avgSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_speed'],
      )!,
      maxCoolant: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_coolant'],
      )!,
      maxRpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_rpm'],
      )!,
      tripHealthScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_health_score'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      idleMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idle_minutes'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance;
  final double fuelEconomy;
  final double avgSpeed;
  final int maxCoolant;
  final int maxRpm;
  final int tripHealthScore;
  final int durationMinutes;
  final int idleMinutes;
  const Trip({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.distance,
    required this.fuelEconomy,
    required this.avgSpeed,
    required this.maxCoolant,
    required this.maxRpm,
    required this.tripHealthScore,
    required this.durationMinutes,
    required this.idleMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['distance'] = Variable<double>(distance);
    map['fuel_economy'] = Variable<double>(fuelEconomy);
    map['avg_speed'] = Variable<double>(avgSpeed);
    map['max_coolant'] = Variable<int>(maxCoolant);
    map['max_rpm'] = Variable<int>(maxRpm);
    map['trip_health_score'] = Variable<int>(tripHealthScore);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['idle_minutes'] = Variable<int>(idleMinutes);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      distance: Value(distance),
      fuelEconomy: Value(fuelEconomy),
      avgSpeed: Value(avgSpeed),
      maxCoolant: Value(maxCoolant),
      maxRpm: Value(maxRpm),
      tripHealthScore: Value(tripHealthScore),
      durationMinutes: Value(durationMinutes),
      idleMinutes: Value(idleMinutes),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<int>(json['id']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      distance: serializer.fromJson<double>(json['distance']),
      fuelEconomy: serializer.fromJson<double>(json['fuelEconomy']),
      avgSpeed: serializer.fromJson<double>(json['avgSpeed']),
      maxCoolant: serializer.fromJson<int>(json['maxCoolant']),
      maxRpm: serializer.fromJson<int>(json['maxRpm']),
      tripHealthScore: serializer.fromJson<int>(json['tripHealthScore']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      idleMinutes: serializer.fromJson<int>(json['idleMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'distance': serializer.toJson<double>(distance),
      'fuelEconomy': serializer.toJson<double>(fuelEconomy),
      'avgSpeed': serializer.toJson<double>(avgSpeed),
      'maxCoolant': serializer.toJson<int>(maxCoolant),
      'maxRpm': serializer.toJson<int>(maxRpm),
      'tripHealthScore': serializer.toJson<int>(tripHealthScore),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'idleMinutes': serializer.toJson<int>(idleMinutes),
    };
  }

  Trip copyWith({
    int? id,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    double? distance,
    double? fuelEconomy,
    double? avgSpeed,
    int? maxCoolant,
    int? maxRpm,
    int? tripHealthScore,
    int? durationMinutes,
    int? idleMinutes,
  }) => Trip(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    distance: distance ?? this.distance,
    fuelEconomy: fuelEconomy ?? this.fuelEconomy,
    avgSpeed: avgSpeed ?? this.avgSpeed,
    maxCoolant: maxCoolant ?? this.maxCoolant,
    maxRpm: maxRpm ?? this.maxRpm,
    tripHealthScore: tripHealthScore ?? this.tripHealthScore,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    idleMinutes: idleMinutes ?? this.idleMinutes,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      distance: data.distance.present ? data.distance.value : this.distance,
      fuelEconomy: data.fuelEconomy.present
          ? data.fuelEconomy.value
          : this.fuelEconomy,
      avgSpeed: data.avgSpeed.present ? data.avgSpeed.value : this.avgSpeed,
      maxCoolant: data.maxCoolant.present
          ? data.maxCoolant.value
          : this.maxCoolant,
      maxRpm: data.maxRpm.present ? data.maxRpm.value : this.maxRpm,
      tripHealthScore: data.tripHealthScore.present
          ? data.tripHealthScore.value
          : this.tripHealthScore,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      idleMinutes: data.idleMinutes.present
          ? data.idleMinutes.value
          : this.idleMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('distance: $distance, ')
          ..write('fuelEconomy: $fuelEconomy, ')
          ..write('avgSpeed: $avgSpeed, ')
          ..write('maxCoolant: $maxCoolant, ')
          ..write('maxRpm: $maxRpm, ')
          ..write('tripHealthScore: $tripHealthScore, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('idleMinutes: $idleMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startTime,
    endTime,
    distance,
    fuelEconomy,
    avgSpeed,
    maxCoolant,
    maxRpm,
    tripHealthScore,
    durationMinutes,
    idleMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.distance == this.distance &&
          other.fuelEconomy == this.fuelEconomy &&
          other.avgSpeed == this.avgSpeed &&
          other.maxCoolant == this.maxCoolant &&
          other.maxRpm == this.maxRpm &&
          other.tripHealthScore == this.tripHealthScore &&
          other.durationMinutes == this.durationMinutes &&
          other.idleMinutes == this.idleMinutes);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<int> id;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<double> distance;
  final Value<double> fuelEconomy;
  final Value<double> avgSpeed;
  final Value<int> maxCoolant;
  final Value<int> maxRpm;
  final Value<int> tripHealthScore;
  final Value<int> durationMinutes;
  final Value<int> idleMinutes;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.distance = const Value.absent(),
    this.fuelEconomy = const Value.absent(),
    this.avgSpeed = const Value.absent(),
    this.maxCoolant = const Value.absent(),
    this.maxRpm = const Value.absent(),
    this.tripHealthScore = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.idleMinutes = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startTime,
    this.endTime = const Value.absent(),
    this.distance = const Value.absent(),
    this.fuelEconomy = const Value.absent(),
    this.avgSpeed = const Value.absent(),
    this.maxCoolant = const Value.absent(),
    this.maxRpm = const Value.absent(),
    this.tripHealthScore = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.idleMinutes = const Value.absent(),
  }) : startTime = Value(startTime);
  static Insertable<Trip> custom({
    Expression<int>? id,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<double>? distance,
    Expression<double>? fuelEconomy,
    Expression<double>? avgSpeed,
    Expression<int>? maxCoolant,
    Expression<int>? maxRpm,
    Expression<int>? tripHealthScore,
    Expression<int>? durationMinutes,
    Expression<int>? idleMinutes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (distance != null) 'distance': distance,
      if (fuelEconomy != null) 'fuel_economy': fuelEconomy,
      if (avgSpeed != null) 'avg_speed': avgSpeed,
      if (maxCoolant != null) 'max_coolant': maxCoolant,
      if (maxRpm != null) 'max_rpm': maxRpm,
      if (tripHealthScore != null) 'trip_health_score': tripHealthScore,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (idleMinutes != null) 'idle_minutes': idleMinutes,
    });
  }

  TripsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<double>? distance,
    Value<double>? fuelEconomy,
    Value<double>? avgSpeed,
    Value<int>? maxCoolant,
    Value<int>? maxRpm,
    Value<int>? tripHealthScore,
    Value<int>? durationMinutes,
    Value<int>? idleMinutes,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      fuelEconomy: fuelEconomy ?? this.fuelEconomy,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      maxCoolant: maxCoolant ?? this.maxCoolant,
      maxRpm: maxRpm ?? this.maxRpm,
      tripHealthScore: tripHealthScore ?? this.tripHealthScore,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      idleMinutes: idleMinutes ?? this.idleMinutes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    if (fuelEconomy.present) {
      map['fuel_economy'] = Variable<double>(fuelEconomy.value);
    }
    if (avgSpeed.present) {
      map['avg_speed'] = Variable<double>(avgSpeed.value);
    }
    if (maxCoolant.present) {
      map['max_coolant'] = Variable<int>(maxCoolant.value);
    }
    if (maxRpm.present) {
      map['max_rpm'] = Variable<int>(maxRpm.value);
    }
    if (tripHealthScore.present) {
      map['trip_health_score'] = Variable<int>(tripHealthScore.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (idleMinutes.present) {
      map['idle_minutes'] = Variable<int>(idleMinutes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('distance: $distance, ')
          ..write('fuelEconomy: $fuelEconomy, ')
          ..write('avgSpeed: $avgSpeed, ')
          ..write('maxCoolant: $maxCoolant, ')
          ..write('maxRpm: $maxRpm, ')
          ..write('tripHealthScore: $tripHealthScore, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('idleMinutes: $idleMinutes')
          ..write(')'))
        .toString();
  }
}

class $TripPointsTable extends TripPoints
    with TableInfo<$TripPointsTable, TripPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rpmMeta = const VerificationMeta('rpm');
  @override
  late final GeneratedColumn<double> rpm = GeneratedColumn<double>(
    'rpm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coolantMeta = const VerificationMeta(
    'coolant',
  );
  @override
  late final GeneratedColumn<double> coolant = GeneratedColumn<double>(
    'coolant',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voltageMeta = const VerificationMeta(
    'voltage',
  );
  @override
  late final GeneratedColumn<double> voltage = GeneratedColumn<double>(
    'voltage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mapValueMeta = const VerificationMeta(
    'mapValue',
  );
  @override
  late final GeneratedColumn<double> mapValue = GeneratedColumn<double>(
    'map_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _throttleMeta = const VerificationMeta(
    'throttle',
  );
  @override
  late final GeneratedColumn<double> throttle = GeneratedColumn<double>(
    'throttle',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineLoadMeta = const VerificationMeta(
    'engineLoad',
  );
  @override
  late final GeneratedColumn<double> engineLoad = GeneratedColumn<double>(
    'engine_load',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelMeta = const VerificationMeta('fuel');
  @override
  late final GeneratedColumn<double> fuel = GeneratedColumn<double>(
    'fuel',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelEconomyMeta = const VerificationMeta(
    'fuelEconomy',
  );
  @override
  late final GeneratedColumn<double> fuelEconomy = GeneratedColumn<double>(
    'fuel_economy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intakeAirTempMeta = const VerificationMeta(
    'intakeAirTemp',
  );
  @override
  late final GeneratedColumn<double> intakeAirTemp = GeneratedColumn<double>(
    'intake_air_temp',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mafMeta = const VerificationMeta('maf');
  @override
  late final GeneratedColumn<double> maf = GeneratedColumn<double>(
    'maf',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timingAdvanceMeta = const VerificationMeta(
    'timingAdvance',
  );
  @override
  late final GeneratedColumn<double> timingAdvance = GeneratedColumn<double>(
    'timing_advance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    timestamp,
    rpm,
    speed,
    coolant,
    voltage,
    mapValue,
    throttle,
    engineLoad,
    fuel,
    fuelEconomy,
    intakeAirTemp,
    maf,
    timingAdvance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('rpm')) {
      context.handle(
        _rpmMeta,
        rpm.isAcceptableOrUnknown(data['rpm']!, _rpmMeta),
      );
    } else if (isInserting) {
      context.missing(_rpmMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    } else if (isInserting) {
      context.missing(_speedMeta);
    }
    if (data.containsKey('coolant')) {
      context.handle(
        _coolantMeta,
        coolant.isAcceptableOrUnknown(data['coolant']!, _coolantMeta),
      );
    } else if (isInserting) {
      context.missing(_coolantMeta);
    }
    if (data.containsKey('voltage')) {
      context.handle(
        _voltageMeta,
        voltage.isAcceptableOrUnknown(data['voltage']!, _voltageMeta),
      );
    } else if (isInserting) {
      context.missing(_voltageMeta);
    }
    if (data.containsKey('map_value')) {
      context.handle(
        _mapValueMeta,
        mapValue.isAcceptableOrUnknown(data['map_value']!, _mapValueMeta),
      );
    } else if (isInserting) {
      context.missing(_mapValueMeta);
    }
    if (data.containsKey('throttle')) {
      context.handle(
        _throttleMeta,
        throttle.isAcceptableOrUnknown(data['throttle']!, _throttleMeta),
      );
    }
    if (data.containsKey('engine_load')) {
      context.handle(
        _engineLoadMeta,
        engineLoad.isAcceptableOrUnknown(data['engine_load']!, _engineLoadMeta),
      );
    }
    if (data.containsKey('fuel')) {
      context.handle(
        _fuelMeta,
        fuel.isAcceptableOrUnknown(data['fuel']!, _fuelMeta),
      );
    }
    if (data.containsKey('fuel_economy')) {
      context.handle(
        _fuelEconomyMeta,
        fuelEconomy.isAcceptableOrUnknown(
          data['fuel_economy']!,
          _fuelEconomyMeta,
        ),
      );
    }
    if (data.containsKey('intake_air_temp')) {
      context.handle(
        _intakeAirTempMeta,
        intakeAirTemp.isAcceptableOrUnknown(
          data['intake_air_temp']!,
          _intakeAirTempMeta,
        ),
      );
    }
    if (data.containsKey('maf')) {
      context.handle(
        _mafMeta,
        maf.isAcceptableOrUnknown(data['maf']!, _mafMeta),
      );
    }
    if (data.containsKey('timing_advance')) {
      context.handle(
        _timingAdvanceMeta,
        timingAdvance.isAcceptableOrUnknown(
          data['timing_advance']!,
          _timingAdvanceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      rpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rpm'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      coolant: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}coolant'],
      )!,
      voltage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}voltage'],
      )!,
      mapValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}map_value'],
      )!,
      throttle: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}throttle'],
      ),
      engineLoad: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}engine_load'],
      ),
      fuel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel'],
      ),
      fuelEconomy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_economy'],
      ),
      intakeAirTemp: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intake_air_temp'],
      ),
      maf: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}maf'],
      ),
      timingAdvance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}timing_advance'],
      ),
    );
  }

  @override
  $TripPointsTable createAlias(String alias) {
    return $TripPointsTable(attachedDatabase, alias);
  }
}

class TripPoint extends DataClass implements Insertable<TripPoint> {
  final int id;
  final int? tripId;
  final DateTime timestamp;
  final double rpm;
  final double speed;
  final double coolant;
  final double voltage;
  final double mapValue;
  final double? throttle;
  final double? engineLoad;
  final double? fuel;
  final double? fuelEconomy;
  final double? intakeAirTemp;
  final double? maf;
  final double? timingAdvance;
  const TripPoint({
    required this.id,
    this.tripId,
    required this.timestamp,
    required this.rpm,
    required this.speed,
    required this.coolant,
    required this.voltage,
    required this.mapValue,
    this.throttle,
    this.engineLoad,
    this.fuel,
    this.fuelEconomy,
    this.intakeAirTemp,
    this.maf,
    this.timingAdvance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['rpm'] = Variable<double>(rpm);
    map['speed'] = Variable<double>(speed);
    map['coolant'] = Variable<double>(coolant);
    map['voltage'] = Variable<double>(voltage);
    map['map_value'] = Variable<double>(mapValue);
    if (!nullToAbsent || throttle != null) {
      map['throttle'] = Variable<double>(throttle);
    }
    if (!nullToAbsent || engineLoad != null) {
      map['engine_load'] = Variable<double>(engineLoad);
    }
    if (!nullToAbsent || fuel != null) {
      map['fuel'] = Variable<double>(fuel);
    }
    if (!nullToAbsent || fuelEconomy != null) {
      map['fuel_economy'] = Variable<double>(fuelEconomy);
    }
    if (!nullToAbsent || intakeAirTemp != null) {
      map['intake_air_temp'] = Variable<double>(intakeAirTemp);
    }
    if (!nullToAbsent || maf != null) {
      map['maf'] = Variable<double>(maf);
    }
    if (!nullToAbsent || timingAdvance != null) {
      map['timing_advance'] = Variable<double>(timingAdvance);
    }
    return map;
  }

  TripPointsCompanion toCompanion(bool nullToAbsent) {
    return TripPointsCompanion(
      id: Value(id),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      timestamp: Value(timestamp),
      rpm: Value(rpm),
      speed: Value(speed),
      coolant: Value(coolant),
      voltage: Value(voltage),
      mapValue: Value(mapValue),
      throttle: throttle == null && nullToAbsent
          ? const Value.absent()
          : Value(throttle),
      engineLoad: engineLoad == null && nullToAbsent
          ? const Value.absent()
          : Value(engineLoad),
      fuel: fuel == null && nullToAbsent ? const Value.absent() : Value(fuel),
      fuelEconomy: fuelEconomy == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelEconomy),
      intakeAirTemp: intakeAirTemp == null && nullToAbsent
          ? const Value.absent()
          : Value(intakeAirTemp),
      maf: maf == null && nullToAbsent ? const Value.absent() : Value(maf),
      timingAdvance: timingAdvance == null && nullToAbsent
          ? const Value.absent()
          : Value(timingAdvance),
    );
  }

  factory TripPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripPoint(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      rpm: serializer.fromJson<double>(json['rpm']),
      speed: serializer.fromJson<double>(json['speed']),
      coolant: serializer.fromJson<double>(json['coolant']),
      voltage: serializer.fromJson<double>(json['voltage']),
      mapValue: serializer.fromJson<double>(json['mapValue']),
      throttle: serializer.fromJson<double?>(json['throttle']),
      engineLoad: serializer.fromJson<double?>(json['engineLoad']),
      fuel: serializer.fromJson<double?>(json['fuel']),
      fuelEconomy: serializer.fromJson<double?>(json['fuelEconomy']),
      intakeAirTemp: serializer.fromJson<double?>(json['intakeAirTemp']),
      maf: serializer.fromJson<double?>(json['maf']),
      timingAdvance: serializer.fromJson<double?>(json['timingAdvance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int?>(tripId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'rpm': serializer.toJson<double>(rpm),
      'speed': serializer.toJson<double>(speed),
      'coolant': serializer.toJson<double>(coolant),
      'voltage': serializer.toJson<double>(voltage),
      'mapValue': serializer.toJson<double>(mapValue),
      'throttle': serializer.toJson<double?>(throttle),
      'engineLoad': serializer.toJson<double?>(engineLoad),
      'fuel': serializer.toJson<double?>(fuel),
      'fuelEconomy': serializer.toJson<double?>(fuelEconomy),
      'intakeAirTemp': serializer.toJson<double?>(intakeAirTemp),
      'maf': serializer.toJson<double?>(maf),
      'timingAdvance': serializer.toJson<double?>(timingAdvance),
    };
  }

  TripPoint copyWith({
    int? id,
    Value<int?> tripId = const Value.absent(),
    DateTime? timestamp,
    double? rpm,
    double? speed,
    double? coolant,
    double? voltage,
    double? mapValue,
    Value<double?> throttle = const Value.absent(),
    Value<double?> engineLoad = const Value.absent(),
    Value<double?> fuel = const Value.absent(),
    Value<double?> fuelEconomy = const Value.absent(),
    Value<double?> intakeAirTemp = const Value.absent(),
    Value<double?> maf = const Value.absent(),
    Value<double?> timingAdvance = const Value.absent(),
  }) => TripPoint(
    id: id ?? this.id,
    tripId: tripId.present ? tripId.value : this.tripId,
    timestamp: timestamp ?? this.timestamp,
    rpm: rpm ?? this.rpm,
    speed: speed ?? this.speed,
    coolant: coolant ?? this.coolant,
    voltage: voltage ?? this.voltage,
    mapValue: mapValue ?? this.mapValue,
    throttle: throttle.present ? throttle.value : this.throttle,
    engineLoad: engineLoad.present ? engineLoad.value : this.engineLoad,
    fuel: fuel.present ? fuel.value : this.fuel,
    fuelEconomy: fuelEconomy.present ? fuelEconomy.value : this.fuelEconomy,
    intakeAirTemp: intakeAirTemp.present
        ? intakeAirTemp.value
        : this.intakeAirTemp,
    maf: maf.present ? maf.value : this.maf,
    timingAdvance: timingAdvance.present
        ? timingAdvance.value
        : this.timingAdvance,
  );
  TripPoint copyWithCompanion(TripPointsCompanion data) {
    return TripPoint(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      rpm: data.rpm.present ? data.rpm.value : this.rpm,
      speed: data.speed.present ? data.speed.value : this.speed,
      coolant: data.coolant.present ? data.coolant.value : this.coolant,
      voltage: data.voltage.present ? data.voltage.value : this.voltage,
      mapValue: data.mapValue.present ? data.mapValue.value : this.mapValue,
      throttle: data.throttle.present ? data.throttle.value : this.throttle,
      engineLoad: data.engineLoad.present
          ? data.engineLoad.value
          : this.engineLoad,
      fuel: data.fuel.present ? data.fuel.value : this.fuel,
      fuelEconomy: data.fuelEconomy.present
          ? data.fuelEconomy.value
          : this.fuelEconomy,
      intakeAirTemp: data.intakeAirTemp.present
          ? data.intakeAirTemp.value
          : this.intakeAirTemp,
      maf: data.maf.present ? data.maf.value : this.maf,
      timingAdvance: data.timingAdvance.present
          ? data.timingAdvance.value
          : this.timingAdvance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripPoint(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('timestamp: $timestamp, ')
          ..write('rpm: $rpm, ')
          ..write('speed: $speed, ')
          ..write('coolant: $coolant, ')
          ..write('voltage: $voltage, ')
          ..write('mapValue: $mapValue, ')
          ..write('throttle: $throttle, ')
          ..write('engineLoad: $engineLoad, ')
          ..write('fuel: $fuel, ')
          ..write('fuelEconomy: $fuelEconomy, ')
          ..write('intakeAirTemp: $intakeAirTemp, ')
          ..write('maf: $maf, ')
          ..write('timingAdvance: $timingAdvance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    timestamp,
    rpm,
    speed,
    coolant,
    voltage,
    mapValue,
    throttle,
    engineLoad,
    fuel,
    fuelEconomy,
    intakeAirTemp,
    maf,
    timingAdvance,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripPoint &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.timestamp == this.timestamp &&
          other.rpm == this.rpm &&
          other.speed == this.speed &&
          other.coolant == this.coolant &&
          other.voltage == this.voltage &&
          other.mapValue == this.mapValue &&
          other.throttle == this.throttle &&
          other.engineLoad == this.engineLoad &&
          other.fuel == this.fuel &&
          other.fuelEconomy == this.fuelEconomy &&
          other.intakeAirTemp == this.intakeAirTemp &&
          other.maf == this.maf &&
          other.timingAdvance == this.timingAdvance);
}

class TripPointsCompanion extends UpdateCompanion<TripPoint> {
  final Value<int> id;
  final Value<int?> tripId;
  final Value<DateTime> timestamp;
  final Value<double> rpm;
  final Value<double> speed;
  final Value<double> coolant;
  final Value<double> voltage;
  final Value<double> mapValue;
  final Value<double?> throttle;
  final Value<double?> engineLoad;
  final Value<double?> fuel;
  final Value<double?> fuelEconomy;
  final Value<double?> intakeAirTemp;
  final Value<double?> maf;
  final Value<double?> timingAdvance;
  const TripPointsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rpm = const Value.absent(),
    this.speed = const Value.absent(),
    this.coolant = const Value.absent(),
    this.voltage = const Value.absent(),
    this.mapValue = const Value.absent(),
    this.throttle = const Value.absent(),
    this.engineLoad = const Value.absent(),
    this.fuel = const Value.absent(),
    this.fuelEconomy = const Value.absent(),
    this.intakeAirTemp = const Value.absent(),
    this.maf = const Value.absent(),
    this.timingAdvance = const Value.absent(),
  });
  TripPointsCompanion.insert({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    required DateTime timestamp,
    required double rpm,
    required double speed,
    required double coolant,
    required double voltage,
    required double mapValue,
    this.throttle = const Value.absent(),
    this.engineLoad = const Value.absent(),
    this.fuel = const Value.absent(),
    this.fuelEconomy = const Value.absent(),
    this.intakeAirTemp = const Value.absent(),
    this.maf = const Value.absent(),
    this.timingAdvance = const Value.absent(),
  }) : timestamp = Value(timestamp),
       rpm = Value(rpm),
       speed = Value(speed),
       coolant = Value(coolant),
       voltage = Value(voltage),
       mapValue = Value(mapValue);
  static Insertable<TripPoint> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<DateTime>? timestamp,
    Expression<double>? rpm,
    Expression<double>? speed,
    Expression<double>? coolant,
    Expression<double>? voltage,
    Expression<double>? mapValue,
    Expression<double>? throttle,
    Expression<double>? engineLoad,
    Expression<double>? fuel,
    Expression<double>? fuelEconomy,
    Expression<double>? intakeAirTemp,
    Expression<double>? maf,
    Expression<double>? timingAdvance,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (timestamp != null) 'timestamp': timestamp,
      if (rpm != null) 'rpm': rpm,
      if (speed != null) 'speed': speed,
      if (coolant != null) 'coolant': coolant,
      if (voltage != null) 'voltage': voltage,
      if (mapValue != null) 'map_value': mapValue,
      if (throttle != null) 'throttle': throttle,
      if (engineLoad != null) 'engine_load': engineLoad,
      if (fuel != null) 'fuel': fuel,
      if (fuelEconomy != null) 'fuel_economy': fuelEconomy,
      if (intakeAirTemp != null) 'intake_air_temp': intakeAirTemp,
      if (maf != null) 'maf': maf,
      if (timingAdvance != null) 'timing_advance': timingAdvance,
    });
  }

  TripPointsCompanion copyWith({
    Value<int>? id,
    Value<int?>? tripId,
    Value<DateTime>? timestamp,
    Value<double>? rpm,
    Value<double>? speed,
    Value<double>? coolant,
    Value<double>? voltage,
    Value<double>? mapValue,
    Value<double?>? throttle,
    Value<double?>? engineLoad,
    Value<double?>? fuel,
    Value<double?>? fuelEconomy,
    Value<double?>? intakeAirTemp,
    Value<double?>? maf,
    Value<double?>? timingAdvance,
  }) {
    return TripPointsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      timestamp: timestamp ?? this.timestamp,
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      coolant: coolant ?? this.coolant,
      voltage: voltage ?? this.voltage,
      mapValue: mapValue ?? this.mapValue,
      throttle: throttle ?? this.throttle,
      engineLoad: engineLoad ?? this.engineLoad,
      fuel: fuel ?? this.fuel,
      fuelEconomy: fuelEconomy ?? this.fuelEconomy,
      intakeAirTemp: intakeAirTemp ?? this.intakeAirTemp,
      maf: maf ?? this.maf,
      timingAdvance: timingAdvance ?? this.timingAdvance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rpm.present) {
      map['rpm'] = Variable<double>(rpm.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (coolant.present) {
      map['coolant'] = Variable<double>(coolant.value);
    }
    if (voltage.present) {
      map['voltage'] = Variable<double>(voltage.value);
    }
    if (mapValue.present) {
      map['map_value'] = Variable<double>(mapValue.value);
    }
    if (throttle.present) {
      map['throttle'] = Variable<double>(throttle.value);
    }
    if (engineLoad.present) {
      map['engine_load'] = Variable<double>(engineLoad.value);
    }
    if (fuel.present) {
      map['fuel'] = Variable<double>(fuel.value);
    }
    if (fuelEconomy.present) {
      map['fuel_economy'] = Variable<double>(fuelEconomy.value);
    }
    if (intakeAirTemp.present) {
      map['intake_air_temp'] = Variable<double>(intakeAirTemp.value);
    }
    if (maf.present) {
      map['maf'] = Variable<double>(maf.value);
    }
    if (timingAdvance.present) {
      map['timing_advance'] = Variable<double>(timingAdvance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripPointsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('timestamp: $timestamp, ')
          ..write('rpm: $rpm, ')
          ..write('speed: $speed, ')
          ..write('coolant: $coolant, ')
          ..write('voltage: $voltage, ')
          ..write('mapValue: $mapValue, ')
          ..write('throttle: $throttle, ')
          ..write('engineLoad: $engineLoad, ')
          ..write('fuel: $fuel, ')
          ..write('fuelEconomy: $fuelEconomy, ')
          ..write('intakeAirTemp: $intakeAirTemp, ')
          ..write('maf: $maf, ')
          ..write('timingAdvance: $timingAdvance')
          ..write(')'))
        .toString();
  }
}

class $FuelLogsTable extends FuelLogs with TableInfo<$FuelLogsTable, FuelLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FuelLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fuelTypeMeta = const VerificationMeta(
    'fuelType',
  );
  @override
  late final GeneratedColumn<String> fuelType = GeneratedColumn<String>(
    'fuel_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _litersMeta = const VerificationMeta('liters');
  @override
  late final GeneratedColumn<double> liters = GeneratedColumn<double>(
    'liters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _economyMeta = const VerificationMeta(
    'economy',
  );
  @override
  late final GeneratedColumn<double> economy = GeneratedColumn<double>(
    'economy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    fuelType,
    liters,
    price,
    odometer,
    economy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fuel_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FuelLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('fuel_type')) {
      context.handle(
        _fuelTypeMeta,
        fuelType.isAcceptableOrUnknown(data['fuel_type']!, _fuelTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fuelTypeMeta);
    }
    if (data.containsKey('liters')) {
      context.handle(
        _litersMeta,
        liters.isAcceptableOrUnknown(data['liters']!, _litersMeta),
      );
    } else if (isInserting) {
      context.missing(_litersMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMeta);
    }
    if (data.containsKey('economy')) {
      context.handle(
        _economyMeta,
        economy.isAcceptableOrUnknown(data['economy']!, _economyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FuelLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FuelLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      fuelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_type'],
      )!,
      liters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}liters'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
      economy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}economy'],
      ),
    );
  }

  @override
  $FuelLogsTable createAlias(String alias) {
    return $FuelLogsTable(attachedDatabase, alias);
  }
}

class FuelLog extends DataClass implements Insertable<FuelLog> {
  final int id;
  final DateTime timestamp;
  final String fuelType;
  final double liters;
  final double price;
  final double odometer;
  final double? economy;
  const FuelLog({
    required this.id,
    required this.timestamp,
    required this.fuelType,
    required this.liters,
    required this.price,
    required this.odometer,
    this.economy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['fuel_type'] = Variable<String>(fuelType);
    map['liters'] = Variable<double>(liters);
    map['price'] = Variable<double>(price);
    map['odometer'] = Variable<double>(odometer);
    if (!nullToAbsent || economy != null) {
      map['economy'] = Variable<double>(economy);
    }
    return map;
  }

  FuelLogsCompanion toCompanion(bool nullToAbsent) {
    return FuelLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      fuelType: Value(fuelType),
      liters: Value(liters),
      price: Value(price),
      odometer: Value(odometer),
      economy: economy == null && nullToAbsent
          ? const Value.absent()
          : Value(economy),
    );
  }

  factory FuelLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FuelLog(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      fuelType: serializer.fromJson<String>(json['fuelType']),
      liters: serializer.fromJson<double>(json['liters']),
      price: serializer.fromJson<double>(json['price']),
      odometer: serializer.fromJson<double>(json['odometer']),
      economy: serializer.fromJson<double?>(json['economy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'fuelType': serializer.toJson<String>(fuelType),
      'liters': serializer.toJson<double>(liters),
      'price': serializer.toJson<double>(price),
      'odometer': serializer.toJson<double>(odometer),
      'economy': serializer.toJson<double?>(economy),
    };
  }

  FuelLog copyWith({
    int? id,
    DateTime? timestamp,
    String? fuelType,
    double? liters,
    double? price,
    double? odometer,
    Value<double?> economy = const Value.absent(),
  }) => FuelLog(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    fuelType: fuelType ?? this.fuelType,
    liters: liters ?? this.liters,
    price: price ?? this.price,
    odometer: odometer ?? this.odometer,
    economy: economy.present ? economy.value : this.economy,
  );
  FuelLog copyWithCompanion(FuelLogsCompanion data) {
    return FuelLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      fuelType: data.fuelType.present ? data.fuelType.value : this.fuelType,
      liters: data.liters.present ? data.liters.value : this.liters,
      price: data.price.present ? data.price.value : this.price,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      economy: data.economy.present ? data.economy.value : this.economy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FuelLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('fuelType: $fuelType, ')
          ..write('liters: $liters, ')
          ..write('price: $price, ')
          ..write('odometer: $odometer, ')
          ..write('economy: $economy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, fuelType, liters, price, odometer, economy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FuelLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.fuelType == this.fuelType &&
          other.liters == this.liters &&
          other.price == this.price &&
          other.odometer == this.odometer &&
          other.economy == this.economy);
}

class FuelLogsCompanion extends UpdateCompanion<FuelLog> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> fuelType;
  final Value<double> liters;
  final Value<double> price;
  final Value<double> odometer;
  final Value<double?> economy;
  const FuelLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.fuelType = const Value.absent(),
    this.liters = const Value.absent(),
    this.price = const Value.absent(),
    this.odometer = const Value.absent(),
    this.economy = const Value.absent(),
  });
  FuelLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String fuelType,
    required double liters,
    required double price,
    required double odometer,
    this.economy = const Value.absent(),
  }) : timestamp = Value(timestamp),
       fuelType = Value(fuelType),
       liters = Value(liters),
       price = Value(price),
       odometer = Value(odometer);
  static Insertable<FuelLog> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? fuelType,
    Expression<double>? liters,
    Expression<double>? price,
    Expression<double>? odometer,
    Expression<double>? economy,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (fuelType != null) 'fuel_type': fuelType,
      if (liters != null) 'liters': liters,
      if (price != null) 'price': price,
      if (odometer != null) 'odometer': odometer,
      if (economy != null) 'economy': economy,
    });
  }

  FuelLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? fuelType,
    Value<double>? liters,
    Value<double>? price,
    Value<double>? odometer,
    Value<double?>? economy,
  }) {
    return FuelLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      fuelType: fuelType ?? this.fuelType,
      liters: liters ?? this.liters,
      price: price ?? this.price,
      odometer: odometer ?? this.odometer,
      economy: economy ?? this.economy,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (fuelType.present) {
      map['fuel_type'] = Variable<String>(fuelType.value);
    }
    if (liters.present) {
      map['liters'] = Variable<double>(liters.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (economy.present) {
      map['economy'] = Variable<double>(economy.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FuelLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('fuelType: $fuelType, ')
          ..write('liters: $liters, ')
          ..write('price: $price, ')
          ..write('odometer: $odometer, ')
          ..write('economy: $economy')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceLogsTable extends MaintenanceLogs
    with TableInfo<$MaintenanceLogsTable, MaintenanceLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
    'cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    type,
    description,
    odometer,
    cost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost'],
      )!,
    );
  }

  @override
  $MaintenanceLogsTable createAlias(String alias) {
    return $MaintenanceLogsTable(attachedDatabase, alias);
  }
}

class MaintenanceLog extends DataClass implements Insertable<MaintenanceLog> {
  final int id;
  final DateTime timestamp;
  final String type;
  final String? description;
  final double odometer;
  final double cost;
  const MaintenanceLog({
    required this.id,
    required this.timestamp,
    required this.type,
    this.description,
    required this.odometer,
    required this.cost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['odometer'] = Variable<double>(odometer);
    map['cost'] = Variable<double>(cost);
    return map;
  }

  MaintenanceLogsCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      type: Value(type),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      odometer: Value(odometer),
      cost: Value(cost),
    );
  }

  factory MaintenanceLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceLog(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      odometer: serializer.fromJson<double>(json['odometer']),
      cost: serializer.fromJson<double>(json['cost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String?>(description),
      'odometer': serializer.toJson<double>(odometer),
      'cost': serializer.toJson<double>(cost),
    };
  }

  MaintenanceLog copyWith({
    int? id,
    DateTime? timestamp,
    String? type,
    Value<String?> description = const Value.absent(),
    double? odometer,
    double? cost,
  }) => MaintenanceLog(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    description: description.present ? description.value : this.description,
    odometer: odometer ?? this.odometer,
    cost: cost ?? this.cost,
  );
  MaintenanceLog copyWithCompanion(MaintenanceLogsCompanion data) {
    return MaintenanceLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      cost: data.cost.present ? data.cost.value : this.cost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('odometer: $odometer, ')
          ..write('cost: $cost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, type, description, odometer, cost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.description == this.description &&
          other.odometer == this.odometer &&
          other.cost == this.cost);
}

class MaintenanceLogsCompanion extends UpdateCompanion<MaintenanceLog> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> type;
  final Value<String?> description;
  final Value<double> odometer;
  final Value<double> cost;
  const MaintenanceLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.odometer = const Value.absent(),
    this.cost = const Value.absent(),
  });
  MaintenanceLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String type,
    this.description = const Value.absent(),
    required double odometer,
    this.cost = const Value.absent(),
  }) : timestamp = Value(timestamp),
       type = Value(type),
       odometer = Value(odometer);
  static Insertable<MaintenanceLog> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? type,
    Expression<String>? description,
    Expression<double>? odometer,
    Expression<double>? cost,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (odometer != null) 'odometer': odometer,
      if (cost != null) 'cost': cost,
    });
  }

  MaintenanceLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? type,
    Value<String?>? description,
    Value<double>? odometer,
    Value<double>? cost,
  }) {
    return MaintenanceLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      description: description ?? this.description,
      odometer: odometer ?? this.odometer,
      cost: cost ?? this.cost,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('odometer: $odometer, ')
          ..write('cost: $cost')
          ..write(')'))
        .toString();
  }
}

class $DtcLogsTable extends DtcLogs with TableInfo<$DtcLogsTable, DtcLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DtcLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 5,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _resolvedTimeMeta = const VerificationMeta(
    'resolvedTime',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedTime = GeneratedColumn<DateTime>(
    'resolved_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    code,
    description,
    category,
    active,
    resolvedTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dtc_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DtcLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('resolved_time')) {
      context.handle(
        _resolvedTimeMeta,
        resolvedTime.isAcceptableOrUnknown(
          data['resolved_time']!,
          _resolvedTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DtcLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DtcLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      resolvedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_time'],
      ),
    );
  }

  @override
  $DtcLogsTable createAlias(String alias) {
    return $DtcLogsTable(attachedDatabase, alias);
  }
}

class DtcLog extends DataClass implements Insertable<DtcLog> {
  final int id;
  final DateTime timestamp;
  final String code;
  final String description;
  final String category;
  final bool active;
  final DateTime? resolvedTime;
  const DtcLog({
    required this.id,
    required this.timestamp,
    required this.code,
    required this.description,
    required this.category,
    required this.active,
    this.resolvedTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['code'] = Variable<String>(code);
    map['description'] = Variable<String>(description);
    map['category'] = Variable<String>(category);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || resolvedTime != null) {
      map['resolved_time'] = Variable<DateTime>(resolvedTime);
    }
    return map;
  }

  DtcLogsCompanion toCompanion(bool nullToAbsent) {
    return DtcLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      code: Value(code),
      description: Value(description),
      category: Value(category),
      active: Value(active),
      resolvedTime: resolvedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedTime),
    );
  }

  factory DtcLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DtcLog(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      code: serializer.fromJson<String>(json['code']),
      description: serializer.fromJson<String>(json['description']),
      category: serializer.fromJson<String>(json['category']),
      active: serializer.fromJson<bool>(json['active']),
      resolvedTime: serializer.fromJson<DateTime?>(json['resolvedTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'code': serializer.toJson<String>(code),
      'description': serializer.toJson<String>(description),
      'category': serializer.toJson<String>(category),
      'active': serializer.toJson<bool>(active),
      'resolvedTime': serializer.toJson<DateTime?>(resolvedTime),
    };
  }

  DtcLog copyWith({
    int? id,
    DateTime? timestamp,
    String? code,
    String? description,
    String? category,
    bool? active,
    Value<DateTime?> resolvedTime = const Value.absent(),
  }) => DtcLog(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    code: code ?? this.code,
    description: description ?? this.description,
    category: category ?? this.category,
    active: active ?? this.active,
    resolvedTime: resolvedTime.present ? resolvedTime.value : this.resolvedTime,
  );
  DtcLog copyWithCompanion(DtcLogsCompanion data) {
    return DtcLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      code: data.code.present ? data.code.value : this.code,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
      active: data.active.present ? data.active.value : this.active,
      resolvedTime: data.resolvedTime.present
          ? data.resolvedTime.value
          : this.resolvedTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DtcLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('code: $code, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('active: $active, ')
          ..write('resolvedTime: $resolvedTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    code,
    description,
    category,
    active,
    resolvedTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DtcLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.code == this.code &&
          other.description == this.description &&
          other.category == this.category &&
          other.active == this.active &&
          other.resolvedTime == this.resolvedTime);
}

class DtcLogsCompanion extends UpdateCompanion<DtcLog> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> code;
  final Value<String> description;
  final Value<String> category;
  final Value<bool> active;
  final Value<DateTime?> resolvedTime;
  const DtcLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.code = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.active = const Value.absent(),
    this.resolvedTime = const Value.absent(),
  });
  DtcLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String code,
    required String description,
    required String category,
    this.active = const Value.absent(),
    this.resolvedTime = const Value.absent(),
  }) : timestamp = Value(timestamp),
       code = Value(code),
       description = Value(description),
       category = Value(category);
  static Insertable<DtcLog> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? code,
    Expression<String>? description,
    Expression<String>? category,
    Expression<bool>? active,
    Expression<DateTime>? resolvedTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (active != null) 'active': active,
      if (resolvedTime != null) 'resolved_time': resolvedTime,
    });
  }

  DtcLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? code,
    Value<String>? description,
    Value<String>? category,
    Value<bool>? active,
    Value<DateTime?>? resolvedTime,
  }) {
    return DtcLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      code: code ?? this.code,
      description: description ?? this.description,
      category: category ?? this.category,
      active: active ?? this.active,
      resolvedTime: resolvedTime ?? this.resolvedTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (resolvedTime.present) {
      map['resolved_time'] = Variable<DateTime>(resolvedTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DtcLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('code: $code, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('active: $active, ')
          ..write('resolvedTime: $resolvedTime')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final String key;
  final String value;
  const UserPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory UserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UserPreference copyWith({String? key, String? value}) =>
      UserPreference(key: key ?? this.key, value: value ?? this.value);
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const UserPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<UserPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return UserPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripPointsTable tripPoints = $TripPointsTable(this);
  late final $FuelLogsTable fuelLogs = $FuelLogsTable(this);
  late final $MaintenanceLogsTable maintenanceLogs = $MaintenanceLogsTable(
    this,
  );
  late final $DtcLogsTable dtcLogs = $DtcLogsTable(this);
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    trips,
    tripPoints,
    fuelLogs,
    maintenanceLogs,
    dtcLogs,
    userPreferences,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_points', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      Value<int> id,
      required String name,
      Value<double> odometer,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> odometer,
    });

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
          Vehicle,
          PrefetchHooks Function()
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> odometer = const Value.absent(),
              }) => VehiclesCompanion(id: id, name: name, odometer: odometer),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double> odometer = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                name: name,
                odometer: odometer,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
      Vehicle,
      PrefetchHooks Function()
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      required DateTime startTime,
      Value<DateTime?> endTime,
      Value<double> distance,
      Value<double> fuelEconomy,
      Value<double> avgSpeed,
      Value<int> maxCoolant,
      Value<int> maxRpm,
      Value<int> tripHealthScore,
      Value<int> durationMinutes,
      Value<int> idleMinutes,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<double> distance,
      Value<double> fuelEconomy,
      Value<double> avgSpeed,
      Value<int> maxCoolant,
      Value<int> maxRpm,
      Value<int> tripHealthScore,
      Value<int> durationMinutes,
      Value<int> idleMinutes,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripPointsTable, List<TripPoint>>
  _tripPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripPoints,
    aliasName: $_aliasNameGenerator(db.trips.id, db.tripPoints.tripId),
  );

  $$TripPointsTableProcessedTableManager get tripPointsRefs {
    final manager = $$TripPointsTableTableManager(
      $_db,
      $_db.tripPoints,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgSpeed => $composableBuilder(
    column: $table.avgSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCoolant => $composableBuilder(
    column: $table.maxCoolant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRpm => $composableBuilder(
    column: $table.maxRpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tripHealthScore => $composableBuilder(
    column: $table.tripHealthScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idleMinutes => $composableBuilder(
    column: $table.idleMinutes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripPointsRefs(
    Expression<bool> Function($$TripPointsTableFilterComposer f) f,
  ) {
    final $$TripPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripPoints,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripPointsTableFilterComposer(
            $db: $db,
            $table: $db.tripPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgSpeed => $composableBuilder(
    column: $table.avgSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCoolant => $composableBuilder(
    column: $table.maxCoolant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRpm => $composableBuilder(
    column: $table.maxRpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tripHealthScore => $composableBuilder(
    column: $table.tripHealthScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idleMinutes => $composableBuilder(
    column: $table.idleMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgSpeed =>
      $composableBuilder(column: $table.avgSpeed, builder: (column) => column);

  GeneratedColumn<int> get maxCoolant => $composableBuilder(
    column: $table.maxCoolant,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxRpm =>
      $composableBuilder(column: $table.maxRpm, builder: (column) => column);

  GeneratedColumn<int> get tripHealthScore => $composableBuilder(
    column: $table.tripHealthScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get idleMinutes => $composableBuilder(
    column: $table.idleMinutes,
    builder: (column) => column,
  );

  Expression<T> tripPointsRefs<T extends Object>(
    Expression<T> Function($$TripPointsTableAnnotationComposer a) f,
  ) {
    final $$TripPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripPoints,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({bool tripPointsRefs})
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> distance = const Value.absent(),
                Value<double> fuelEconomy = const Value.absent(),
                Value<double> avgSpeed = const Value.absent(),
                Value<int> maxCoolant = const Value.absent(),
                Value<int> maxRpm = const Value.absent(),
                Value<int> tripHealthScore = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> idleMinutes = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                startTime: startTime,
                endTime: endTime,
                distance: distance,
                fuelEconomy: fuelEconomy,
                avgSpeed: avgSpeed,
                maxCoolant: maxCoolant,
                maxRpm: maxRpm,
                tripHealthScore: tripHealthScore,
                durationMinutes: durationMinutes,
                idleMinutes: idleMinutes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> distance = const Value.absent(),
                Value<double> fuelEconomy = const Value.absent(),
                Value<double> avgSpeed = const Value.absent(),
                Value<int> maxCoolant = const Value.absent(),
                Value<int> maxRpm = const Value.absent(),
                Value<int> tripHealthScore = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> idleMinutes = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                startTime: startTime,
                endTime: endTime,
                distance: distance,
                fuelEconomy: fuelEconomy,
                avgSpeed: avgSpeed,
                maxCoolant: maxCoolant,
                maxRpm: maxRpm,
                tripHealthScore: tripHealthScore,
                durationMinutes: durationMinutes,
                idleMinutes: idleMinutes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tripPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripPointsRefs) db.tripPoints],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripPointsRefs)
                    await $_getPrefetchedData<Trip, $TripsTable, TripPoint>(
                      currentTable: table,
                      referencedTable: $$TripsTableReferences
                          ._tripPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TripsTableReferences(db, table, p0).tripPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tripId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({bool tripPointsRefs})
    >;
typedef $$TripPointsTableCreateCompanionBuilder =
    TripPointsCompanion Function({
      Value<int> id,
      Value<int?> tripId,
      required DateTime timestamp,
      required double rpm,
      required double speed,
      required double coolant,
      required double voltage,
      required double mapValue,
      Value<double?> throttle,
      Value<double?> engineLoad,
      Value<double?> fuel,
      Value<double?> fuelEconomy,
      Value<double?> intakeAirTemp,
      Value<double?> maf,
      Value<double?> timingAdvance,
    });
typedef $$TripPointsTableUpdateCompanionBuilder =
    TripPointsCompanion Function({
      Value<int> id,
      Value<int?> tripId,
      Value<DateTime> timestamp,
      Value<double> rpm,
      Value<double> speed,
      Value<double> coolant,
      Value<double> voltage,
      Value<double> mapValue,
      Value<double?> throttle,
      Value<double?> engineLoad,
      Value<double?> fuel,
      Value<double?> fuelEconomy,
      Value<double?> intakeAirTemp,
      Value<double?> maf,
      Value<double?> timingAdvance,
    });

final class $$TripPointsTableReferences
    extends BaseReferences<_$AppDatabase, $TripPointsTable, TripPoint> {
  $$TripPointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) => db.trips.createAlias(
    $_aliasNameGenerator(db.tripPoints.tripId, db.trips.id),
  );

  $$TripsTableProcessedTableManager? get tripId {
    final $_column = $_itemColumn<int>('trip_id');
    if ($_column == null) return null;
    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripPointsTableFilterComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rpm => $composableBuilder(
    column: $table.rpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get coolant => $composableBuilder(
    column: $table.coolant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get voltage => $composableBuilder(
    column: $table.voltage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mapValue => $composableBuilder(
    column: $table.mapValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get throttle => $composableBuilder(
    column: $table.throttle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get engineLoad => $composableBuilder(
    column: $table.engineLoad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuel => $composableBuilder(
    column: $table.fuel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intakeAirTemp => $composableBuilder(
    column: $table.intakeAirTemp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maf => $composableBuilder(
    column: $table.maf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get timingAdvance => $composableBuilder(
    column: $table.timingAdvance,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rpm => $composableBuilder(
    column: $table.rpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get coolant => $composableBuilder(
    column: $table.coolant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get voltage => $composableBuilder(
    column: $table.voltage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mapValue => $composableBuilder(
    column: $table.mapValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get throttle => $composableBuilder(
    column: $table.throttle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get engineLoad => $composableBuilder(
    column: $table.engineLoad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuel => $composableBuilder(
    column: $table.fuel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intakeAirTemp => $composableBuilder(
    column: $table.intakeAirTemp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maf => $composableBuilder(
    column: $table.maf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get timingAdvance => $composableBuilder(
    column: $table.timingAdvance,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripPointsTable> {
  $$TripPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get rpm =>
      $composableBuilder(column: $table.rpm, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get coolant =>
      $composableBuilder(column: $table.coolant, builder: (column) => column);

  GeneratedColumn<double> get voltage =>
      $composableBuilder(column: $table.voltage, builder: (column) => column);

  GeneratedColumn<double> get mapValue =>
      $composableBuilder(column: $table.mapValue, builder: (column) => column);

  GeneratedColumn<double> get throttle =>
      $composableBuilder(column: $table.throttle, builder: (column) => column);

  GeneratedColumn<double> get engineLoad => $composableBuilder(
    column: $table.engineLoad,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fuel =>
      $composableBuilder(column: $table.fuel, builder: (column) => column);

  GeneratedColumn<double> get fuelEconomy => $composableBuilder(
    column: $table.fuelEconomy,
    builder: (column) => column,
  );

  GeneratedColumn<double> get intakeAirTemp => $composableBuilder(
    column: $table.intakeAirTemp,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maf =>
      $composableBuilder(column: $table.maf, builder: (column) => column);

  GeneratedColumn<double> get timingAdvance => $composableBuilder(
    column: $table.timingAdvance,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripPointsTable,
          TripPoint,
          $$TripPointsTableFilterComposer,
          $$TripPointsTableOrderingComposer,
          $$TripPointsTableAnnotationComposer,
          $$TripPointsTableCreateCompanionBuilder,
          $$TripPointsTableUpdateCompanionBuilder,
          (TripPoint, $$TripPointsTableReferences),
          TripPoint,
          PrefetchHooks Function({bool tripId})
        > {
  $$TripPointsTableTableManager(_$AppDatabase db, $TripPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> rpm = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<double> coolant = const Value.absent(),
                Value<double> voltage = const Value.absent(),
                Value<double> mapValue = const Value.absent(),
                Value<double?> throttle = const Value.absent(),
                Value<double?> engineLoad = const Value.absent(),
                Value<double?> fuel = const Value.absent(),
                Value<double?> fuelEconomy = const Value.absent(),
                Value<double?> intakeAirTemp = const Value.absent(),
                Value<double?> maf = const Value.absent(),
                Value<double?> timingAdvance = const Value.absent(),
              }) => TripPointsCompanion(
                id: id,
                tripId: tripId,
                timestamp: timestamp,
                rpm: rpm,
                speed: speed,
                coolant: coolant,
                voltage: voltage,
                mapValue: mapValue,
                throttle: throttle,
                engineLoad: engineLoad,
                fuel: fuel,
                fuelEconomy: fuelEconomy,
                intakeAirTemp: intakeAirTemp,
                maf: maf,
                timingAdvance: timingAdvance,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                required DateTime timestamp,
                required double rpm,
                required double speed,
                required double coolant,
                required double voltage,
                required double mapValue,
                Value<double?> throttle = const Value.absent(),
                Value<double?> engineLoad = const Value.absent(),
                Value<double?> fuel = const Value.absent(),
                Value<double?> fuelEconomy = const Value.absent(),
                Value<double?> intakeAirTemp = const Value.absent(),
                Value<double?> maf = const Value.absent(),
                Value<double?> timingAdvance = const Value.absent(),
              }) => TripPointsCompanion.insert(
                id: id,
                tripId: tripId,
                timestamp: timestamp,
                rpm: rpm,
                speed: speed,
                coolant: coolant,
                voltage: voltage,
                mapValue: mapValue,
                throttle: throttle,
                engineLoad: engineLoad,
                fuel: fuel,
                fuelEconomy: fuelEconomy,
                intakeAirTemp: intakeAirTemp,
                maf: maf,
                timingAdvance: timingAdvance,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripPointsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripPointsTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TripPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripPointsTable,
      TripPoint,
      $$TripPointsTableFilterComposer,
      $$TripPointsTableOrderingComposer,
      $$TripPointsTableAnnotationComposer,
      $$TripPointsTableCreateCompanionBuilder,
      $$TripPointsTableUpdateCompanionBuilder,
      (TripPoint, $$TripPointsTableReferences),
      TripPoint,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$FuelLogsTableCreateCompanionBuilder =
    FuelLogsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String fuelType,
      required double liters,
      required double price,
      required double odometer,
      Value<double?> economy,
    });
typedef $$FuelLogsTableUpdateCompanionBuilder =
    FuelLogsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> fuelType,
      Value<double> liters,
      Value<double> price,
      Value<double> odometer,
      Value<double?> economy,
    });

class $$FuelLogsTableFilterComposer
    extends Composer<_$AppDatabase, $FuelLogsTable> {
  $$FuelLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get liters => $composableBuilder(
    column: $table.liters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get economy => $composableBuilder(
    column: $table.economy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FuelLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $FuelLogsTable> {
  $$FuelLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get liters => $composableBuilder(
    column: $table.liters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get economy => $composableBuilder(
    column: $table.economy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FuelLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FuelLogsTable> {
  $$FuelLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get fuelType =>
      $composableBuilder(column: $table.fuelType, builder: (column) => column);

  GeneratedColumn<double> get liters =>
      $composableBuilder(column: $table.liters, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<double> get economy =>
      $composableBuilder(column: $table.economy, builder: (column) => column);
}

class $$FuelLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FuelLogsTable,
          FuelLog,
          $$FuelLogsTableFilterComposer,
          $$FuelLogsTableOrderingComposer,
          $$FuelLogsTableAnnotationComposer,
          $$FuelLogsTableCreateCompanionBuilder,
          $$FuelLogsTableUpdateCompanionBuilder,
          (FuelLog, BaseReferences<_$AppDatabase, $FuelLogsTable, FuelLog>),
          FuelLog,
          PrefetchHooks Function()
        > {
  $$FuelLogsTableTableManager(_$AppDatabase db, $FuelLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FuelLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FuelLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FuelLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> fuelType = const Value.absent(),
                Value<double> liters = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<double> odometer = const Value.absent(),
                Value<double?> economy = const Value.absent(),
              }) => FuelLogsCompanion(
                id: id,
                timestamp: timestamp,
                fuelType: fuelType,
                liters: liters,
                price: price,
                odometer: odometer,
                economy: economy,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String fuelType,
                required double liters,
                required double price,
                required double odometer,
                Value<double?> economy = const Value.absent(),
              }) => FuelLogsCompanion.insert(
                id: id,
                timestamp: timestamp,
                fuelType: fuelType,
                liters: liters,
                price: price,
                odometer: odometer,
                economy: economy,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FuelLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FuelLogsTable,
      FuelLog,
      $$FuelLogsTableFilterComposer,
      $$FuelLogsTableOrderingComposer,
      $$FuelLogsTableAnnotationComposer,
      $$FuelLogsTableCreateCompanionBuilder,
      $$FuelLogsTableUpdateCompanionBuilder,
      (FuelLog, BaseReferences<_$AppDatabase, $FuelLogsTable, FuelLog>),
      FuelLog,
      PrefetchHooks Function()
    >;
typedef $$MaintenanceLogsTableCreateCompanionBuilder =
    MaintenanceLogsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String type,
      Value<String?> description,
      required double odometer,
      Value<double> cost,
    });
typedef $$MaintenanceLogsTableUpdateCompanionBuilder =
    MaintenanceLogsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> type,
      Value<String?> description,
      Value<double> odometer,
      Value<double> cost,
    });

class $$MaintenanceLogsTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceLogsTable> {
  $$MaintenanceLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MaintenanceLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceLogsTable> {
  $$MaintenanceLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MaintenanceLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceLogsTable> {
  $$MaintenanceLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);
}

class $$MaintenanceLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceLogsTable,
          MaintenanceLog,
          $$MaintenanceLogsTableFilterComposer,
          $$MaintenanceLogsTableOrderingComposer,
          $$MaintenanceLogsTableAnnotationComposer,
          $$MaintenanceLogsTableCreateCompanionBuilder,
          $$MaintenanceLogsTableUpdateCompanionBuilder,
          (
            MaintenanceLog,
            BaseReferences<
              _$AppDatabase,
              $MaintenanceLogsTable,
              MaintenanceLog
            >,
          ),
          MaintenanceLog,
          PrefetchHooks Function()
        > {
  $$MaintenanceLogsTableTableManager(
    _$AppDatabase db,
    $MaintenanceLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> odometer = const Value.absent(),
                Value<double> cost = const Value.absent(),
              }) => MaintenanceLogsCompanion(
                id: id,
                timestamp: timestamp,
                type: type,
                description: description,
                odometer: odometer,
                cost: cost,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String type,
                Value<String?> description = const Value.absent(),
                required double odometer,
                Value<double> cost = const Value.absent(),
              }) => MaintenanceLogsCompanion.insert(
                id: id,
                timestamp: timestamp,
                type: type,
                description: description,
                odometer: odometer,
                cost: cost,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MaintenanceLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceLogsTable,
      MaintenanceLog,
      $$MaintenanceLogsTableFilterComposer,
      $$MaintenanceLogsTableOrderingComposer,
      $$MaintenanceLogsTableAnnotationComposer,
      $$MaintenanceLogsTableCreateCompanionBuilder,
      $$MaintenanceLogsTableUpdateCompanionBuilder,
      (
        MaintenanceLog,
        BaseReferences<_$AppDatabase, $MaintenanceLogsTable, MaintenanceLog>,
      ),
      MaintenanceLog,
      PrefetchHooks Function()
    >;
typedef $$DtcLogsTableCreateCompanionBuilder =
    DtcLogsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String code,
      required String description,
      required String category,
      Value<bool> active,
      Value<DateTime?> resolvedTime,
    });
typedef $$DtcLogsTableUpdateCompanionBuilder =
    DtcLogsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> code,
      Value<String> description,
      Value<String> category,
      Value<bool> active,
      Value<DateTime?> resolvedTime,
    });

class $$DtcLogsTableFilterComposer
    extends Composer<_$AppDatabase, $DtcLogsTable> {
  $$DtcLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedTime => $composableBuilder(
    column: $table.resolvedTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DtcLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $DtcLogsTable> {
  $$DtcLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedTime => $composableBuilder(
    column: $table.resolvedTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DtcLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DtcLogsTable> {
  $$DtcLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedTime => $composableBuilder(
    column: $table.resolvedTime,
    builder: (column) => column,
  );
}

class $$DtcLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DtcLogsTable,
          DtcLog,
          $$DtcLogsTableFilterComposer,
          $$DtcLogsTableOrderingComposer,
          $$DtcLogsTableAnnotationComposer,
          $$DtcLogsTableCreateCompanionBuilder,
          $$DtcLogsTableUpdateCompanionBuilder,
          (DtcLog, BaseReferences<_$AppDatabase, $DtcLogsTable, DtcLog>),
          DtcLog,
          PrefetchHooks Function()
        > {
  $$DtcLogsTableTableManager(_$AppDatabase db, $DtcLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DtcLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DtcLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DtcLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime?> resolvedTime = const Value.absent(),
              }) => DtcLogsCompanion(
                id: id,
                timestamp: timestamp,
                code: code,
                description: description,
                category: category,
                active: active,
                resolvedTime: resolvedTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String code,
                required String description,
                required String category,
                Value<bool> active = const Value.absent(),
                Value<DateTime?> resolvedTime = const Value.absent(),
              }) => DtcLogsCompanion.insert(
                id: id,
                timestamp: timestamp,
                code: code,
                description: description,
                category: category,
                active: active,
                resolvedTime: resolvedTime,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DtcLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DtcLogsTable,
      DtcLog,
      $$DtcLogsTableFilterComposer,
      $$DtcLogsTableOrderingComposer,
      $$DtcLogsTableAnnotationComposer,
      $$DtcLogsTableCreateCompanionBuilder,
      $$DtcLogsTableUpdateCompanionBuilder,
      (DtcLog, BaseReferences<_$AppDatabase, $DtcLogsTable, DtcLog>),
      DtcLog,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTable,
          UserPreference,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreference,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTable,
              UserPreference
            >,
          ),
          UserPreference,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTable,
      UserPreference,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreference,
        BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>,
      ),
      UserPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripPointsTableTableManager get tripPoints =>
      $$TripPointsTableTableManager(_db, _db.tripPoints);
  $$FuelLogsTableTableManager get fuelLogs =>
      $$FuelLogsTableTableManager(_db, _db.fuelLogs);
  $$MaintenanceLogsTableTableManager get maintenanceLogs =>
      $$MaintenanceLogsTableTableManager(_db, _db.maintenanceLogs);
  $$DtcLogsTableTableManager get dtcLogs =>
      $$DtcLogsTableTableManager(_db, _db.dtcLogs);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
}

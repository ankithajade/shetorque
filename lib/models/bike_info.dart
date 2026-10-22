/// Vehicle specification and telemetry metadata model.
class BikeInfo {
  String brand;
  String model;
  String regNumber;
  String year;
  String fuelType;
  String odometer;
  String nextService;

  // Numerical properties matching Supabase bikes schema for range & service calculations
  double fuelCapacityL;
  double avgMileageKmpl;
  double odometerKm;
  double lastServiceKm;

  BikeInfo({
    this.brand = 'Royal Enfield',
    this.model = 'Hunter 350 Dapper',
    this.regNumber = 'KA 05 EQ 8824',
    this.year = '2024',
    this.fuelType = 'Petrol (E20)',
    this.odometer = '4,820 km',
    this.nextService = 'In 180 km',
    this.fuelCapacityL = 13.0,
    this.avgMileageKmpl = 35.0,
    this.odometerKm = 4820.0,
    this.lastServiceKm = 3000.0,
  });

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'regNumber': regNumber,
        'year': year,
        'fuelType': fuelType,
        'odometer': odometer,
        'nextService': nextService,
        'fuel_capacity_l': fuelCapacityL,
        'avg_mileage_kmpl': avgMileageKmpl,
        'odometer_km': odometerKm,
        'last_service_km': lastServiceKm,
      };

  factory BikeInfo.fromJson(Map<String, dynamic> json) {
    final odoNum = (json['odometer_km'] as num?)?.toDouble() ??
        _parseOdo(json['odometer'] as String?);
    final lastServ = (json['last_service_km'] as num?)?.toDouble() ?? 3000.0;
    final cap = (json['fuel_capacity_l'] as num?)?.toDouble() ?? 13.0;
    final mileage = (json['avg_mileage_kmpl'] as num?)?.toDouble() ?? 35.0;

    return BikeInfo(
      brand: (json['brand'] ?? json['make']) as String? ?? 'Royal Enfield',
      model: json['model'] as String? ?? 'Hunter 350 Dapper',
      regNumber: (json['regNumber'] ?? json['reg_number'] ?? json['plateNumber'])
              as String? ??
          'KA 05 EQ 8824',
      year: json['year']?.toString() ?? '2024',
      fuelType: json['fuelType'] as String? ?? 'Petrol (E20)',
      odometer: json['odometer'] as String? ?? '${odoNum.toStringAsFixed(0)} km',
      nextService: json['nextService'] as String? ?? 'In 180 km',
      fuelCapacityL: cap,
      avgMileageKmpl: mileage,
      odometerKm: odoNum,
      lastServiceKm: lastServ,
    );
  }

  static double _parseOdo(String? str) {
    if (str == null) return 4820.0;
    final clean = str.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 4820.0;
  }

  BikeInfo copyWith({
    String? brand,
    String? model,
    String? regNumber,
    String? year,
    String? fuelType,
    String? odometer,
    String? nextService,
    double? fuelCapacityL,
    double? avgMileageKmpl,
    double? odometerKm,
    double? lastServiceKm,
  }) {
    return BikeInfo(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      regNumber: regNumber ?? this.regNumber,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      odometer: odometer ?? this.odometer,
      nextService: nextService ?? this.nextService,
      fuelCapacityL: fuelCapacityL ?? this.fuelCapacityL,
      avgMileageKmpl: avgMileageKmpl ?? this.avgMileageKmpl,
      odometerKm: odometerKm ?? this.odometerKm,
      lastServiceKm: lastServiceKm ?? this.lastServiceKm,
    );
  }
}

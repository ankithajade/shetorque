/// Vehicle specification and telemetry metadata model.
class BikeInfo {
  String brand;
  String model;
  String regNumber;
  String year;
  String fuelType;
  String odometer;
  String nextService;

  BikeInfo({
    this.brand = 'Royal Enfield',
    this.model = 'Hunter 350 Dapper',
    this.regNumber = 'KA 05 EQ 8824',
    this.year = '2024',
    this.fuelType = 'Petrol (E20)',
    this.odometer = '4,820 km',
    this.nextService = 'In 180 km',
  });

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'regNumber': regNumber,
        'year': year,
        'fuelType': fuelType,
        'odometer': odometer,
        'nextService': nextService,
      };

  factory BikeInfo.fromJson(Map<String, dynamic> json) => BikeInfo(
        brand: (json['brand'] ?? json['make']) as String? ?? 'Royal Enfield',
        model: json['model'] as String? ?? 'Hunter 350 Dapper',
        regNumber: (json['regNumber'] ?? json['plateNumber']) as String? ??
            'KA 05 EQ 8824',
        year: json['year']?.toString() ?? '2024',
        fuelType: json['fuelType'] as String? ?? 'Petrol (E20)',
        odometer: json['odometer'] as String? ?? '4,820 km',
        nextService: json['nextService'] as String? ?? 'In 180 km',
      );

  BikeInfo copyWith({
    String? brand,
    String? model,
    String? regNumber,
    String? year,
    String? fuelType,
    String? odometer,
    String? nextService,
  }) {
    return BikeInfo(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      regNumber: regNumber ?? this.regNumber,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      odometer: odometer ?? this.odometer,
      nextService: nextService ?? this.nextService,
    );
  }
}

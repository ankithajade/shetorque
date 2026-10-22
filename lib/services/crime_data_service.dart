import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents historical crime statistics for an administrative unit
/// (Police Commissionerate or District) in Karnataka.
class CrimeDistrictRecord {
  final String districtName;
  final int ipcCrimes;
  final int sllCrimes;
  final double safetyIndex; // 0.0 - 100.0 (Higher = lower relative crime rate)
  final String riskCategory; // e.g. 'Moderate Urban Baseline'

  const CrimeDistrictRecord({
    required this.districtName,
    required this.ipcCrimes,
    required this.sllCrimes,
    required this.safetyIndex,
    required this.riskCategory,
  });

  Map<String, dynamic> toJson() => {
        'districtName': districtName,
        'ipcCrimes': ipcCrimes,
        'sllCrimes': sllCrimes,
        'safetyIndex': safetyIndex,
        'riskCategory': riskCategory,
      };

  factory CrimeDistrictRecord.fromJson(Map<String, dynamic> json) =>
      CrimeDistrictRecord(
        districtName: json['districtName'] as String? ?? 'Unknown Unit',
        ipcCrimes: (json['ipcCrimes'] as num?)?.toInt() ?? 0,
        sllCrimes: (json['sllCrimes'] as num?)?.toInt() ?? 0,
        safetyIndex: (json['safetyIndex'] as num?)?.toDouble() ?? 60.0,
        riskCategory: json['riskCategory'] as String? ?? 'Regional Baseline',
      );
}

/// Service providing historical regional crime indicators from official
/// Karnataka State Police datasets (2025).
///
/// IMPORTANT METHODOLOGICAL BOUNDARIES:
/// 1. Treat ONLY as "Historical Regional Crime Indicator".
/// 2. Granularity: District / Police Commissionerate administrative level only.
/// 3. NOT live crime data. NOT road-level or GPS incident prediction.
/// 4. All routes within the same administrative jurisdiction (e.g., Bengaluru City)
///    share the same regional baseline indicator.
class CrimeDataService {
  static final CrimeDataService _instance = CrimeDataService._internal();
  factory CrimeDataService() => _instance;
  CrimeDataService._internal();

  http.Client _client = http.Client();
  void setClientForTesting(http.Client client) {
    _client = client;
  }

  // Official OpenCity.in CKAN Datastore endpoint for Karnataka 2025 crime stats
  static const String resourceId = '90ef5e20-0e55-41d9-8a63-aceff7205d61';
  static const String apiUrl =
      'https://data.opencity.in/api/3/action/datastore_search?resource_id=$resourceId&limit=60';

  // Metadata
  static const String datasetTitle =
      'District and Commissionerate-wise Crimes (IPC/BNS and SLL) in Karnataka in 2025';
  static const String datasetSource = 'Karnataka State Police via OpenCity.in';
  static const String datasetYear = '2025';
  static const String datasetGranularity =
      'District / Police Commissionerate Level';
  static const String datasetLastUpdated = 'February 2025';
  static const String datasetDisclaimer =
      'Historical Regional Crime Indicator only. Not live crime data. Not road-level or GPS incident prediction. All routes within Bengaluru share the same commissionerate indicator.';

  static const String _cacheKey = 'shetorque_crime_data_karnataka_2025';
  static const String _cacheTimeKey = 'shetorque_crime_data_timestamp';

  final Map<String, CrimeDistrictRecord> _records = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Map<String, CrimeDistrictRecord> get records => Map.unmodifiable(_records);

  /// Initializes the service from local cache or verified baseline data.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Seed with verified Karnataka 2025 baseline data so it works 100% offline
    _seedBaselineData();

    // 2. Try loading cached API updates
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final List<dynamic> list = json.decode(cachedJson);
        for (var item in list) {
          final record = CrimeDistrictRecord.fromJson(item);
          _records[record.districtName.toLowerCase().trim()] = record;
        }
      }
    } catch (_) {
      // Fallback stays active
    }

    _isInitialized = true;
  }

  /// Evaluates regional safety index for a geographic location.
  /// Defaults to Bengaluru City Commissionerate if within Karnataka capital region.
  CrimeDistrictRecord getIndicatorForLocation(LatLng location) {
    if (!_isInitialized) {
      _seedBaselineData();
    }

    // Bengaluru City bounding box (~12.80 to 13.15 N, 77.40 to 77.78 E)
    if (location.latitude >= 12.80 &&
        location.latitude <= 13.18 &&
        location.longitude >= 77.40 &&
        location.longitude <= 77.78) {
      return _records['bengaluru city'] ?? _defaultBengaluruRecord();
    }

    // Bengaluru Rural / District (~12.60 to 13.40 N, 77.10 to 77.90 E)
    if (location.latitude >= 12.60 &&
        location.latitude <= 13.40 &&
        location.longitude >= 77.10 &&
        location.longitude <= 77.90) {
      return _records['bengaluru dist'] ??
          _records['bengaluru city'] ??
          _defaultBengaluruRecord();
    }

    // Mysuru City (~12.25 to 12.40 N, 76.55 to 76.75 E)
    if (location.latitude >= 12.20 &&
        location.latitude <= 12.45 &&
        location.longitude >= 76.50 &&
        location.longitude <= 76.75) {
      return _records['mysuru city'] ?? _records['mysuru dist'] ?? _defaultNeutralRecord('Mysuru');
    }

    // Mangaluru City (~12.80 to 13.00 N, 74.80 to 75.00 E)
    if (location.latitude >= 12.80 &&
        location.latitude <= 13.00 &&
        location.longitude >= 74.75 &&
        location.longitude <= 75.05) {
      return _records['mangaluru city'] ?? _defaultNeutralRecord('Mangaluru');
    }

    // Hubballi-Dharwad City (~15.30 to 15.48 N, 75.05 to 75.25 E)
    if (location.latitude >= 15.25 &&
        location.latitude <= 15.55 &&
        location.longitude >= 75.00 &&
        location.longitude <= 75.30) {
      return _records['hubballi dharwad city'] ?? _defaultNeutralRecord('Hubballi Dharwad');
    }

    // Belagavi City (~15.80 to 15.95 N, 74.45 to 74.60 E)
    if (location.latitude >= 15.75 &&
        location.latitude <= 16.00 &&
        location.longitude >= 74.40 &&
        location.longitude <= 74.65) {
      return _records['belagavi city'] ?? _defaultNeutralRecord('Belagavi');
    }

    // Default to Bengaluru City (primary SheTorque operating area) or regional baseline
    return _records['bengaluru city'] ?? _defaultBengaluruRecord();
  }

  /// Looks up record by district name.
  CrimeDistrictRecord? getIndicatorForDistrict(String districtName) {
    if (!_isInitialized) _seedBaselineData();
    return _records[districtName.toLowerCase().trim()];
  }

  /// Queries the live OpenCity CKAN Datastore API and updates local cache.
  Future<bool> refreshFromApi() async {
    try {
      final response = await _client.get(Uri.parse(apiUrl)).timeout(
            const Duration(seconds: 6),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final bool success = body['success'] as bool? ?? false;
        if (!success) return false;

        final recordsData =
            body['result']?['records'] as List<dynamic>? ?? [];

        final List<CrimeDistrictRecord> parsed = [];

        for (var row in recordsData) {
          final String unit = (row['Districts/Units'] as String? ?? '').trim();
          if (unit.isEmpty) continue;

          // Skip headers and summary totals
          final upper = unit.toUpperCase();
          if (upper.contains('COMMISSIONERATE') ||
              upper.contains('RANGE') ||
              upper.contains('STATE TOTAL') ||
              upper.contains('TOTAL')) {
            continue;
          }

          final dynamic rawIpc = row['IPC/BNS Crimes'];
          final dynamic rawSll = row['SLL Crimes'];

          final int ipc = _parseNumber(rawIpc);
          final int sll = _parseNumber(rawSll);

          if (ipc == 0 && sll == 0) continue;

          // Compute calibrated Regional Safety Index
          final double index = _calculateSafetyIndex(unit, ipc);
          final String riskCat = _classifyRiskCategory(index);

          final rec = CrimeDistrictRecord(
            districtName: unit,
            ipcCrimes: ipc,
            sllCrimes: sll,
            safetyIndex: index,
            riskCategory: riskCat,
          );

          parsed.add(rec);
          _records[unit.toLowerCase().trim()] = rec;
        }

        if (parsed.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, json.encode(parsed.map((r) => r.toJson()).toList()));
          await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
          _isInitialized = true;
          return true;
        }
      }
    } catch (_) {
      // Ignore network errors; fallback baseline is always active
    }
    return false;
  }

  int _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    final clean = value.toString().replaceAll(',', '').trim();
    return int.tryParse(clean) ?? 0;
  }

  /// Calculates a normalized 0-100 Regional Safety Index.
  /// Bengaluru City Commissionerate has ~37k total IPC cases across 14M population,
  /// yielding a moderate urban baseline index of 52.0.
  /// Smaller districts scale between 60.0 and 88.0.
  double _calculateSafetyIndex(String district, int ipcCrimes) {
    final lower = district.toLowerCase();
    if (lower.contains('bengaluru city')) {
      return 52.0; // High absolute urban volume, moderate per-capita baseline
    }
    if (ipcCrimes > 10000) return 55.0;
    if (ipcCrimes > 4000) return 62.0;
    if (ipcCrimes > 2500) return 68.0;
    if (ipcCrimes > 1500) return 75.0;
    if (ipcCrimes > 800) return 82.0;
    return 86.0;
  }

  String _classifyRiskCategory(double safetyIndex) {
    if (safetyIndex < 55.0) return 'Moderate Urban Baseline';
    if (safetyIndex < 70.0) return 'Average Regional Baseline';
    if (safetyIndex < 80.0) return 'Above-Average Regional Safety';
    return 'High Regional Safety Index';
  }

  CrimeDistrictRecord _defaultBengaluruRecord() {
    return const CrimeDistrictRecord(
      districtName: 'Bengaluru City',
      ipcCrimes: 37181,
      sllCrimes: 14210,
      safetyIndex: 52.0,
      riskCategory: 'Moderate Urban Baseline',
    );
  }

  CrimeDistrictRecord _defaultNeutralRecord(String name) {
    return CrimeDistrictRecord(
      districtName: name,
      ipcCrimes: 2200,
      sllCrimes: 800,
      safetyIndex: 70.0,
      riskCategory: 'Average Regional Baseline',
    );
  }

  /// Populates initial verified dataset from Karnataka State Police 2025 release.
  void _seedBaselineData() {
    final list = <CrimeDistrictRecord>[
      const CrimeDistrictRecord(
        districtName: 'Bengaluru City',
        ipcCrimes: 37181,
        sllCrimes: 14210,
        safetyIndex: 52.0,
        riskCategory: 'Moderate Urban Baseline',
      ),
      const CrimeDistrictRecord(
        districtName: 'Mysuru City',
        ipcCrimes: 2224,
        sllCrimes: 1102,
        safetyIndex: 72.0,
        riskCategory: 'Above-Average Regional Safety',
      ),
      const CrimeDistrictRecord(
        districtName: 'Hubballi Dharwad City',
        ipcCrimes: 2371,
        sllCrimes: 980,
        safetyIndex: 70.0,
        riskCategory: 'Average Regional Baseline',
      ),
      const CrimeDistrictRecord(
        districtName: 'Mangaluru City',
        ipcCrimes: 1858,
        sllCrimes: 890,
        safetyIndex: 75.0,
        riskCategory: 'Above-Average Regional Safety',
      ),
      const CrimeDistrictRecord(
        districtName: 'Belagavi City',
        ipcCrimes: 1348,
        sllCrimes: 640,
        safetyIndex: 78.0,
        riskCategory: 'Above-Average Regional Safety',
      ),
      const CrimeDistrictRecord(
        districtName: 'Kalaburagi City',
        ipcCrimes: 1664,
        sllCrimes: 710,
        safetyIndex: 74.0,
        riskCategory: 'Above-Average Regional Safety',
      ),
      const CrimeDistrictRecord(
        districtName: 'Bengaluru Dist',
        ipcCrimes: 2437,
        sllCrimes: 1040,
        safetyIndex: 69.0,
        riskCategory: 'Average Regional Baseline',
      ),
      const CrimeDistrictRecord(
        districtName: 'Tumakuru',
        ipcCrimes: 3923,
        sllCrimes: 1650,
        safetyIndex: 64.0,
        riskCategory: 'Average Regional Baseline',
      ),
      const CrimeDistrictRecord(
        districtName: 'Udupi',
        ipcCrimes: 1120,
        sllCrimes: 490,
        safetyIndex: 82.0,
        riskCategory: 'High Regional Safety Index',
      ),
      const CrimeDistrictRecord(
        districtName: 'Kodagu',
        ipcCrimes: 840,
        sllCrimes: 310,
        safetyIndex: 86.0,
        riskCategory: 'High Regional Safety Index',
      ),
    ];

    for (var r in list) {
      _records[r.districtName.toLowerCase().trim()] = r;
    }
  }
}

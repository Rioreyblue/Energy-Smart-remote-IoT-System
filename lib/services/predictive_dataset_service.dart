import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/predictive_data_model.dart';
import '../services/monitoring_dataset_service.dart';
import '../utils/app_logger.dart';
import '../constants/embedded_dataset.dart';

/// Data source type for tracking dataset origin
enum DataSourceType {
  cloud, // From Firestore (online)
  local, // From SharedPreferences (offline backup)
  embedded, // From embedded CSV (fallback)
}

/// Service for importing and managing predictive consumption datasets
class PredictiveDatasetService extends ChangeNotifier {
  static final PredictiveDatasetService _instance =
      PredictiveDatasetService._internal();
  factory PredictiveDatasetService() => _instance;
  PredictiveDatasetService._internal();

  static const String _prefKey = 'predictive_dataset';
  static const String _prefKeyDataSource = '${_prefKey}_data_source';

  // Valid appliance names (standardized)
  static const List<String> _validAppliances = [
    'appliances_001',
    'appliances_002',
    'appliances_003',
    'appliances_004',
  ];
  List<PredictiveDataModel> _dataset = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastImportDate;
  DateTime? _lastSyncTime;
  DataSourceType _currentDataSource = DataSourceType.embedded;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  Timer? _autoSyncTimer;

  // Getters
  List<PredictiveDataModel> get dataset => _dataset;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasDataset => _dataset.isNotEmpty;
  DateTime? get lastImportDate => _lastImportDate;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get datasetSize => _dataset.length;
  DataSourceType get dataSource => _currentDataSource;
  bool get isOnline => _isOnline;

  /// Refresh connectivity status (public method for UI to call)
  Future<void> refreshConnectivity() async {
    await _checkConnectivity();
    notifyListeners();
  }

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      _isOnline = results.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );

      AppLogger.d(
        '[PredictiveDatasetService] Connectivity check: $_isOnline (${results.join(", ")})',
      );
      return _isOnline;
    } catch (e) {
      AppLogger.w('[PredictiveDatasetService] Error checking connectivity: $e');
      _isOnline = false;
      return false;
    }
  }

  /// Start listening to connectivity changes
  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    final connectivity = Connectivity();

    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = results.any(
          (result) =>
              result == ConnectivityResult.mobile ||
              result == ConnectivityResult.wifi ||
              result == ConnectivityResult.ethernet,
        );

        AppLogger.d(
          '[PredictiveDatasetService] Connectivity changed: $_isOnline (${results.join(", ")})',
        );

        // If just came online and not using cloud data, attempt sync
        if (_isOnline &&
            !wasOnline &&
            _currentDataSource != DataSourceType.cloud) {
          AppLogger.i(
            '[PredictiveDatasetService] Device came online, attempting automatic sync...',
          );
          syncFromCloud().then((success) {
            if (success) {
              AppLogger.i(
                '[PredictiveDatasetService] Automatic sync successful after coming online',
              );
            }
          });
        }

        notifyListeners();
      },
      onError: (error) {
        AppLogger.e(
          '[PredictiveDatasetService] Connectivity listener error: $error',
        );
        _isOnline = false;
        notifyListeners();
      },
    );
  }

  /// Start automatic periodic sync when online
  void _startAutoSync() {
    _autoSyncTimer?.cancel();

    // Sync every 30 minutes if online and not using cloud data
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (_isOnline && _currentDataSource != DataSourceType.cloud) {
        AppLogger.d(
          '[PredictiveDatasetService] Automatic periodic sync triggered...',
        );
        syncFromCloud().then((success) {
          if (success) {
            AppLogger.i(
              '[PredictiveDatasetService] Automatic periodic sync successful',
            );
          }
        });
      }
    });
  }

  /// Initialize and load stored dataset or embedded dataset
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check connectivity first
      await _checkConnectivity();

      // Start connectivity listener
      _startConnectivityListener();

      // Start automatic sync if online
      if (_isOnline) {
        _startAutoSync();
      }

      // Try to load from cloud storage first (if online)
      if (_isOnline) {
        AppLogger.i(
          '[PredictiveDatasetService] Initializing - device is online, attempting to load from cloud...',
        );
        final loadedFromCloud = await _loadFromCloudStorage();

        if (loadedFromCloud) {
          _currentDataSource = DataSourceType.cloud;
          _lastSyncTime = DateTime.now();
          AppLogger.i(
            '[PredictiveDatasetService] Successfully loaded from cloud storage',
          );
        } else {
          // Cloud load failed, try local storage
          AppLogger.i(
            '[PredictiveDatasetService] Cloud load failed, trying local storage...',
          );
          await _loadStoredDataset();
          if (_dataset.isNotEmpty) {
            _currentDataSource = DataSourceType.local;
            AppLogger.i(
              '[PredictiveDatasetService] Successfully loaded from local storage',
            );
          } else {
            // If no stored dataset exists, load embedded dataset
            AppLogger.i(
              '[PredictiveDatasetService] No local data, loading embedded dataset...',
            );
            await loadEmbeddedDataset();
            _currentDataSource = DataSourceType.embedded;
            AppLogger.i(
              '[PredictiveDatasetService] Successfully loaded embedded dataset',
            );
          }
        }
      } else {
        // Device is offline, load from local storage or embedded
        AppLogger.i(
          '[PredictiveDatasetService] Device is offline, loading from local storage...',
        );
        await _loadStoredDataset();

        if (_dataset.isNotEmpty) {
          _currentDataSource = DataSourceType.local;
          AppLogger.i(
            '[PredictiveDatasetService] Successfully loaded from local storage (offline)',
          );
        } else {
          // If no stored dataset exists, load embedded dataset
          AppLogger.i(
            '[PredictiveDatasetService] No local data, loading embedded dataset (offline)...',
          );
          await loadEmbeddedDataset();
          _currentDataSource = DataSourceType.embedded;
          AppLogger.i(
            '[PredictiveDatasetService] Successfully loaded embedded dataset (offline)',
          );
        }
      }

      // Store data source info
      await _storeDataSourceInfo();
    } catch (e) {
      _error = 'Failed to load dataset: $e';
      AppLogger.e('[PredictiveDatasetService] Error loading dataset: $e');
      // Fallback to embedded if all else fails
      if (_dataset.isEmpty) {
        try {
          await loadEmbeddedDataset();
          _currentDataSource = DataSourceType.embedded;
        } catch (fallbackError) {
          AppLogger.e(
            '[PredictiveDatasetService] Fallback to embedded also failed: $fallbackError',
          );
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load dataset from cloud storage (Firestore monitoring_dataset/reference)
  Future<bool> _loadFromCloudStorage() async {
    // Check connectivity before attempting cloud load
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      AppLogger.w(
        '[PredictiveDatasetService] Cannot load from cloud: device is offline',
      );
      return false;
    }

    try {
      final monitoringDatasetService = MonitoringDatasetService();
      final datasetReference =
          await monitoringDatasetService.getDatasetReference();

      if (datasetReference == null) {
        AppLogger.w(
          '[PredictiveDatasetService] Cloud dataset reference does not exist',
        );
        return false;
      }

      // Check if dataset has enough data (needs at least 3 months)
      if (!datasetReference.isValid) {
        final monthCount = datasetReference.monthlyData.length;
        AppLogger.w(
          '[PredictiveDatasetService] Cloud dataset reference has only $monthCount months (need at least 3). Attempting to update...',
        );

        // Try to update the dataset reference if it's empty or has insufficient data
        final updated = await monitoringDatasetService.updateDatasetReference();
        if (updated) {
          // Retry loading after update
          final updatedReference =
              await monitoringDatasetService.getDatasetReference();
          if (updatedReference != null && updatedReference.isValid) {
            final predictiveData = updatedReference.toPredictiveDataModels();
            if (predictiveData.isNotEmpty) {
              _dataset = predictiveData;
              _lastImportDate = updatedReference.lastUpdated;
              _currentDataSource = DataSourceType.cloud;
              await _storeDataset();
              AppLogger.i(
                '[PredictiveDatasetService] Successfully loaded ${_dataset.length} records after dataset update',
              );
              return true;
            }
          }
        }

        AppLogger.w(
          '[PredictiveDatasetService] Dataset update failed or still insufficient. Using fallback data source.',
        );
        return false;
      }

      // Convert MonitoringDatasetModel to PredictiveDataModel format
      final predictiveData = datasetReference.toPredictiveDataModels();

      if (predictiveData.isNotEmpty) {
        _dataset = predictiveData;
        _lastImportDate = datasetReference.lastUpdated;
        _lastSyncTime = DateTime.now();
        _currentDataSource = DataSourceType.cloud;

        // Store to local storage for offline access
        await _storeDataset();
        AppLogger.i(
          '[PredictiveDatasetService] Loaded ${_dataset.length} records from cloud storage and cached locally',
        );
        notifyListeners();
        return true;
      }

      AppLogger.w(
        '[PredictiveDatasetService] Cloud dataset reference exists but produced no predictive data',
      );
      return false;
    } catch (e) {
      // Network errors or other exceptions - treat as offline scenario
      AppLogger.w(
        '[PredictiveDatasetService] Error loading from cloud storage (likely offline): $e',
      );
      return false;
    }
  }

  /// Load embedded dataset
  Future<void> loadEmbeddedDataset() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Parse embedded CSV
      final parsedData = _parseCsvString(EmbeddedDataset.raw);

      // Validate dataset
      final validationResult = validateDataset(parsedData);
      if (!validationResult['valid']) {
        _error = validationResult['error'] ?? 'Invalid embedded dataset';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Store dataset
      _dataset = parsedData;
      _lastImportDate = DateTime.now();
      _currentDataSource = DataSourceType.embedded;
      await _storeDataset();

      _isLoading = false;
      notifyListeners();
      AppLogger.i(
        '[PredictiveDatasetService] Embedded dataset loaded successfully: ${_dataset.length} records',
      );
    } catch (e) {
      _error = 'Failed to load embedded dataset: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      AppLogger.e(
        '[PredictiveDatasetService] Error loading embedded dataset: $e',
      );
    }
  }

  /// Parse CSV string
  List<PredictiveDataModel> _parseCsvString(String csvContent) {
    final csvConverter = const CsvToListConverter();
    final rows = csvConverter.convert(csvContent);

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // First row is headers
    final headers =
        rows[0].map((h) => h.toString().trim().toLowerCase()).toList();

    // Create column mapping
    final columnMap = <String, int>{};
    final requiredColumns = [
      'month',
      'appliance',
      'energy(kwh)',
      'energy',
      'cost',
    ];

    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      // Map common variations - support both old and new formats
      if (header.contains('month')) columnMap['Month'] = i;
      if (header.contains('appliance')) columnMap['Appliance'] = i;
      if (header.contains('voltage') || header.contains('average_voltage')) {
        columnMap['Voltage'] = i;
      }
      if (header.contains('average_voltage(v)')) {
        columnMap['Average_Voltage(V)'] = i;
      }
      if (header.contains('current') || header.contains('average_current')) {
        columnMap['Current'] = i;
      }
      if (header.contains('average_current(a)')) {
        columnMap['Average_Current(A)'] = i;
      }
      if (header.contains('power(w)') || header.contains('power')) {
        columnMap['Power'] = i;
      }
      if (header.contains('power(w)')) columnMap['Power(W)'] = i;
      if (header.contains('usage_hours') ||
          header.contains('hours_per_day') ||
          header.contains('hoursperday')) {
        columnMap['HoursPerDay'] = i;
        columnMap['Usage_Hours_per_Day'] = i;
      }
      if (header.contains('energy_consumption') ||
          header.contains('energy(kwh)') ||
          header.contains('energy')) {
        columnMap['Energy(kWh)'] = i;
        columnMap['Energy_Consumption(kWh)'] = i;
      }
      if (header.contains('power_rate') || header.contains('rate')) {
        columnMap['Rate'] = i;
        columnMap['Power_Rate(₱/kWh)'] = i;
      }
      if (header.contains('estimated_monthly_cost') ||
          header.contains('cost')) {
        columnMap['Cost'] = i;
        columnMap['Estimated_Monthly_Cost(₱)'] = i;
      }
    }

    // Validate required columns
    final missingColumns =
        requiredColumns.where((col) {
          return !columnMap.keys.any((key) => key.contains(col.toLowerCase()));
        }).toList();

    if (missingColumns.isNotEmpty) {
      throw Exception(
        'Missing required columns: ${missingColumns.join(", ")}. Found columns: ${headers.join(", ")}',
      );
    }

    // Parse data rows with appliance name normalization
    final dataset = <PredictiveDataModel>[];
    for (int i = 1; i < rows.length; i++) {
      try {
        var model = PredictiveDataModel.fromCsv(rows[i], columnMap);

        // Normalize appliance name: convert "appliance_XXX" to "appliances_XXX"
        if (model.appliance.startsWith('appliance_') &&
            !model.appliance.startsWith('appliances_')) {
          final normalizedAppliance = model.appliance.replaceFirst(
            'appliance_',
            'appliances_',
          );
          model = model.copyWith(appliance: normalizedAppliance);
        }

        if (model.isValid()) {
          dataset.add(model);
        }
      } catch (e) {
        AppLogger.w('[PredictiveDatasetService] Skipping invalid row $i: $e');
      }
    }

    return dataset;
  }

  /// Validate dataset
  Map<String, dynamic> validateDataset(List<PredictiveDataModel> dataset) {
    if (dataset.isEmpty) {
      return {'valid': false, 'error': 'Dataset is empty'};
    }

    // Check for required fields
    final invalidRecords = dataset.where((d) => !d.isValid()).toList();
    if (invalidRecords.isNotEmpty) {
      return {
        'valid': false,
        'error':
            'Dataset contains ${invalidRecords.length} invalid records. Please check your data.',
      };
    }

    // Validate appliance names (must match standardized format)
    // Accept both "appliance_XXX" and "appliances_XXX" formats
    final normalizedDataset =
        dataset.map((d) {
          if (d.appliance.startsWith('appliance_') &&
              !d.appliance.startsWith('appliances_')) {
            return d.copyWith(
              appliance: d.appliance.replaceFirst('appliance_', 'appliances_'),
            );
          }
          return d;
        }).toList();

    final invalidAppliances =
        normalizedDataset
            .where((d) => !_validAppliances.contains(d.appliance))
            .map((d) => d.appliance)
            .toSet()
            .toList();

    if (invalidAppliances.isNotEmpty) {
      return {
        'valid': false,
        'error':
            'Invalid appliance names found: ${invalidAppliances.join(", ")}. '
            'Valid appliance names must be: ${_validAppliances.join(", ")}',
      };
    }

    // Check minimum data points
    if (dataset.length < 3) {
      return {
        'valid': false,
        'error': 'Dataset must contain at least 3 data points for predictions',
      };
    }

    return {'valid': true};
  }

  /// Get stored dataset from SharedPreferences
  Future<void> _loadStoredDataset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datasetJson = prefs.getString(_prefKey);

      if (datasetJson != null && datasetJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(datasetJson);
        _dataset =
            jsonList
                .map(
                  (json) => PredictiveDataModel.fromJson(
                    json as Map<String, dynamic>,
                  ),
                )
                .toList();

        final lastImportStr = prefs.getString('${_prefKey}_last_import');
        if (lastImportStr != null) {
          _lastImportDate = DateTime.parse(lastImportStr);
        }

        // Restore data source info
        final dataSourceStr = prefs.getString(_prefKeyDataSource);
        if (dataSourceStr != null) {
          _currentDataSource = DataSourceType.values.firstWhere(
            (e) => e.toString() == dataSourceStr,
            orElse: () => DataSourceType.local,
          );
        } else {
          _currentDataSource = DataSourceType.local;
        }

        AppLogger.i(
          '[PredictiveDatasetService] Loaded ${_dataset.length} records from local storage (source: $_currentDataSource)',
        );
      }
    } catch (e) {
      AppLogger.e(
        '[PredictiveDatasetService] Error loading stored dataset: $e',
      );
      _dataset = [];
    }
  }

  /// Store data source info to SharedPreferences
  Future<void> _storeDataSourceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDataSource, _currentDataSource.toString());
    } catch (e) {
      AppLogger.e(
        '[PredictiveDatasetService] Error storing data source info: $e',
      );
    }
  }

  /// Store dataset to SharedPreferences
  Future<void> _storeDataset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _dataset.map((d) => d.toMap()).toList();
      await prefs.setString(_prefKey, jsonEncode(jsonList));

      if (_lastImportDate != null) {
        await prefs.setString(
          '${_prefKey}_last_import',
          _lastImportDate!.toIso8601String(),
        );
      }

      // Store data source info
      await _storeDataSourceInfo();

      AppLogger.i(
        '[PredictiveDatasetService] Dataset stored successfully to local storage',
      );
    } catch (e) {
      AppLogger.e('[PredictiveDatasetService] Error storing dataset: $e');
    }
  }

  /// Get stored dataset (public method)
  Future<List<PredictiveDataModel>> getStoredDataset() async {
    await _loadStoredDataset();
    return _dataset;
  }

  /// Clear dataset
  Future<void> clearDataset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      await prefs.remove('${_prefKey}_last_import');

      _dataset = [];
      _lastImportDate = null;
      notifyListeners();

      AppLogger.i('[PredictiveDatasetService] Dataset cleared');
    } catch (e) {
      AppLogger.e('[PredictiveDatasetService] Error clearing dataset: $e');
    }
  }

  /// Get unique appliances from dataset
  List<String> getUniqueAppliances() {
    final appliances = _dataset.map((d) => d.appliance).toSet().toList();
    appliances.sort();
    return appliances;
  }

  /// Get data grouped by appliance
  Map<String, List<PredictiveDataModel>> getDataByAppliance() {
    final grouped = <String, List<PredictiveDataModel>>{};
    for (final data in _dataset) {
      grouped.putIfAbsent(data.appliance, () => []).add(data);
    }
    return grouped;
  }

  /// Get data grouped by month
  Map<String, List<PredictiveDataModel>> getDataByMonth() {
    final grouped = <String, List<PredictiveDataModel>>{};
    for (final data in _dataset) {
      grouped.putIfAbsent(data.month, () => []).add(data);
    }
    return grouped;
  }

  /// Load dataset from cloud storage (public method)
  Future<bool> loadFromCloudStorage() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _loadFromCloudStorage();

      if (success) {
        // Data already stored in _loadFromCloudStorage
        _currentDataSource = DataSourceType.cloud;
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to load from cloud storage: $e';
      _isLoading = false;
      notifyListeners();
      AppLogger.e(
        '[PredictiveDatasetService] Error loading from cloud storage: $e',
      );
      return false;
    }
  }

  /// Sync dataset from cloud storage (manual sync)
  Future<bool> syncFromCloud() async {
    // Check connectivity before attempting sync
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      AppLogger.w('[PredictiveDatasetService] Cannot sync: device is offline');
      _error = 'Device is offline. Please check your internet connection.';
      notifyListeners();
      return false;
    }

    AppLogger.i('[PredictiveDatasetService] Sync from cloud initiated...');
    final success = await loadFromCloudStorage();

    if (success) {
      _lastSyncTime = DateTime.now();
      // Start auto sync if not already running
      if (_autoSyncTimer == null || !_autoSyncTimer!.isActive) {
        _startAutoSync();
      }
    }

    return success;
  }

  /// Refresh dataset from cloud storage (alias for syncFromCloud)
  Future<void> refreshFromCloud() async {
    await syncFromCloud();
  }

  /// Get data source information
  Map<String, dynamic> getDataSourceInfo() {
    String sourceName;
    String sourceDescription;

    switch (_currentDataSource) {
      case DataSourceType.cloud:
        sourceName = 'Cloud';
        sourceDescription = 'Synced from Firestore';
        break;
      case DataSourceType.local:
        sourceName = 'Local';
        sourceDescription = 'Offline backup';
        break;
      case DataSourceType.embedded:
        sourceName = 'Embedded';
        sourceDescription = 'Default fallback';
        break;
    }

    return {
      'type': _currentDataSource,
      'name': sourceName,
      'description': sourceDescription,
      'isOnline': _isOnline,
      'lastImportDate': _lastImportDate,
      'lastSyncTime': _lastSyncTime,
      'datasetSize': _dataset.length,
    };
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}

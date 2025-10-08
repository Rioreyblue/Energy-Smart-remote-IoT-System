import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appliance_model.dart';
import '../services/appliance_service.dart';
import '../services/energy_overview_service.dart';

class HomeController extends ChangeNotifier {
  final ApplianceService _applianceService = ApplianceService();
  final EnergyOverviewService _energyOverviewService = EnergyOverviewService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  List<ApplianceModel> _appliances = [];
  Map<String, dynamic> _energyOverviewData = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ApplianceModel> get appliances => _appliances;
  Map<String, dynamic> get energyOverviewData => _energyOverviewData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Initialize controller
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Check if user is authenticated
      if (currentUser == null) {
        _setError('User not authenticated');
        return;
      }

      // Check if monthly reset is needed
      final needsReset = await _energyOverviewService.checkMonthlyReset();
      if (needsReset) {
        await _energyOverviewService.initializeMonthlyData();
        await _applianceService.resetMonthlyData();
      }

      // Initialize default appliances if none exist
      final existingAppliances = await _applianceService.getAppliances();
      if (existingAppliances.isEmpty) {
        await _applianceService.initializeDefaultAppliances();
      }

      // Load initial data
      await _loadAppliances();
      await _loadEnergyOverviewData();
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load appliances
  Future<void> _loadAppliances() async {
    try {
      _appliances = await _applianceService.getAppliances();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load appliances: $e');
    }
  }

  // Load energy overview data
  Future<void> _loadEnergyOverviewData() async {
    try {
      _energyOverviewData =
          await _energyOverviewService.getEnergyOverviewData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load energy data: $e');
    }
  }

  // Toggle appliance
  Future<void> toggleAppliance(String applianceUid, bool isOn) async {
    try {
      final success = await _applianceService.toggleAppliance(
        applianceUid,
        isOn,
      );
      if (success) {
        // Update local state
        final index = _appliances.indexWhere((app) => app.uid == applianceUid);
        if (index != -1) {
          _appliances[index] = _appliances[index].copyWith(isOn: isOn);
          notifyListeners();
        }

        // Reload energy overview data
        await _loadEnergyOverviewData();
      } else {
        _setError('Failed to toggle appliance');
      }
    } catch (e) {
      _setError('Failed to toggle appliance: $e');
    }
  }

  // Update appliance
  Future<void> updateAppliance(
    String applianceUid,
    Map<String, dynamic> updates,
  ) async {
    try {
      final success = await _applianceService.updateAppliance(
        applianceUid,
        updates,
      );
      if (success) {
        await _loadAppliances();
      } else {
        _setError('Failed to update appliance');
      }
    } catch (e) {
      _setError('Failed to update appliance: $e');
    }
  }

  // Add appliance
  Future<void> addAppliance(ApplianceModel appliance) async {
    try {
      final success = await _applianceService.addAppliance(appliance);
      if (success) {
        await _loadAppliances();
      } else {
        _setError('Failed to add appliance');
      }
    } catch (e) {
      _setError('Failed to add appliance: $e');
    }
  }

  // Remove appliance
  Future<void> removeAppliance(String applianceUid) async {
    try {
      final success = await _applianceService.removeAppliance(applianceUid);
      if (success) {
        await _loadAppliances();
        await _loadEnergyOverviewData();
      } else {
        _setError('Failed to remove appliance');
      }
    } catch (e) {
      _setError('Failed to remove appliance: $e');
    }
  }

  // Set target cost
  Future<void> setTargetCost(double targetCost) async {
    try {
      final success = await _applianceService.setTargetCost(targetCost);
      if (success) {
        await _loadEnergyOverviewData();
      } else {
        _setError('Failed to set target cost');
      }
    } catch (e) {
      _setError('Failed to set target cost: $e');
    }
  }

  // Refresh data
  Future<void> refresh() async {
    await _loadAppliances();
    await _loadEnergyOverviewData();
  }

  // Get appliances stream
  Stream<List<ApplianceModel>> getAppliancesStream() {
    return _applianceService.getAppliancesStream();
  }

  // Get energy overview data stream
  Stream<Map<String, dynamic>> getEnergyOverviewDataStream() {
    return _energyOverviewService.getEnergyOverviewDataStream();
  }

  // Get current usage
  double getCurrentUsage() {
    return _energyOverviewData['currentUsage'] ?? 0.0;
  }

  // Get conversion value
  double getConversionValue() {
    return _energyOverviewData['conversionValue'] ?? 0.0;
  }

  // Get today's cost
  double getTodaysCost() {
    return _energyOverviewData['todaysCost'] ?? 0.0;
  }

  // Get target cost
  double getTargetCost() {
    return _energyOverviewData['targetCost'] ?? 0.0;
  }

  // Get this month's consumption
  double getThisMonthConsumption() {
    return _energyOverviewData['thisMonth'] ?? 0.0;
  }

  // Format currency
  String formatCurrency(double value) {
    return _energyOverviewService.formatCurrency(value);
  }

  // Format kWh
  String formatKwh(double value) {
    return _energyOverviewService.formatKwh(value);
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    super.dispose();
  }
}


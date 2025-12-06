import '../models/predictive_data_model.dart';
import '../models/prediction_result_model.dart';

class MonitoringPrediction {
  // Returns a tuple: (predicted, previous) - Legacy method for backward compatibility
  static Map<String, double> predictNextPeriodLegacy(List<double> historical) {
    if (historical.isEmpty) return {'predicted': 0, 'previous': 0};
    final previous = historical.last;
    final predicted =
        historical.length > 1
            ? historical.reduce((a, b) => a + b) / historical.length
            : previous;
    return {'predicted': predicted, 'previous': previous};
  }

  /// Predict next period's consumption using weighted moving average with trend analysis
  /// period: 'Day', 'Week', or 'Month'
  /// Returns PredictionResultModel with predicted kWh, cost, and confidence
  static PredictionResultModel predictNextPeriod({
    required List<PredictiveDataModel> dataset,
    required String period, // 'Day', 'Week', or 'Month'
    double minRate = 10.0,
    double maxRate = 14.0,
    double?
    powerRate, // Optional: if provided, use this rate instead of calculating from dataset
  }) {
    // For Day and Week, we need to scale monthly data appropriately
    final scaleFactor = _getPeriodScaleFactor(period);

    if (dataset.isEmpty) {
      return PredictionResultModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        month: _getNextPeriodLabel(period),
        predictedKwh: 0,
        predictedCost: 0,
        confidence: 0,
        consumptionLevel: 'average',
        timestamp: DateTime.now(),
      );
    }

    // Group by appliance and calculate per-appliance predictions
    final applianceBreakdown = <String, double>{};
    final applianceCostBreakdown = <String, double>{};
    final applianceGroups = <String, List<PredictiveDataModel>>{};

    for (final data in dataset) {
      applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
    }

    double totalPredictedKwh = 0;

    // Predict for each appliance (from monthly data)
    for (final entry in applianceGroups.entries) {
      final appliance = entry.key;
      final values = entry.value.map((d) => d.energyKwh).toList();
      final predictedMonthly = _weightedMovingAverageWithTrend(values);
      // Scale down for Day/Week
      final predicted = predictedMonthly * scaleFactor;
      applianceBreakdown[appliance] = predicted;
      totalPredictedKwh += predicted;
    }

    // Calculate average rate from dataset or use provided rate or range
    double finalRate;
    if (powerRate != null && powerRate > 0) {
      finalRate = powerRate;
    } else {
      final avgRate = _calculateAverageRate(dataset);
      finalRate = avgRate > 0 ? avgRate : (minRate + maxRate) / 2;
    }

    // Calculate cost per appliance
    for (final entry in applianceBreakdown.entries) {
      final appliance = entry.key;
      final predictedKwh = entry.value;
      final predictedCost = predictedKwh * finalRate;
      applianceCostBreakdown[appliance] = predictedCost;
    }

    final predictedCost = totalPredictedKwh * finalRate;

    // Calculate confidence based on data variance and amount
    final confidence = _calculateConfidence(dataset);

    // Classify consumption level (using scaled prediction)
    final consumptionLevel = classifyConsumptionLevel(
      dataset,
      totalPredictedKwh /
          scaleFactor, // Use monthly equivalent for classification
    );

    return PredictionResultModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      month: _getNextPeriodLabel(period),
      predictedKwh: totalPredictedKwh,
      predictedCost: predictedCost,
      confidence: confidence,
      consumptionLevel: consumptionLevel,
      applianceBreakdown: applianceBreakdown,
      applianceCostBreakdown: applianceCostBreakdown,
      timestamp: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  /// Predict next month's consumption using weighted moving average with trend analysis
  /// Returns PredictionResultModel with predicted kWh, cost, and confidence
  static PredictionResultModel predictNextMonth({
    required List<PredictiveDataModel> dataset,
    double minRate = 10.0,
    double maxRate = 14.0,
    double?
    powerRate, // Optional: if provided, use this rate instead of calculating from dataset
  }) {
    return predictNextPeriod(
      dataset: dataset,
      period: 'Month',
      minRate: minRate,
      maxRate: maxRate,
      powerRate: powerRate,
    );
  }

  /// Predict consumption by appliance
  static Map<String, double> predictByAppliance(
    List<PredictiveDataModel> dataset,
  ) {
    final applianceGroups = <String, List<PredictiveDataModel>>{};
    final predictions = <String, double>{};

    for (final data in dataset) {
      applianceGroups.putIfAbsent(data.appliance, () => []).add(data);
    }

    for (final entry in applianceGroups.entries) {
      final values = entry.value.map((d) => d.energyKwh).toList();
      predictions[entry.key] = _weightedMovingAverageWithTrend(values);
    }

    return predictions;
  }

  /// Calculate prediction confidence (0-100) based on data variance and amount
  static double calculateConfidence(List<PredictiveDataModel> dataset) {
    if (dataset.length < 2) return 30.0; // Low confidence for insufficient data

    final values = dataset.map((d) => d.energyKwh).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = variance > 0 ? variance : 0.0;
    final coefficientOfVariation = mean > 0 ? (stdDev / mean) * 100 : 100;

    // Confidence factors:
    // - More data = higher confidence (up to 50 points)
    // - Lower variance = higher confidence
    final dataAmountFactor = (dataset.length / 50.0).clamp(0.0, 1.0) * 40;
    final varianceFactor =
        (1 - (coefficientOfVariation / 100).clamp(0.0, 1.0)) * 60;

    return (dataAmountFactor + varianceFactor).clamp(0.0, 100.0);
  }

  /// Identify trends (increasing, decreasing, stable)
  static String identifyTrends(List<PredictiveDataModel> dataset) {
    if (dataset.length < 3) return 'insufficient_data';

    // Sort by month and get energy values
    final sorted = List<PredictiveDataModel>.from(dataset)
      ..sort((a, b) => a.month.compareTo(b.month));

    final recent =
        sorted
            .take((sorted.length * 0.4).ceil())
            .map((d) => d.energyKwh)
            .toList();
    final older =
        sorted
            .skip(sorted.length - (sorted.length * 0.4).ceil())
            .map((d) => d.energyKwh)
            .toList();

    if (recent.isEmpty || older.isEmpty) return 'stable';

    final avgRecent = recent.reduce((a, b) => a + b) / recent.length;
    final avgOlder = older.reduce((a, b) => a + b) / older.length;

    if (avgRecent > avgOlder * 1.1) return 'increasing';
    if (avgRecent < avgOlder * 0.9) return 'decreasing';
    return 'stable';
  }

  /// Forecast cost with rate range
  static Map<String, double> forecastCost({
    required double predictedKwh,
    double minRate = 10.0,
    double maxRate = 14.0,
  }) {
    return {
      'minCost': predictedKwh * minRate,
      'maxCost': predictedKwh * maxRate,
      'avgCost': predictedKwh * ((minRate + maxRate) / 2),
    };
  }

  /// Weighted moving average with trend analysis
  static double _weightedMovingAverageWithTrend(List<double> values) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return values.first;

    // Simple moving average as fallback
    if (values.length < 3) {
      return values.reduce((a, b) => a + b) / values.length;
    }

    // Weighted moving average (more weight to recent values)
    double weightedSum = 0;
    double weightSum = 0;

    for (int i = 0; i < values.length; i++) {
      final weight = i + 1; // Linear weighting
      weightedSum += values[i] * weight;
      weightSum += weight;
    }

    final weightedAvg = weightedSum / weightSum;

    // Simple trend detection (linear regression)
    double trend = 0;
    if (values.length >= 3) {
      final recent = values.take(3).toList();
      final older = values.skip(values.length - 3).take(3).toList();
      final avgRecent = recent.reduce((a, b) => a + b) / recent.length;
      final avgOlder = older.reduce((a, b) => a + b) / older.length;
      trend = (avgRecent - avgOlder) * 0.3; // Apply 30% of trend
    }

    return (weightedAvg + trend).clamp(0.0, double.infinity);
  }

  /// Calculate average rate from dataset
  static double _calculateAverageRate(List<PredictiveDataModel> dataset) {
    if (dataset.isEmpty) return 0.0;
    final rates = dataset.where((d) => d.rate > 0).map((d) => d.rate).toList();
    if (rates.isEmpty) return 0.0;
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  /// Get scale factor to convert monthly prediction to day/week
  static double _getPeriodScaleFactor(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 1.0 / 30.0; // Average days per month
      case 'week':
        return 1.0 / 4.33; // Average weeks per month
      case 'month':
      default:
        return 1.0;
    }
  }

  /// Get label for next period
  static String _getNextPeriodLabel(String period) {
    final now = DateTime.now();
    switch (period.toLowerCase()) {
      case 'day':
        final tomorrow = now.add(const Duration(days: 1));
        return 'Tomorrow (${_formatDate(tomorrow)})';
      case 'week':
        final nextWeek = now.add(const Duration(days: 7));
        return 'Next Week (${_formatDate(nextWeek)})';
      case 'month':
      default:
        return _getNextMonth();
    }
  }

  /// Format date for display
  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get next month string (e.g., "January 2025")
  static String _getNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[nextMonth.month - 1]} ${nextMonth.year}';
  }

  /// Enhanced confidence calculation for dataset
  static double _calculateConfidence(List<PredictiveDataModel> dataset) {
    return calculateConfidence(dataset);
  }

  /// Classify consumption level using weighted combination of three methods
  /// Returns 'low', 'average', or 'high'
  static String classifyConsumptionLevel(
    List<PredictiveDataModel> dataset,
    double predictedKwh,
  ) {
    if (dataset.isEmpty || predictedKwh <= 0) return 'average';

    // Method 1: Percentile-based (weight: 0.5)
    final percentileScore = _getPercentileScore(dataset, predictedKwh);

    // Method 2: Historical comparison (weight: 0.3)
    final historicalScore = _getHistoricalComparisonScore(
      dataset,
      predictedKwh,
    );

    // Method 3: Industry benchmarks (weight: 0.2)
    final benchmarkScore = _getIndustryBenchmarkScore(dataset, predictedKwh);

    // Weighted combination
    final finalScore =
        (percentileScore * 0.5) +
        (historicalScore * 0.3) +
        (benchmarkScore * 0.2);

    // Classify based on weighted score
    // Thresholds: < -0.4 = low, -0.4 to 0.4 = average, > 0.4 = high
    if (finalScore < -0.4) {
      return 'low';
    } else if (finalScore > 0.4) {
      return 'high';
    } else {
      return 'average';
    }
  }

  /// Percentile-based classification score (-1 for low, 0 for average, 1 for high)
  static double _getPercentileScore(
    List<PredictiveDataModel> dataset,
    double predictedKwh,
  ) {
    if (dataset.isEmpty) return 0.0;

    final values = dataset.map((d) => d.energyKwh).toList()..sort();
    if (values.isEmpty) return 0.0;

    final percentile33 = values[(values.length * 0.33).floor()];
    final percentile67 = values[(values.length * 0.67).floor()];

    if (predictedKwh < percentile33) {
      return -1.0; // Low
    } else if (predictedKwh > percentile67) {
      return 1.0; // High
    } else {
      return 0.0; // Average
    }
  }

  /// Historical comparison score (-1 for low, 0 for average, 1 for high)
  static double _getHistoricalComparisonScore(
    List<PredictiveDataModel> dataset,
    double predictedKwh,
  ) {
    final historicalAvg = calculateHistoricalAverage(dataset);
    if (historicalAvg <= 0) return 0.0;

    final ratio = predictedKwh / historicalAvg;

    if (ratio < 0.85) {
      return -1.0; // Low (15% below average)
    } else if (ratio > 1.15) {
      return 1.0; // High (15% above average)
    } else {
      return 0.0; // Average
    }
  }

  /// Industry benchmark score (-1 for low, 0 for average, 1 for high)
  static double _getIndustryBenchmarkScore(
    List<PredictiveDataModel> dataset,
    double predictedKwh,
  ) {
    final benchmarks = getIndustryBenchmarks(dataset);
    final lowThreshold = benchmarks['low'] ?? 50.0;
    final highThreshold = benchmarks['high'] ?? 150.0;

    if (predictedKwh < lowThreshold) {
      return -1.0; // Low
    } else if (predictedKwh > highThreshold) {
      return 1.0; // High
    } else {
      return 0.0; // Average
    }
  }

  /// Calculate historical average from dataset
  static double calculateHistoricalAverage(List<PredictiveDataModel> dataset) {
    if (dataset.isEmpty) return 0.0;
    final values = dataset.map((d) => d.energyKwh).toList();
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Get industry benchmarks (configurable per dataset)
  /// Returns a map with 'low' and 'high' thresholds
  static Map<String, double> getIndustryBenchmarks(
    List<PredictiveDataModel> dataset,
  ) {
    if (dataset.isEmpty) {
      // Default industry benchmarks
      return {'low': 50.0, 'high': 150.0};
    }

    // Calculate benchmarks from dataset statistics
    final values = dataset.map((d) => d.energyKwh).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = variance > 0 ? variance : 0.0;

    // Use mean ± 0.5 stdDev as thresholds
    final lowThreshold = (mean - (stdDev * 0.5)).clamp(0.0, double.infinity);
    final highThreshold = mean + (stdDev * 0.5);

    return {'low': lowThreshold, 'high': highThreshold};
  }
}

class MonitoringPrediction {
  // Returns a tuple: (predicted, previous)
  static Map<String, double> predictNextPeriod(List<double> historical) {
    if (historical.isEmpty) return {'predicted': 0, 'previous': 0};
    final previous = historical.last;
    final predicted =
        historical.length > 1
            ? historical.reduce((a, b) => a + b) / historical.length
            : previous;
    return {'predicted': predicted, 'previous': previous};
  }
}

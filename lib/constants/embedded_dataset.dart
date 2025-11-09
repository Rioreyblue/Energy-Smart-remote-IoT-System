/// Embedded prediction dataset for AI consumption prediction feature
/// This dataset contains exactly 3 months of appliance energy consumption data
/// All 4 appliances (appliances_001 through appliances_004) are included for each month
class EmbeddedDataset {
  static const String csvData = '''
Month,Appliance,Average_Voltage(V),Average_Current(A),Power(W),Usage_Hours_per_Day,Energy_Consumption(kWh),Power_Rate(₱/kWh),Estimated_Monthly_Cost(₱)
2025-08,appliances_001,224.98,0.044,10,8,2.4,12.47,29.92
2025-08,appliances_002,229.54,0.044,10,8,2.4,13.95,33.49
2025-08,appliances_003,239.43,0.063,15,3,1.35,12.8,17.29
2025-08,appliances_004,234.52,0.277,65,8,15.6,13.36,208.43
2025-09,appliances_001,227.56,0.044,10,8,2.4,10.33,24.8
2025-09,appliances_002,236.31,0.042,10,8,2.4,10.49,25.18
2025-09,appliances_003,235.8,0.064,15,3,1.35,11.78,15.9
2025-09,appliances_004,221.6,0.293,65,8,15.6,11.52,179.65
2025-10,appliances_001,227.83,0.044,10,8,2.4,10.56,25.34
2025-10,appliances_002,239.21,0.042,10,8,2.4,10.08,24.2
2025-10,appliances_003,232.01,0.065,15,3,1.35,10.93,14.75
2025-10,appliances_004,239.98,0.271,65,8,15.6,13.01,202.97
''';

  /// Get the embedded dataset as a raw CSV string
  static String get raw => csvData.trim();
}

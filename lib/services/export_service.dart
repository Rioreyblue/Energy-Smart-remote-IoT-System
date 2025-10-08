import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:exercise_app/models/goals_model.dart';

/// Abstract base class for export functionality
abstract class ExportStrategy {
  Future<String> export(List<MeterReadingModel> data, String fileName);
}

/// CSV Export Strategy
class CSVExportStrategy implements ExportStrategy {
  @override
  Future<String> export(List<MeterReadingModel> data, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.csv');

    final csvContent = _generateCSVContent(data);
    await file.writeAsString(csvContent);

    return file.path;
  }

  String _generateCSVContent(List<MeterReadingModel> data) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
      'Date Range,Previous Reading (kWh),Present Reading (kWh),Consumption (kWh),Rate (₱/kWh),Estimated Bill (₱),Created At',
    );

    // CSV Data
    for (final reading in data) {
      buffer.writeln(
        [
          '${reading.startDate.day}/${reading.startDate.month}/${reading.startDate.year} - ${reading.endDate.day}/${reading.endDate.month}/${reading.endDate.year}',
          reading.previousReading.toStringAsFixed(2),
          reading.presentReading.toStringAsFixed(2),
          reading.consumption.toStringAsFixed(2),
          reading.ratePerKwh.toStringAsFixed(2),
          reading.estimatedBill.toStringAsFixed(2),
          '${reading.createdAt.day}/${reading.createdAt.month}/${reading.createdAt.year}',
        ].join(','),
      );
    }

    return buffer.toString();
  }
}

/// PDF Export Strategy
class PDFExportStrategy implements ExportStrategy {
  @override
  Future<String> export(List<MeterReadingModel> data, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.pdf');

    // For now, create a simple text-based PDF
    // In a real implementation, you would use a PDF library like pdf package
    final pdfContent = _generatePDFContent(data);
    await file.writeAsString(pdfContent);

    return file.path;
  }

  String _generatePDFContent(List<MeterReadingModel> data) {
    final buffer = StringBuffer();

    buffer.writeln('ENERGY SMART - USAGE REPORT');
    buffer.writeln(
      'Generated on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
    );
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (int i = 0; i < data.length; i++) {
      final reading = data[i];
      buffer.writeln('Reading #${i + 1}');
      buffer.writeln(
        'Date Range: ${reading.startDate.day}/${reading.startDate.month}/${reading.startDate.year} - ${reading.endDate.day}/${reading.endDate.month}/${reading.endDate.year}',
      );
      buffer.writeln(
        'Previous Reading: ${reading.previousReading.toStringAsFixed(2)} kWh',
      );
      buffer.writeln(
        'Present Reading: ${reading.presentReading.toStringAsFixed(2)} kWh',
      );
      buffer.writeln(
        'Consumption: ${reading.consumption.toStringAsFixed(2)} kWh',
      );
      buffer.writeln('Rate: ₱${reading.ratePerKwh.toStringAsFixed(2)}/kWh');
      buffer.writeln(
        'Estimated Bill: ₱${reading.estimatedBill.toStringAsFixed(2)}',
      );
      buffer.writeln(
        'Created: ${reading.createdAt.day}/${reading.createdAt.month}/${reading.createdAt.year}',
      );
      buffer.writeln('-' * 30);
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Export Service using Strategy Pattern
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export data using specified strategy
  Future<ExportResult> exportData({
    required List<MeterReadingModel> data,
    required ExportFormat format,
    required String fileName,
  }) async {
    try {
      ExportStrategy strategy;

      switch (format) {
        case ExportFormat.csv:
          strategy = CSVExportStrategy();
          break;
        case ExportFormat.pdf:
          strategy = PDFExportStrategy();
          break;
      }

      final filePath = await strategy.export(data, fileName);

      return ExportResult(
        success: true,
        filePath: filePath,
        message: 'Data exported successfully as ${format.name.toUpperCase()}',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: null,
        message: 'Export failed: $e',
      );
    }
  }

  /// Get available export formats
  List<ExportFormat> getAvailableFormats() {
    return ExportFormat.values;
  }

  /// Validate export data
  bool validateExportData(List<MeterReadingModel> data) {
    return data.isNotEmpty;
  }

  /// Get export statistics
  ExportStatistics getExportStatistics(List<MeterReadingModel> data) {
    if (data.isEmpty) {
      return ExportStatistics(
        totalReadings: 0,
        totalConsumption: 0.0,
        totalBill: 0.0,
        averageConsumption: 0.0,
        dateRange: 'No data',
      );
    }

    final totalConsumption = data.fold(
      0.0,
      (sum, reading) => sum + reading.consumption,
    );
    final totalBill = data.fold(
      0.0,
      (sum, reading) => sum + reading.estimatedBill,
    );
    final averageConsumption = totalConsumption / data.length;

    final startDate = data
        .map((r) => r.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final endDate = data
        .map((r) => r.endDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final dateRange =
        '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}';

    return ExportStatistics(
      totalReadings: data.length,
      totalConsumption: totalConsumption,
      totalBill: totalBill,
      averageConsumption: averageConsumption,
      dateRange: dateRange,
    );
  }
}

/// Export format enumeration
enum ExportFormat { csv, pdf }

/// Export result model
class ExportResult {
  final bool success;
  final String? filePath;
  final String message;

  const ExportResult({
    required this.success,
    this.filePath,
    required this.message,
  });
}

/// Export statistics model
class ExportStatistics {
  final int totalReadings;
  final double totalConsumption;
  final double totalBill;
  final double averageConsumption;
  final String dateRange;

  const ExportStatistics({
    required this.totalReadings,
    required this.totalConsumption,
    required this.totalBill,
    required this.averageConsumption,
    required this.dateRange,
  });
}

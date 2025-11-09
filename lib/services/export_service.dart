import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:exercise_app/models/goals_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/permission_helper.dart';
import '../utils/app_logger.dart';
import 'package:intl/intl.dart';

/// Abstract base class for export functionality
abstract class ExportStrategy {
  Future<String> export(List<MeterReadingModel> data, String fileName);
}

/// CSV Export Strategy
class CSVExportStrategy implements ExportStrategy {
  @override
  Future<String> export(List<MeterReadingModel> data, String fileName) async {
    // Request permissions first
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      throw Exception(
        'Storage permission denied. Please grant permission to export files.',
      );
    }

    // Get Downloads directory
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      // Try common Downloads folder paths
      final possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          downloadsDir = dir;
          break;
        }
      }

      // If none exist, try to construct from external storage directory
      if (downloadsDir == null) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final parts = externalDir.path.split('/');
          if (parts.length >= 4) {
            // Navigate to root and then to Download
            final rootPath = parts.sublist(0, 4).join('/');
            downloadsDir = Directory('$rootPath/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = Directory('$rootPath/Downloads');
            }
          }
        }
      }
    }

    // Fallback to app documents directory if Downloads not accessible
    if (downloadsDir == null || !await downloadsDir.exists()) {
      AppLogger.w(
        '[CSVExport] Downloads folder not accessible, using app directory',
      );
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    // Create directory if it doesn't exist
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final file = File('${downloadsDir.path}/$fileName.csv');
    final csvContent = _generateCSVContent(data);
    await file.writeAsString(csvContent);

    AppLogger.i('[CSVExport] File saved to: ${file.path}');
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
      final dateFormat = DateFormat('dd/MM/yyyy');
      buffer.writeln(
        [
          '${dateFormat.format(reading.startDate)} - ${dateFormat.format(reading.endDate)}',
          reading.previousReading.toStringAsFixed(2),
          reading.presentReading.toStringAsFixed(2),
          reading.consumption.toStringAsFixed(2),
          reading.ratePerKwh.toStringAsFixed(4),
          reading.estimatedBill.toStringAsFixed(2),
          dateFormat.format(reading.createdAt),
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
    // Request permissions first
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      throw Exception(
        'Storage permission denied. Please grant permission to export files.',
      );
    }

    // Get Downloads directory (same logic as CSV export)
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      // Try common Downloads folder paths
      final possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          downloadsDir = dir;
          break;
        }
      }

      // If none exist, try to construct from external storage directory
      if (downloadsDir == null) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final parts = externalDir.path.split('/');
          if (parts.length >= 4) {
            // Navigate to root and then to Download
            final rootPath = parts.sublist(0, 4).join('/');
            downloadsDir = Directory('$rootPath/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = Directory('$rootPath/Downloads');
            }
          }
        }
      }
    }

    // Fallback to app documents directory if Downloads not accessible
    if (downloadsDir == null || !await downloadsDir.exists()) {
      AppLogger.w(
        '[PDFExport] Downloads folder not accessible, using app directory',
      );
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    // Create directory if it doesn't exist
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Generate PDF
    final pdf = await _generatePDF(data);
    final file = File('${downloadsDir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());

    AppLogger.i('[PDFExport] File saved to: ${file.path}');
    return file.path;
  }

  Future<pw.Document> _generatePDF(List<MeterReadingModel> data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    // Calculate statistics
    final totalConsumption = data.fold(0.0, (sum, r) => sum + r.consumption);
    final totalBill = data.fold(0.0, (sum, r) => sum + r.estimatedBill);
    final averageConsumption =
        data.isEmpty ? 0.0 : totalConsumption / data.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ENERGY SMART',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#27AE60'),
                        ),
                      ),
                      pw.Text(
                        'Energy Usage Report',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Generated: ${dateFormat.format(now)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Statistics Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#27AE601A'), // 0.1 opacity in hex
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary Statistics',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatBox('Total Readings', '${data.length}'),
                      _buildStatBox(
                        'Total Consumption',
                        '${totalConsumption.toStringAsFixed(2)} kWh',
                      ),
                      _buildStatBox(
                        'Total Bill',
                        '₱${totalBill.toStringAsFixed(2)}',
                      ),
                      _buildStatBox(
                        'Average Usage',
                        '${averageConsumption.toStringAsFixed(2)} kWh',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Data Table
            pw.Text(
              'Meter Reading Details',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date Range',
                'Previous\n(kWh)',
                'Present\n(kWh)',
                'Consumption\n(kWh)',
                'Rate\n(₱/kWh)',
                'Bill (₱)',
              ],
              data:
                  data
                      .map(
                        (reading) => [
                          '${dateFormat.format(reading.startDate)}\n${dateFormat.format(reading.endDate)}',
                          reading.previousReading.toStringAsFixed(2),
                          reading.presentReading.toStringAsFixed(2),
                          reading.consumption.toStringAsFixed(2),
                          reading.ratePerKwh.toStringAsFixed(4),
                          reading.estimatedBill.toStringAsFixed(2),
                        ],
                      )
                      .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#27AE60'),
              ),
              cellStyle: pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildStatBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#27AE60'),
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
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
      if (data.isEmpty) {
        return ExportResult(
          success: false,
          filePath: null,
          message: 'No data available to export',
        );
      }

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
      AppLogger.e('[ExportService] Export failed: $e');
      return ExportResult(
        success: false,
        filePath: null,
        message: 'Export failed: ${e.toString()}',
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
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateRange =
        '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';

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

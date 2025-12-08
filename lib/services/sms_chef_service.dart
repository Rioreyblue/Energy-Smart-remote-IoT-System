import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:exercise_app/constants/app_config.dart';
import 'package:exercise_app/utils/app_logger.dart';

class SmsChefException implements Exception {
  SmsChefException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'SmsChefException(statusCode: $statusCode, message: $message)';
}

class SmsChefService {
  SmsChefService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri _endpoint = Uri.parse(
    'https://www.cloud.smschef.com/api/send/sms',
  );

  Future<void> sendOtp({
    required String phoneNumber,
    required String otp,
    Duration? expiry,
  }) async {
    final expireDuration = expiry ?? AppConfig.smsOtpValidity;
    final message =
        'Your ${AppConfig.appName} verification code is $otp. It will expire in ${expireDuration.inMinutes} minute(s).';

    final request =
        http.MultipartRequest('POST', _endpoint)
          ..fields['secret'] = AppConfig.smsChefSecret
          ..fields['mode'] = AppConfig.smsChefMode
          ..fields['device'] = AppConfig.smsChefDeviceId
          ..fields['sim'] = AppConfig.smsChefSimSlot
          ..fields['phone'] = phoneNumber
          ..fields['message'] = message;

    AppLogger.d('[SmsChefService] Sending OTP to $phoneNumber via device mode');

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw SmsChefException(
        'Failed to send OTP. Please try again later.',
        response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      throw SmsChefException('Empty response body from SmsChef');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final messageValue =
        (decoded['message'] ?? decoded['error'] ?? '').toString();
    final normalizedMessage = messageValue.toLowerCase();
    final success =
        (decoded['status'] == true) ||
        (decoded['success'] == true) ||
        normalizedMessage.contains('queued');
    if (!success) {
      final message = messageValue.isNotEmpty ? messageValue : 'Unknown error';
      throw SmsChefException(message, response.statusCode);
    }
  }

  /// Send budget threshold alert SMS
  Future<void> sendBudgetAlert({
    required String phoneNumber,
    required double consumedCost,
    required double remainingBudget,
    required double totalBudget,
    required double thresholdPercentage,
    bool isFullConsumption = false,
  }) async {
    final usedPercent = (consumedCost / totalBudget * 100).toStringAsFixed(1);
    final remainingPercent = (remainingBudget / totalBudget * 100)
        .toStringAsFixed(1);

    // Create a well-formatted, readable SMS message with icons and spacing
    final alertTitle =
        isFullConsumption
            ? '🚨 ${AppConfig.appName} Budget Fully Consumed!'
            : '⚠️ ${AppConfig.appName} Budget Alert';

    final alertMessage =
        isFullConsumption
            ? '📊 Budget Fully Consumed: 100%'
            : '📊 Threshold Reached: ${thresholdPercentage.toStringAsFixed(0)}%';

    final actionMessage =
        isFullConsumption
            ? '🚨 Your budget has been fully consumed. Please review your energy usage immediately.'
            : '📱 Please monitor your energy usage to stay within budget.';

    final message =
        '$alertTitle\n\n'
        '$alertMessage\n\n'
        '💰 Budget Summary:\n'
        '• Total Budget: ₱${totalBudget.toStringAsFixed(2)}\n'
        '• Consumed: ₱${consumedCost.toStringAsFixed(2)} (${usedPercent}%)\n'
        '• Remaining: ₱${remainingBudget.toStringAsFixed(2)} (${remainingPercent}%)\n\n'
        '$actionMessage\n\n'
        'Thank you for using ${AppConfig.appName}!';

    // Log the formatted message for debugging
    AppLogger.d('[SmsChefService] Formatted SMS message:\n$message');

    final request =
        http.MultipartRequest('POST', _endpoint)
          ..fields['secret'] = AppConfig.smsChefSecret
          ..fields['mode'] = AppConfig.smsChefMode
          ..fields['device'] = AppConfig.smsChefDeviceId
          ..fields['sim'] = AppConfig.smsChefSimSlot
          ..fields['phone'] = phoneNumber
          ..fields['message'] = message;

    AppLogger.d(
      '[SmsChefService] Sending budget alert to $phoneNumber via device mode',
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw SmsChefException(
        'Failed to send budget alert. Please try again later.',
        response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      throw SmsChefException('Empty response body from SmsChef');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final messageValue =
        (decoded['message'] ?? decoded['error'] ?? '').toString();
    final normalizedMessage = messageValue.toLowerCase();
    final success =
        (decoded['status'] == true) ||
        (decoded['success'] == true) ||
        normalizedMessage.contains('queued');
    if (!success) {
      final message = messageValue.isNotEmpty ? messageValue : 'Unknown error';
      throw SmsChefException(message, response.statusCode);
    }

    AppLogger.i(
      '[SmsChefService] ✅ Budget alert SMS sent successfully to $phoneNumber',
    );
  }

  /// Send power rate update alert SMS
  Future<void> sendPowerRateUpdateAlert({
    required String phoneNumber,
    required double oldRate,
    required double newRate,
  }) async {
    final rateChange = newRate - oldRate;
    final changeDirection =
        rateChange > 0
            ? '📈'
            : rateChange < 0
            ? '📉'
            : '📊';
    final changeAmount = rateChange.abs();
    final changePercent = ((rateChange / oldRate) * 100).abs().toStringAsFixed(
      2,
    );

    // Create a well-formatted, readable SMS message with icons and spacing
    final alertTitle = '⚡️ ${AppConfig.appName} Power Rate Update';

    final rateChangeSection =
        rateChange > 0
            ? '📈 Rate Increased by ${changePercent}%'
            : rateChange < 0
            ? '📉 Rate Decreased by ${changePercent}%'
            : '📊 Rate Updated';

    final message =
        '$alertTitle\n\n'
        '$rateChangeSection\n\n'
        '💰 Rate Details:\n'
        '• Previous Rate: ₱${oldRate.toStringAsFixed(4)}/kWh\n'
        '• New Rate: ₱${newRate.toStringAsFixed(4)}/kWh\n'
        '• Change: ${rateChange > 0 ? '+' : ''}₱${changeAmount.toStringAsFixed(4)}/kWh\n\n'
        '$changeDirection Your energy costs will be affected by this change.\n\n'
        '📱 Please review your energy usage accordingly.\n\n'
        'Thank you for using ${AppConfig.appName}!';

    // Log the formatted message for debugging
    AppLogger.d('[SmsChefService] Formatted SMS message:\n$message');

    final request =
        http.MultipartRequest('POST', _endpoint)
          ..fields['secret'] = AppConfig.smsChefSecret
          ..fields['mode'] = AppConfig.smsChefMode
          ..fields['device'] = AppConfig.smsChefDeviceId
          ..fields['sim'] = AppConfig.smsChefSimSlot
          ..fields['phone'] = phoneNumber
          ..fields['message'] = message;

    AppLogger.d(
      '[SmsChefService] Sending power rate update alert to $phoneNumber via device mode',
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw SmsChefException(
        'Failed to send power rate update alert. Please try again later.',
        response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      throw SmsChefException('Empty response body from SmsChef');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final messageValue =
        (decoded['message'] ?? decoded['error'] ?? '').toString();
    final normalizedMessage = messageValue.toLowerCase();
    final success =
        (decoded['status'] == true) ||
        (decoded['success'] == true) ||
        normalizedMessage.contains('queued');
    if (!success) {
      final message = messageValue.isNotEmpty ? messageValue : 'Unknown error';
      throw SmsChefException(message, response.statusCode);
    }

    AppLogger.i(
      '[SmsChefService] ✅ Power rate update alert SMS sent successfully to $phoneNumber',
    );
  }
}

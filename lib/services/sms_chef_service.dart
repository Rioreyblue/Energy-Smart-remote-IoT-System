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
}

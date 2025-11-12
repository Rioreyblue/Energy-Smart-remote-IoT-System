import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';
import '../utils/app_logger.dart';

/// Service for uploading images to Cloudinary
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // Cloudinary credentials
  // Values come from CloudinaryConfig so they can be overridden via --dart-define.
  static const String _cloudName = CloudinaryConfig.cloudName;
  static const String _uploadPreset = CloudinaryConfig.uploadPreset;
  static const String _defaultFolder = CloudinaryConfig.defaultFolder;
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload image file to Cloudinary using unsigned upload preset
  /// Returns the secure URL of the uploaded image
  Future<String?> uploadImage(
    File imageFile, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // Add upload preset (unsigned upload - no signature needed)
      request.fields['upload_preset'] = _uploadPreset;

      // Add folder if specified, fall back to configured default
      final resolvedFolder = (folder ?? _defaultFolder).trim();
      if (resolvedFolder.isNotEmpty) {
        request.fields['folder'] = resolvedFolder;
      }

      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Track progress
      if (onProgress != null) {
        onProgress(0.5); // Indicate upload started
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (onProgress != null) {
        onProgress(1.0); // Indicate upload completed
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final secureUrl = responseData['secure_url'] as String?;

        if (secureUrl != null) {
          AppLogger.i(
            '[CloudinaryService] Image uploaded successfully: $secureUrl',
          );
          return secureUrl;
        } else {
          AppLogger.e(
            '[CloudinaryService] No secure_url in response: ${response.body}',
          );
          return null;
        }
      } else {
        AppLogger.e(
          '[CloudinaryService] Upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        '[CloudinaryService] Error uploading image: $e',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Upload image from bytes (for web or already loaded images)
  Future<String?> uploadImageFromBytes(
    List<int> imageBytes,
    String fileName, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // Add upload preset (unsigned upload - no signature needed)
      request.fields['upload_preset'] = _uploadPreset;

      // Add folder if specified
      final resolvedFolder = (folder ?? _defaultFolder).trim();
      if (resolvedFolder.isNotEmpty) {
        request.fields['folder'] = resolvedFolder;
      }

      // Add image file from bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // Track progress
      if (onProgress != null) {
        onProgress(0.5);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (onProgress != null) {
        onProgress(1.0);
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final secureUrl = responseData['secure_url'] as String?;

        if (secureUrl != null) {
          AppLogger.i(
            '[CloudinaryService] Image uploaded successfully: $secureUrl',
          );
          return secureUrl;
        } else {
          AppLogger.e(
            '[CloudinaryService] No secure_url in response: ${response.body}',
          );
          return null;
        }
      } else {
        AppLogger.e(
          '[CloudinaryService] Upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        '[CloudinaryService] Error uploading image: $e',
        e,
        stackTrace,
      );
      return null;
    }
  }
}

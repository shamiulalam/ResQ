import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

/// API client for generating DINOv2 embeddings.
///
/// IMPORTANT:
///
/// Despite the historical class name HuggingFaceService,
/// this class NO LONGER calls Hugging Face's Serverless
/// Inference API.
///
/// It now calls the ResQ FastAPI backend:
///
/// Flutter
///   -> FastAPI
///   -> facebook/dinov2-base
///   -> 768-dimensional embedding
///
/// The old class name is deliberately preserved so existing
/// PetSearchService code does not need to be rewritten.
class HuggingFaceService {
  static const int embeddingDimension = 768;

  final String _baseUrl;
  final http.Client _httpClient;

  bool _disposed = false;

  HuggingFaceService({
    // Kept only for backward compatibility with any old
    // constructor calls. The token is no longer used.
    String? token,
    String? baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = (baseUrl ?? ApiConstants.backendBaseUrl).replaceFirst(
          RegExp(r'/$'),
          '',
        ),
        _httpClient = httpClient ?? http.Client();

  Uri get _embeddingEndpoint {
    return Uri.parse(
      '$_baseUrl/api/match/embed',
    );
  }

  Uri get _healthEndpoint {
    return Uri.parse(
      '$_baseUrl/health',
    );
  }

  /// Converts an image into a normalized
  /// 768-dimensional DINOv2 embedding.
  ///
  /// Provide exactly ONE:
  ///
  /// - imageFile
  /// - imageBytes
  ///
  /// The method signature intentionally remains close to
  /// the previous HuggingFaceService implementation.
  Future<List<double>> embedImage({
    File? imageFile,
    Uint8List? imageBytes,
    String? filename,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (_disposed) {
      throw Exception(
        'HuggingFaceService is disposed.',
      );
    }

    // -------------------------------------------------------
    // Exactly one image source
    // -------------------------------------------------------

    final bool hasFile = imageFile != null;

    final bool hasBytes = imageBytes != null;

    if (hasFile == hasBytes) {
      throw Exception(
        'Provide exactly one of '
        'imageFile or imageBytes.',
      );
    }

    // -------------------------------------------------------
    // Build multipart request
    // -------------------------------------------------------

    final request = http.MultipartRequest(
      'POST',
      _embeddingEndpoint,
    );

    request.headers['Accept'] = 'application/json';

    // -------------------------------------------------------
    // File input
    // -------------------------------------------------------

    if (imageFile != null) {
      final bool exists = await imageFile.exists();

      if (!exists) {
        throw Exception(
          'Image file does not exist: '
          '${imageFile.path}',
        );
      }

      final int fileSize = await imageFile.length();

      if (fileSize == 0) {
        throw Exception(
          'Image file is empty.',
        );
      }

      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          'Image must be 10 MB or smaller.',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: _extractFilename(
            imageFile.path,
          ),
        ),
      );
    }

    // -------------------------------------------------------
    // Uint8List input
    // -------------------------------------------------------

    if (imageBytes != null) {
      if (imageBytes.isEmpty) {
        throw Exception(
          'Image bytes are empty.',
        );
      }

      if (imageBytes.length > 10 * 1024 * 1024) {
        throw Exception(
          'Image must be 10 MB or smaller.',
        );
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename ?? 'image.jpg',
        ),
      );
    }

    // -------------------------------------------------------
    // Send request
    // -------------------------------------------------------

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await _httpClient.send(request).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'DINOv2 backend request '
            'timed out after '
            '${timeout.inSeconds} seconds.',
          );
        },
      );
    } on TimeoutException {
      rethrow;
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to the '
        'ResQ AI backend at '
        '$_baseUrl. '
        'Make sure FastAPI is running. '
        'Network error: $e',
      );
    } catch (e) {
      throw Exception(
        'Failed to call the '
        'ResQ AI backend: $e',
      );
    }

    // -------------------------------------------------------
    // Convert streamed response
    // -------------------------------------------------------

    final http.Response response;

    try {
      response = await http.Response.fromStream(
        streamedResponse,
      );
    } catch (e) {
      throw Exception(
        'Failed to read backend '
        'response: $e',
      );
    }

    // -------------------------------------------------------
    // HTTP errors
    // -------------------------------------------------------

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = _extractServerError(
        response.body,
      );

      throw Exception(
        'DINOv2 backend returned '
        '${response.statusCode}: '
        '$serverMessage',
      );
    }

    // -------------------------------------------------------
    // Parse JSON
    // -------------------------------------------------------

    dynamic decoded;

    try {
      decoded = jsonDecode(
        response.body,
      );
    } catch (e) {
      throw Exception(
        'Backend returned invalid '
        'JSON: $e',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Unexpected response format '
        'from DINOv2 backend.',
      );
    }

    // -------------------------------------------------------
    // Check server dimension
    // -------------------------------------------------------

    final dynamic dimension = decoded['dimension'];

    if (dimension != null &&
        dimension is num &&
        dimension.toInt() != embeddingDimension) {
      throw Exception(
        'Backend reported embedding '
        'dimension ${dimension.toInt()}, '
        'expected '
        '$embeddingDimension.',
      );
    }

    // -------------------------------------------------------
    // Extract embedding
    // -------------------------------------------------------

    final dynamic rawEmbedding = decoded['embedding'];

    if (rawEmbedding == null) {
      throw Exception(
        'Backend response does not '
        'contain an embedding.',
      );
    }

    if (rawEmbedding is! List) {
      throw Exception(
        'Embedding returned by backend '
        'is not a list.',
      );
    }

    final List<double> embedding;

    try {
      embedding = rawEmbedding.map<double>(
        (dynamic value) {
          if (value is! num) {
            throw const FormatException(
              'Embedding contains '
              'a non-numeric value.',
            );
          }

          return value.toDouble();
        },
      ).toList(
        growable: false,
      );
    } catch (e) {
      throw Exception(
        'Failed to parse embedding '
        'values: $e',
      );
    }

    // -------------------------------------------------------
    // Validate dimensions
    // -------------------------------------------------------

    if (embedding.length != embeddingDimension) {
      throw Exception(
        'Embedding dimension mismatch: '
        'expected '
        '$embeddingDimension, '
        'got ${embedding.length}.',
      );
    }

    return embedding;
  }

  /// Check whether the FastAPI backend and DINOv2
  /// model are available.
  Future<bool> healthCheck({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_disposed) {
      return false;
    }

    try {
      final response = await _httpClient.get(
        _healthEndpoint,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        timeout,
      );

      if (response.statusCode != 200) {
        return false;
      }

      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        return false;
      }

      return (decoded['status'] == 'ok' &&
          decoded['embedding_dimension'] == embeddingDimension);
    } catch (_) {
      return false;
    }
  }

  /// Extract useful FastAPI error messages.
  String _extractServerError(
    String body,
  ) {
    if (body.trim().isEmpty) {
      return ('No error details '
          'were provided.');
    }

    try {
      final dynamic decoded = jsonDecode(body);

      if (decoded is Map) {
        final dynamic detail = decoded['detail'];

        if (detail != null) {
          return detail.toString();
        }

        final dynamic error = decoded['error'];

        if (error != null) {
          return error.toString();
        }

        final dynamic message = decoded['message'];

        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      // Fall back to raw body.
    }

    return body;
  }

  static String _extractFilename(
    String path,
  ) {
    final normalized = path.replaceAll(
      '\\',
      '/',
    );

    return normalized.split('/').last;
  }

  void dispose() {
    if (!_disposed) {
      _httpClient.close();
      _disposed = true;
    }
  }
}

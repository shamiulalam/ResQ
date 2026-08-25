import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../../core/constants/api_constants.dart';

class UploadedChatMedia {
  const UploadedChatMedia({
    required this.objectPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String objectPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  Map<String, dynamic> toMap() => {
        'objectPath': objectPath,
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
      };
}

class ChatMediaService {
  ChatMediaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, _SignedUrlCacheEntry> _signedUrls = {};

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in to upload media.');
    return {'Authorization': 'Bearer $token'};
  }

  Future<UploadedChatMedia> upload({
    required String conversationId,
    required String messageId,
    required File file,
    required String fileName,
  }) async {
    final length = await file.length();
    if (length > 25 * 1024 * 1024) {
      throw StateError('Attachments must be 25 MB or smaller.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.backendBaseUrl}/api/chat/media/upload'),
    );
    request.headers.addAll(await _headers());
    request.fields['conversation_id'] = conversationId;
    request.fields['message_id'] = messageId;
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: fileName,
    ));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UploadedChatMedia(
      objectPath: data['objectPath'] as String,
      fileName: fileName,
      mimeType: lookupMimeType(file.path) ?? 'application/octet-stream',
      sizeBytes: length,
    );
  }

  Future<String> signedUrl(
    String conversationId,
    String objectPath,
  ) async {
    final cached = _signedUrls[objectPath];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }
    final uri = Uri.parse(
      '${ApiConstants.backendBaseUrl}/api/chat/media/signed-url',
    ).replace(queryParameters: {
      'conversation_id': conversationId,
      'object_path': objectPath,
    });
    final response = await _client.get(uri, headers: await _headers());
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['signedUrl'] as String;
    _signedUrls[objectPath] = _SignedUrlCacheEntry(
      url,
      DateTime.now().add(const Duration(minutes: 4)),
    );
    return url;
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? 'Media request failed.';
    } catch (_) {
      return 'Media request failed (${response.statusCode}).';
    }
  }
}

class _SignedUrlCacheEntry {
  const _SignedUrlCacheEntry(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}

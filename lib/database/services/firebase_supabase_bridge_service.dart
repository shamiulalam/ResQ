import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class FirebaseSupabaseBridgeService {
  final http.Client _httpClient;

  FirebaseSupabaseBridgeService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<void> ensureSupabaseRole() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'Firebase user is not logged in.',
      );
    }

    // -------------------------------------------------------
    // First check current token.
    // Avoid unnecessary backend requests.
    // -------------------------------------------------------

    final IdTokenResult currentToken = await user.getIdTokenResult();

    final currentRole = currentToken.claims?['role'];

    if (currentRole == 'authenticated') {
      return;
    }

    // -------------------------------------------------------
    // Get current valid Firebase JWT.
    // -------------------------------------------------------

    final String? idToken = await user.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Could not obtain Firebase ID token.',
      );
    }

    final String baseUrl = ApiConstants.backendBaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );

    final Uri uri = Uri.parse(
      '$baseUrl/api/auth/'
      'sync-supabase-role',
    );

    final http.Response response;

    try {
      response = await _httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Accept': 'application/json',
        },
      );
    } catch (e) {
      throw Exception(
        'Failed to contact authentication '
        'bridge: $e',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = response.body;

      try {
        final dynamic decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map && decoded['detail'] != null) {
          message = decoded['detail'].toString();
        }
      } catch (_) {
        // Use raw response.
      }

      throw Exception(
        'Authentication bridge returned '
        '${response.statusCode}: $message',
      );
    }

    // -------------------------------------------------------
    // VERY IMPORTANT:
    //
    // The claim was changed SERVER-SIDE.
    // Our existing Firebase ID token is therefore stale.
    //
    // Force Firebase to issue a new token.
    // -------------------------------------------------------

    final IdTokenResult refreshedToken = await user.getIdTokenResult(
      true,
    );

    final refreshedRole = refreshedToken.claims?['role'];

    if (refreshedRole != 'authenticated') {
      throw Exception(
        'Firebase token refresh succeeded '
        'but role=authenticated was not found.',
      );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

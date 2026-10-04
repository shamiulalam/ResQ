import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

class ChatDirectoryService {
  ChatDirectoryService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<UserModel>> listUsers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Please sign in to start a chat.');
    final response = await _client.get(
      Uri.parse('${ApiConstants.backendBaseUrl}/api/chat/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw StateError('Could not load the chat directory.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>? ?? const [];
    return users.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return UserModel.fromMap(map['uid'] as String, map);
    }).toList();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../presentation/screens/chat/chat_window_screen.dart';

class ChatNotificationService {
  ChatNotificationService._();
  static final instance = ChatNotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _local = FlutterLocalNotificationsPlugin();
  String? _openConversationId;

  void setOpenConversation(String? conversationId) {
    _openConversationId = conversationId;
  }

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) _openPayload(response.payload!);
      },
    );
    const channel = AndroidNotificationChannel(
      'resq_messages',
      'ResQ messages',
      description: 'Direct message notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    try {
      await FirebaseMessaging.instance.requestPermission();
      await _registerCurrentToken();
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) unawaited(_registerCurrentToken());
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_openRemoteMessage);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openRemoteMessage(initial);
        });
      }
    } catch (error) {
      debugPrint('Chat notifications are unavailable: $error');
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final deviceId = token.hashCode.abs().toRadixString(16);
    await FirebaseFirestore.instance.doc('users/$uid/devices/$deviceId').set({
      'token': token,
      'platform': Platform.operatingSystem,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (message.data['conversationId'] == _openConversationId) return;
    const details = AndroidNotificationDetails(
      'resq_messages',
      'ResQ messages',
      channelDescription: 'Direct message notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _local.show(
      message.hashCode,
      message.notification?.title ?? message.data['senderName'],
      message.notification?.body ?? 'New message',
      const NotificationDetails(android: details),
      payload: jsonEncode(message.data),
    );
  }

  void _openRemoteMessage(RemoteMessage message) {
    _openData(message.data);
  }

  void _openPayload(String payload) {
    _openData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
  }

  void _openData(Map<String, dynamic> data) {
    final conversationId = data['conversationId']?.toString();
    final senderUid = data['senderUid']?.toString();
    if (conversationId == null || senderUid == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatWindowScreen(
          conversationId: conversationId,
          otherUid: senderUid,
          contactName: data['senderName']?.toString() ?? 'ResQ User',
        ),
      ),
    );
  }

  Future<void> dispatch(String conversationId, String messageId) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    await http.post(
      Uri.parse(
        '${ApiConstants.backendBaseUrl}/api/chat/notifications/send',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'conversationId': conversationId,
        'messageId': messageId,
      }),
    );
  }
}

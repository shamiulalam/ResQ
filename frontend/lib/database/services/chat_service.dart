import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : db = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String get uid =>
      auth.currentUser?.uid ??
      (throw const ChatException('Please sign in to use chat.'));
  static String directConversationId(String a, String b) {
    if (a.isEmpty || b.isEmpty || a == b) {
      throw const ChatException('A direct chat requires two different users.');
    }
    final ids = [a, b]..sort();
    return 'direct_${ids[0]}_${ids[1]}';
  }

  DocumentReference<Map<String, dynamic>> _conversation(String id) =>
      db.collection('conversations').doc(id);
  Future<String> openOrCreateDirectConversation(String otherUid,
      {String? contextFlareId}) async {
    final me = uid;
    final id = directConversationId(me, otherUid);
    final ref = _conversation(id);
    final blockedByMe = await db.doc('users/$me/blockedUsers/$otherUid').get();
    if (blockedByMe.exists) {
      throw const ChatException('Messaging is unavailable for this user.');
    }
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final ids = [me, otherUid]..sort();
        tx.set(ref, {
          'type': 'direct',
          'participantIds': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageText': '',
          'lastMessageType': 'text',
          'lastMessageSenderId': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts': {for (final i in ids) i: 0},
          'lastReadAt': {},
          'lastDeliveredAt': {},
          if (contextFlareId != null) 'contextFlareId': contextFlareId,
          'schemaVersion': 1
        });
      }
    });
    return id;
  }

  Stream<List<Conversation>> watchInbox() => db
          .collection('conversations')
          .where('participantIds', arrayContains: uid)
          .snapshots()
          .map((snapshot) {
        final conversations = snapshot.docs
            .map((doc) => Conversation.fromMap(doc.id, doc.data()))
            .toList();
        conversations.sort((first, second) {
          final firstTime = first.lastMessageAt ?? first.createdAt;
          final secondTime = second.lastMessageAt ?? second.createdAt;
          if (firstTime == null && secondTime == null) return 0;
          if (firstTime == null) return 1;
          if (secondTime == null) return -1;
          return secondTime.compareTo(firstTime);
        });
        return conversations;
      });
  Stream<Conversation?> watchConversation(String id) => _conversation(id)
      .snapshots()
      .map((d) => d.exists ? Conversation.fromMap(d.id, d.data()!) : null);
  Stream<List<ChatMessage>> watchRecentMessages(String id, {int limit = 30}) =>
      _conversation(id)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true)
          .map((s) => s.docs
              .map((d) => ChatMessage.fromMap(d.id, d.data()))
              .where((m) => !m.deletedFor.contains(uid))
              .toList());
  Future<List<ChatMessage>> loadOlderMessages(String id, DateTime before,
      {int limit = 30}) async {
    final s = await _conversation(id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return s.docs
        .map((d) => ChatMessage.fromMap(d.id, d.data()))
        .where((m) => !m.deletedFor.contains(uid))
        .toList();
  }

  String newMessageId(String conversationId) =>
      _conversation(conversationId).collection('messages').doc().id;

  Future<String> sendText(
    String id,
    String text, {
    MessageReply? reply,
    String? messageId,
  }) =>
      sendMessage(
        id,
        type: ChatMessageType.text,
        text: text,
        reply: reply,
        messageId: messageId,
      );

  Future<String> sendMessage(
    String id, {
    required ChatMessageType type,
    String text = '',
    MessageReply? reply,
    Map<String, dynamic>? media,
    String? flareId,
    String? messageId,
  }) async {
    final value = text.trim();
    if (type == ChatMessageType.text && value.isEmpty) {
      throw const ChatException('Message cannot be empty.');
    }
    final me = uid;
    final conversation = _conversation(id);
    final message = conversation.collection('messages').doc(messageId);
    final targetId = message.id;
    await db.runTransaction((tx) async {
      final c = await tx.get(conversation);
      if (!c.exists ||
          !List<String>.from(c.data()?['participantIds'] ?? []).contains(me)) {
        throw const ChatException('Conversation is unavailable.');
      }
      final existing = await tx.get(message);
      if (existing.exists) return;
      final participants =
          List<String>.from(c.data()?['participantIds'] ?? const []);
      final other = participants.firstWhere((participant) => participant != me);
      final preview = value.isNotEmpty ? value : _previewForType(type);
      tx.set(message, {
        'senderId': me,
        'type': type.name,
        'text': value,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.now(),
        'clientMessageId': targetId,
        'deletedFor': <String>[],
        'deletedForEveryone': false,
        'reactions': <String, String>{},
        if (reply != null) 'replyTo': reply.toMap(),
        if (media != null) 'media': media,
        if (flareId != null) 'flareId': flareId,
      });
      tx.update(conversation, {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageId': targetId,
        'lastMessageText': preview,
        'lastMessageType': type.name,
        'lastMessageSenderId': me,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.$other': FieldValue.increment(1)
      });
    });
    return targetId;
  }

  String _previewForType(ChatMessageType type) => switch (type) {
        ChatMessageType.image => 'Photo',
        ChatMessageType.video => 'Video',
        ChatMessageType.file => 'File',
        ChatMessageType.audio => 'Voice message',
        ChatMessageType.flare => 'Shared a Flare',
        ChatMessageType.system => 'System message',
        ChatMessageType.text => '',
      };

  Future<void> markDelivered(String id) => _conversation(id)
      .update({'lastDeliveredAt.$uid': FieldValue.serverTimestamp()});
  Future<void> markRead(String id) => _conversation(id).update({
        'unreadCounts.$uid': 0,
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
        'lastDeliveredAt.$uid': FieldValue.serverTimestamp()
      });
  Future<void> setTyping(String id, bool value) => _conversation(id)
      .collection('typing')
      .doc(uid)
      .set({'isTyping': value, 'updatedAt': FieldValue.serverTimestamp()});
  Stream<bool> watchTyping(String id, String other) =>
      _conversation(id).collection('typing').doc(other).snapshots().map((d) {
        final data = d.data();
        final at = _date(data?['updatedAt']);
        return data?['isTyping'] == true &&
            at != null &&
            DateTime.now().difference(at) < const Duration(seconds: 8);
      });
  Future<void> react(String id, String messageId, String? emoji) =>
      _conversation(id)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$uid': emoji ?? FieldValue.delete()});
  Future<void> edit(String id, String messageId, String text) =>
      _conversation(id).collection('messages').doc(messageId).update(
          {'text': text.trim(), 'editedAt': FieldValue.serverTimestamp()});
  Future<void> deleteForMe(String id, String messageId) =>
      _conversation(id).collection('messages').doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([uid])
      });
  Future<void> unsend(String id, String messageId) =>
      _conversation(id).collection('messages').doc(messageId).update({
        'text': '',
        'media': FieldValue.delete(),
        'deletedForEveryone': true,
        'deletedAt': FieldValue.serverTimestamp()
      });
  DocumentReference<Map<String, dynamic>> preferenceRef(String id) =>
      db.doc('users/$uid/chatPreferences/$id');
  Stream<ConversationPreference> watchPreference(String id) => preferenceRef(id)
      .snapshots()
      .map((d) => ConversationPreference.fromMap(d.data()));
  Future<void> setPreference(String id,
          {bool? muted, bool? pinned, bool? archived}) =>
      preferenceRef(id).set({
        if (muted != null) 'muted': muted,
        if (pinned != null) 'pinned': pinned,
        if (archived != null) 'archived': archived,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
  Future<void> setBlocked(String other, bool blocked) {
    final reference = db.doc('users/$uid/blockedUsers/$other');
    if (!blocked) {
      return reference.delete();
    }
    return reference.set({'blockedAt': FieldValue.serverTimestamp()});
  }

  Future<void> updatePresence(bool online) => db.doc('presence/$uid').set({
        'state': online ? 'online' : 'offline',
        'lastActiveAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
}

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

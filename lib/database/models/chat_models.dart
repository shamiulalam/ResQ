import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : null;

enum ChatMessageType { text, image, video, audio, file, flare, system }

class MessageReply {
  const MessageReply(
      {required this.messageId,
      required this.senderId,
      required this.type,
      required this.preview});
  final String messageId, senderId, type, preview;
  factory MessageReply.fromMap(Map<String, dynamic> map) => MessageReply(
      messageId: map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      preview: map['preview'] as String? ?? '');
  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderId': senderId,
        'type': type,
        'preview': preview
      };
}

class ChatMessage {
  const ChatMessage(
      {required this.id,
      required this.senderId,
      required this.type,
      required this.text,
      required this.clientCreatedAt,
      this.createdAt,
      this.editedAt,
      this.replyTo,
      this.reactions = const {},
      this.deletedFor = const [],
      this.deletedForEveryone = false,
      this.media,
      this.clientMessageId = ''});
  final String id, senderId, text, clientMessageId;
  final ChatMessageType type;
  final DateTime clientCreatedAt;
  final DateTime? createdAt, editedAt;
  final MessageReply? replyTo;
  final Map<String, String> reactions;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final Map<String, dynamic>? media;
  DateTime get effectiveCreatedAt => createdAt ?? clientCreatedAt;
  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? 'text';
    return ChatMessage(
        id: id,
        senderId: map['senderId'] as String? ?? '',
        type: ChatMessageType.values
                .where((e) => e.name == typeName)
                .firstOrNull ??
            ChatMessageType.text,
        text: map['text'] as String? ?? '',
        createdAt: _date(map['createdAt']),
        clientCreatedAt: _date(map['clientCreatedAt']) ?? DateTime.now(),
        editedAt: _date(map['editedAt']),
        replyTo: map['replyTo'] is Map
            ? MessageReply.fromMap(
                Map<String, dynamic>.from(map['replyTo'] as Map))
            : null,
        reactions:
            Map<String, String>.from(map['reactions'] as Map? ?? const {}),
        deletedFor: List<String>.from(map['deletedFor'] as List? ?? const []),
        deletedForEveryone: map['deletedForEveryone'] as bool? ?? false,
        media: map['media'] is Map
            ? Map<String, dynamic>.from(map['media'] as Map)
            : null,
        clientMessageId: map['clientMessageId'] as String? ?? id);
  }
}

class Conversation {
  const Conversation(
      {required this.id,
      required this.participantIds,
      required this.lastMessageText,
      required this.lastMessageType,
      required this.lastMessageSenderId,
      this.createdAt,
      this.updatedAt,
      this.lastMessageAt,
      this.unreadCounts = const {},
      this.lastReadAt = const {},
      this.lastDeliveredAt = const {},
      this.contextFlareId});
  final String id, lastMessageText, lastMessageType, lastMessageSenderId;
  final List<String> participantIds;
  final DateTime? createdAt, updatedAt, lastMessageAt;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> lastReadAt, lastDeliveredAt;
  final String? contextFlareId;
  String otherUid(String uid) =>
      participantIds.firstWhere((e) => e != uid, orElse: () => '');
  factory Conversation.fromMap(String id, Map<String, dynamic> map) => Conversation(
      id: id,
      participantIds:
          List<String>.from(map['participantIds'] as List? ?? const []),
      lastMessageText: map['lastMessageText'] as String? ?? '',
      lastMessageType: map['lastMessageType'] as String? ?? 'text',
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      lastMessageAt: _date(map['lastMessageAt']),
      unreadCounts: (map['unreadCounts'] as Map? ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
      lastReadAt: (map['lastReadAt'] as Map? ?? const {}).map((k, v) =>
          MapEntry(k.toString(),
              _date(v) ?? DateTime.fromMillisecondsSinceEpoch(0))),
      lastDeliveredAt: (map['lastDeliveredAt'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k.toString(),
              _date(v) ?? DateTime.fromMillisecondsSinceEpoch(0))),
      contextFlareId: map['contextFlareId'] as String?);
}

class ConversationPreference {
  const ConversationPreference(
      {this.muted = false, this.pinned = false, this.archived = false});
  final bool muted, pinned, archived;
  factory ConversationPreference.fromMap(Map<String, dynamic>? map) =>
      ConversationPreference(
          muted: map?['muted'] as bool? ?? false,
          pinned: map?['pinned'] as bool? ?? false,
          archived: map?['archived'] as bool? ?? false);
}

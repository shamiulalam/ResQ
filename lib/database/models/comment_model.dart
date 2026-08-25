import 'package:cloud_firestore/cloud_firestore.dart';

/// A single comment on a Flare post.
///
/// Firestore path: `flares/{flareId}/comments/{commentId}`
class CommentModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(String id, Map<String, dynamic> map) {
    return CommentModel(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Anonymous',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

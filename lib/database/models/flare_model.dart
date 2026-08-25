import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single "Flare" post (lost / spotted / general) as stored
/// in Firestore, under the `flares` collection.
///
/// Deliberately stores [postType] and [petType] as plain strings rather
/// than importing the PostType/PetType enums from the presentation
/// layer's flare_models.dart — this keeps the database layer decoupled
/// from UI-layer enum definitions. Callers should pass `_postType.name`
/// / `_petType.name` (Dart enums have a built-in `.name` getter).
class FlareModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String postType; // 'lost' | 'spotted' | 'general'
  final String petType; // 'dog' | 'cat' | 'bird'
  final String petName;
  final String breed;
  final String age;
  final String gender;
  final String description;

  /// Public Supabase Storage URL for newly-created flares.
  final String? photoUrl;

  /// Legacy inline image data retained only so existing Firestore posts render.
  final String? photoBase64;
  final double latitude;
  final double longitude;
  final String address;
  final String locationLabel;
  final DateTime dateTimeLost;
  final DateTime createdAt;

  // Engagement counters
  final int loveCount;
  final int commentCount;
  final List<String> lovedBy; // list of uids that have loved this post

  const FlareModel({
    required this.id,
    required this.authorUid,
    this.authorName = '',
    required this.postType,
    required this.petType,
    required this.petName,
    required this.breed,
    required this.age,
    required this.gender,
    required this.description,
    this.photoUrl,
    this.photoBase64,
    required this.latitude,
    required this.longitude,
    this.address = '',
    required this.locationLabel,
    required this.dateTimeLost,
    required this.createdAt,
    this.loveCount = 0,
    this.commentCount = 0,
    this.lovedBy = const [],
  });

  /// Converts this model into a Firestore-writable map. Note [id] is
  /// intentionally excluded — Firestore already has it as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'postType': postType,
      'petType': petType,
      'petName': petName,
      'breed': breed,
      'age': age,
      'gender': gender,
      'description': description,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      // Do not write base64 photos for new flares. This keeps documents well
      // below Firestore's 1 MiB document limit.
      if (photoBase64 != null && photoBase64!.isNotEmpty)
        'photoBase64': photoBase64,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'locationLabel': locationLabel,
      'dateTimeLost': Timestamp.fromDate(dateTimeLost),
      'createdAt': Timestamp.fromDate(createdAt),
      'loveCount': loveCount,
      'commentCount': commentCount,
      'lovedBy': lovedBy,
    };
  }

  /// Builds a FlareModel from a Firestore document snapshot.
  factory FlareModel.fromMap(String id, Map<String, dynamic> map) {
    return FlareModel(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      postType: map['postType'] as String? ?? 'general',
      petType: map['petType'] as String? ?? 'dog',
      petName: map['petName'] as String? ?? '',
      breed: map['breed'] as String? ?? '',
      age: map['age'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      description: map['description'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      photoBase64: map['photoBase64'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String? ??
          map['locationLabel'] as String? ??
          '',
      locationLabel: map['locationLabel'] as String? ??
          map['address'] as String? ??
          '',
      dateTimeLost:
          (map['dateTimeLost'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      loveCount: (map['loveCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      lovedBy: List<String>.from(map['lovedBy'] as List? ?? []),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a registered user's profile as stored in Firestore,
/// under the `users` collection, keyed by their Firebase Auth uid.
class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender; // 'Male' | 'Female'
  final DateTime createdAt;
  final String profileImage;
  final String bio;
  final String subtitle;
  final String location;
  final String city;
  final bool isVerified;
  final bool isEmailPublic;
  final bool isPhonePublic;
  final int followersCount;
  final int followingCount;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.createdAt,
    this.profileImage = '',
    this.bio = '',
    this.subtitle = '',
    this.location = '',
    this.city = '',
    this.isVerified = false,
    this.isEmailPublic = false,
    this.isPhonePublic = false,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  String get fullName => '$firstName $lastName';

  /// Converts this model into a Firestore-writable map.
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'gender': gender,
      'createdAt': Timestamp.fromDate(createdAt),
      if (profileImage.isNotEmpty) 'profileImage': profileImage,
      if (bio.isNotEmpty) 'bio': bio,
      if (subtitle.isNotEmpty) 'subtitle': subtitle,
      if (location.isNotEmpty) 'location': location,
      if (city.isNotEmpty) 'city': city,
      'isVerified': isVerified,
      'isEmailPublic': isEmailPublic,
      'isPhonePublic': isPhonePublic,
    };
  }

  /// Builds a UserModel from a Firestore document snapshot.
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImage: (map['profileImage'] ?? map['photoUrl']) as String? ?? '',
      bio: map['bio'] as String? ?? '',
      subtitle: (map['subtitle'] ?? map['roleLabel']) as String? ?? '',
      location: map['location'] as String? ?? '',
      city: map['city'] as String? ?? '',
      isVerified: map['isVerified'] as bool? ?? false,
      isEmailPublic: map['isEmailPublic'] as bool? ?? false,
      isPhonePublic: map['isPhonePublic'] as bool? ?? false,
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

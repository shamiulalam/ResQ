import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flare_model.dart';
import '../models/comment_model.dart';
import 'firebase_supabase_bridge_service.dart';
import 'huggingface_service.dart';
import 'pet_search_service.dart';

/// Handles Firestore data plus Supabase Storage for Flare posts.
/// - Real-time feed streams for the home screen
/// - Love (heart) reaction toggling
/// - Comments (sub-collection: flares/{id}/comments)
class FlareService {
  static const String _storageBucket = 'flare-images';
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;

  final CollectionReference<Map<String, dynamic>> _flaresRef;
  final SupabaseClient _supabase;
  final FirebaseSupabaseBridgeService _authBridge;
  final HuggingFaceService _embeddingService;

  FlareService({
    FirebaseFirestore? firestore,
    SupabaseClient? supabaseClient,
    FirebaseSupabaseBridgeService? authBridge,
    HuggingFaceService? embeddingService,
  })  : _flaresRef =
            (firestore ?? FirebaseFirestore.instance).collection('flares'),
        _supabase = supabaseClient ?? Supabase.instance.client,
        _authBridge = authBridge ?? FirebaseSupabaseBridgeService(),
        _embeddingService = embeddingService ?? HuggingFaceService();

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a flare document and stores its photo in Supabase Storage.
  ///
  /// The Firestore document contains only the public [FlareModel.photoUrl],
  /// never the image bytes. If Firestore fails after an upload, the storage
  /// object is removed so failed submissions do not leave orphaned files.
  ///
  /// Returns the new flare's Firestore document ID.
  Future<String> createFlare(FlareModel flare, {XFile? photo}) async {
    final docRef = _flaresRef.doc();
    String? storagePath;

    if (FirebaseAuth.instance.currentUser?.uid != flare.authorUid) {
      throw StateError('You may only create flares for your own account.');
    }

    FlareModel flareToSave = flare;
    Uint8List? photoBytes;
    if (photo != null) {
      await _authBridge.ensureSupabaseRole();
      photoBytes = await photo.readAsBytes();
      final uploadedPhoto = await _uploadPhoto(
        photo: photo,
        bytes: photoBytes,
        authorUid: flare.authorUid,
        flareId: docRef.id,
      );
      storagePath = uploadedPhoto.path;
      flareToSave = FlareModel(
        id: flare.id,
        authorUid: flare.authorUid,
        authorName: flare.authorName,
        postType: flare.postType,
        petType: flare.petType,
        petName: flare.petName,
        breed: flare.breed,
        age: flare.age,
        gender: flare.gender,
        description: flare.description,
        photoUrl: uploadedPhoto.url,
        latitude: flare.latitude,
        longitude: flare.longitude,
        address: flare.address,
        locationLabel: flare.locationLabel,
        dateTimeLost: flare.dateTimeLost,
        createdAt: flare.createdAt,
      );
    }

    final data = flareToSave.toMap();
    // Initialise counters on creation
    data['loveCount'] = 0;
    data['commentCount'] = 0;
    data['lovedBy'] = [];

    try {
      await docRef.set(data);
    } catch (_) {
      if (storagePath != null) {
        await _deleteStorageObjectBestEffort(storagePath);
      }
      rethrow;
    }

    await _geocodeSavedFlare(docRef, flareToSave.address);

    if (photoBytes != null && flareToSave.photoUrl != null) {
      try {
        await indexFlare(
          flareId: docRef.id,
          ownerId: flare.authorUid,
          species: flare.petType,
          imageUrl: flareToSave.photoUrl!,
          imageBytes: photoBytes,
          filename: photo!.name,
        );
      } catch (error) {
        debugPrint('Vector indexing failed for flare ${docRef.id}: $error');
        throw FlareIndexingException(docRef.id, error);
      }
    }
    return docRef.id;
  }

  Future<void> _geocodeSavedFlare(
    DocumentReference<Map<String, dynamic>> docRef,
    String address,
  ) async {
    try {
      final query = _normalizedBangladeshAddress(address);
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
          'countrycodes': 'bd',
          'addressdetails': '1',
          'accept-language': 'en',
        },
      );
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'ResQ-CSE327/1.0 (Flutter lost-pet application)',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Address lookup failed (${response.statusCode}).');
      }

      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) {
        throw StateError('No coordinates were found for this address.');
      }
      final location = results.first as Map<String, dynamic>;
      final latitude = double.tryParse(location['lat']?.toString() ?? '');
      final longitude = double.tryParse(location['lon']?.toString() ?? '');
      if (latitude == null || longitude == null) {
        throw StateError('The address service returned invalid coordinates.');
      }
      await docRef.update({
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (error) {
      throw FlareGeocodingException(docRef.id, error);
    }
  }

  /// Makes locally-written addresses less ambiguous for Android's native
  /// geocoder without changing the original address stored in Firestore.
  static String _normalizedBangladeshAddress(String address) {
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isNotEmpty) {
      parts[0] = parts[0].replaceFirst(
        RegExp(r'^road\s*[-#:]?\s*', caseSensitive: false),
        'Road ',
      );
    }
    if (parts.length > 1) {
      final blockFirst = RegExp(
        r'^([a-z0-9]+)\s+block$',
        caseSensitive: false,
      ).firstMatch(parts[1]);
      if (blockFirst != null) {
        parts[1] = 'Block ${blockFirst.group(1)}';
      }
    }

    for (var index = 0; index < parts.length; index++) {
      parts[index] = parts[index].replaceAll(
        RegExp(r'\br\s*/\s*a\b', caseSensitive: false),
        'Residential Area',
      );
    }

    final hasBangladesh = parts.any(
      (part) => part.toLowerCase() == 'bangladesh',
    );
    if (!hasBangladesh) parts.add('Bangladesh');
    return parts.join(', ');
  }

  /// Idempotently (re)indexes a Firestore Flare, keyed by its document ID.
  Future<void> indexFlare({
    required String flareId,
    required String ownerId,
    required String species,
    required String imageUrl,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    await _authBridge.ensureSupabaseRole();
    if (FirebaseAuth.instance.currentUser?.uid != ownerId) {
      throw StateError('Only the Flare owner may index this image.');
    }
    final embedding = await _embeddingService.embedImage(
      imageBytes: imageBytes,
      filename: filename,
    );
    PetSearchService.validateEmbedding(embedding);
    await _supabase.from('pets').upsert({
      'flare_id': flareId,
      'owner_id': ownerId,
      'species': species.trim().toLowerCase(),
      'image_url': imageUrl,
      'embedding': embedding,
    }, onConflict: 'flare_id');
  }

  Future<({String path, String url})> _uploadPhoto({
    required XFile photo,
    required Uint8List bytes,
    required String authorUid,
    required String flareId,
  }) async {
    if (bytes.isEmpty) throw StateError('The selected photo is empty.');
    if (bytes.length > _maxImageSizeBytes) {
      throw StateError('Flare photos must be 10 MB or smaller.');
    }

    final namedExtension = _extensionFromName(photo.name);
    final detectedExtension = _detectImageExtension(bytes);
    if (namedExtension == null || detectedExtension == null) {
      throw StateError(
        'Unsupported flare image format. Please select a JPEG, PNG, or WebP image.',
      );
    }
    final normalizedNamedExtension =
        namedExtension == 'jpeg' ? 'jpg' : namedExtension;
    if (normalizedNamedExtension != detectedExtension) {
      throw StateError(
        'The image contents do not match its file extension. '
        'Please select a valid JPEG, PNG, or WebP image.',
      );
    }
    final extension = detectedExtension;
    final path = '$authorUid/$flareId/${_uniqueFilename(extension)}';
    var uploaded = false;
    try {
      await _supabase.storage.from(_storageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeForExtension(extension),
              cacheControl: '3600',
              upsert: false,
            ),
          );
      uploaded = true;
      final url = _supabase.storage.from(_storageBucket).getPublicUrl(path);
      if (url.isEmpty) {
        throw StateError('Supabase returned an empty image URL.');
      }
      return (path: path, url: url);
    } catch (error) {
      if (uploaded) await _deleteStorageObjectBestEffort(path);
      throw StateError('Failed to upload flare image to Supabase: $error');
    }
  }

  Future<void> _deleteStorageObjectBestEffort(String path) async {
    try {
      await _supabase.storage.from(_storageBucket).remove([path]);
    } catch (error) {
      debugPrint('Could not clean up flare image "$path": $error');
    }
  }

  static String? _extensionFromName(String name) {
    final lastDot = name.lastIndexOf('.');
    if (lastDot < 0 || lastDot == name.length - 1) return null;
    final extension = name.substring(lastDot + 1).toLowerCase();
    return _contentTypes.containsKey(extension) ? extension : null;
  }

  static String? _detectImageExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  static String _uniqueFilename(String extension) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '$timestamp-$random.$extension';
  }

  static const Map<String, String> _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String _contentTypeForExtension(String extension) =>
      _contentTypes[extension] ?? 'image/jpeg';

  // ---------------------------------------------------------------------------
  // Read — single
  // ---------------------------------------------------------------------------

  /// Fetches a single flare by ID — for the flare-detail screen.
  Future<FlareModel?> getFlare(String id) async {
    final snapshot = await _flaresRef.doc(id).get();
    if (!snapshot.exists) return null;
    return FlareModel.fromMap(id, snapshot.data()!);
  }

  // ---------------------------------------------------------------------------
  // Read — feed streams
  // ---------------------------------------------------------------------------

  /// Real-time stream of ALL flares, newest first — for the global home feed.
  Stream<List<FlareModel>> watchAllFlares({int limit = 50}) {
    return _flaresRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FlareModel.fromMap(d.id, d.data())).toList());
  }

  /// Real-time stream of a single user's flares, newest first.
  ///
  /// Firestore requires a composite index when filtering by `authorUid`
  /// and ordering by `createdAt`. We instead fetch the filtered results
  /// and sort them client-side to avoid that index requirement.
  Stream<List<FlareModel>> watchUserFlares(String uid, {int limit = 50}) {
    return _flaresRef
        .where('authorUid', isEqualTo: uid)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final flares =
          snap.docs.map((d) => FlareModel.fromMap(d.id, d.data())).toList();
      flares.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return flares;
    });
  }

  /// One-shot fetch of recent flares (kept for backwards compat).
  Future<List<FlareModel>> getRecentFlares({int limit = 30}) async {
    final snapshot = await _flaresRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => FlareModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes a Flare from Firestore and removes its searchable/indexed assets.
  ///
  /// Cleanup is retry-safe. If Firestore was deleted but Supabase was
  /// temporarily unavailable, calling this method again removes the current
  /// user's `pets` row and everything under `{uid}/{flareId}/`.
  Future<void> deleteFlare(String flareId) async {
    final normalizedFlareId = flareId.trim();
    if (normalizedFlareId.isEmpty) {
      throw ArgumentError('flareId cannot be empty.');
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw StateError('You must be logged in to delete a Flare.');
    }

    // Establish Supabase access before making the irreversible Firestore
    // change. The remaining Supabase cleanup is independently retryable.
    await _authBridge.ensureSupabaseRole();

    final docRef = _flaresRef.doc(normalizedFlareId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final ownerId = snapshot.data()?['authorUid'] as String? ?? '';
      if (ownerId != currentUid) {
        throw StateError('Only the Flare owner may delete this post.');
      }
      await docRef.delete();
    }

    final cleanupErrors = <Object>[];
    try {
      await _supabase.from('pets').delete().eq('flare_id', normalizedFlareId);
    } catch (error) {
      cleanupErrors.add(error);
      debugPrint('Could not delete vector row for $normalizedFlareId: $error');
    }

    try {
      await _deleteFlareStorageFolder(
        ownerId: currentUid,
        flareId: normalizedFlareId,
      );
    } catch (error) {
      cleanupErrors.add(error);
      debugPrint('Could not delete images for $normalizedFlareId: $error');
    }

    if (cleanupErrors.isNotEmpty) {
      throw FlareDeletionCleanupException(normalizedFlareId, cleanupErrors);
    }
  }

  Future<void> _deleteFlareStorageFolder({
    required String ownerId,
    required String flareId,
  }) async {
    final prefix = '$ownerId/$flareId';
    final objects =
        await _supabase.storage.from(_storageBucket).list(path: prefix);
    if (objects.isEmpty) return;
    final paths = objects
        .where((object) => object.name.isNotEmpty)
        .map((object) => '$prefix/${object.name}')
        .toList(growable: false);
    if (paths.isNotEmpty) {
      await _supabase.storage.from(_storageBucket).remove(paths);
    }
  }

  // ---------------------------------------------------------------------------
  // Love / Heart reaction
  // ---------------------------------------------------------------------------

  /// Toggles the love reaction for [uid] on [flareId].
  ///
  /// - If [currentlyLoved] is false  → adds uid to `lovedBy`, increments `loveCount`.
  /// - If [currentlyLoved] is true   → removes uid from `lovedBy`, decrements `loveCount`.
  ///
  /// Uses a Firestore transaction so count and array stay consistent.
  Future<void> toggleLove(
      String flareId, String uid, bool currentlyLoved) async {
    final docRef = _flaresRef.doc(flareId);
    await _flaresRef.firestore.runTransaction((tx) async {
      if (currentlyLoved) {
        tx.update(docRef, {
          'lovedBy': FieldValue.arrayRemove([uid]),
          'loveCount': FieldValue.increment(-1),
        });
      } else {
        tx.update(docRef, {
          'lovedBy': FieldValue.arrayUnion([uid]),
          'loveCount': FieldValue.increment(1),
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Comments sub-collection
  // ---------------------------------------------------------------------------

  /// Real-time stream of comments for a flare, oldest first.
  Stream<List<CommentModel>> watchComments(String flareId) {
    return _flaresRef
        .doc(flareId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommentModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Ensures every flare document authored by [uid] has a non-empty
  /// `authorName` field. This is used to backfill older documents that
  /// were created before `authorName` was recorded on creation.
  Future<void> ensureAuthorNameForUid(String uid) async {
    final usersSvc = FirestoreService();
    final profile = await usersSvc.getUserProfile(uid);
    final fullName = profile?.fullName ?? '';
    if (fullName.isEmpty) return;

    final query = await _flaresRef.where('authorUid', isEqualTo: uid).get();
    if (query.docs.isEmpty) return;

    final batch = _flaresRef.firestore.batch();
    var updates = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      final existing = (data['authorName'] as String?) ?? '';
      if (existing != fullName) {
        batch.update(doc.reference, {'authorName': fullName});
        updates += 1;
      }
    }
    if (updates > 0) await batch.commit();
  }

  /// Adds a new comment and increments the `commentCount` on the parent
  /// flare document — done in a batch so both writes succeed or fail together.
  Future<void> addComment(String flareId, CommentModel comment) async {
    final batch = _flaresRef.firestore.batch();

    // Write the comment document
    final commentRef = _flaresRef.doc(flareId).collection('comments').doc();
    batch.set(commentRef, comment.toMap());

    // Increment the counter on the parent flare
    batch.update(_flaresRef.doc(flareId), {
      'commentCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}

class FlareIndexingException implements Exception {
  final String flareId;
  final Object cause;
  const FlareIndexingException(this.flareId, this.cause);

  @override
  String toString() =>
      'Flare $flareId was posted, but AI indexing failed and can be retried: $cause';
}

class FlareGeocodingException implements Exception {
  final String flareId;
  final Object cause;
  const FlareGeocodingException(this.flareId, this.cause);

  @override
  String toString() =>
      'Flare $flareId was saved, but its address could not be geocoded: $cause';
}

class FlareDeletionCleanupException implements Exception {
  final String flareId;
  final List<Object> causes;
  const FlareDeletionCleanupException(this.flareId, this.causes);

  @override
  String toString() =>
      'Flare $flareId was removed from Firestore, but ${causes.length} '
      'Supabase cleanup operation(s) failed. Calling deleteFlare again is safe.';
}

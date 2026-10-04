import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_supabase_bridge_service.dart';
import 'huggingface_service.dart';

/// One minimal row returned by the Supabase vector-search index.
class Pet {
  final String id;
  final String flareId;
  final String ownerId;
  final String species;
  final String imageUrl;
  final double? score;

  const Pet(
      {required this.id,
      required this.flareId,
      required this.ownerId,
      required this.species,
      required this.imageUrl,
      this.score});

  factory Pet.fromMap(Map<String, dynamic> map, {double? score}) => Pet(
        id: _requiredString(map, 'id'),
        flareId: _requiredString(map, 'flare_id'),
        ownerId: _requiredString(map, 'owner_id'),
        species: _requiredString(map, 'species').toLowerCase(),
        imageUrl: _requiredString(map, 'image_url'),
        score: score ?? _similarity(map['similarity']),
      );

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw FormatException('Missing required field: $key');
    return value;
  }

  static double? _similarity(dynamic value) {
    if (value is num) return value.toDouble();
    return value == null ? null : double.tryParse(value.toString());
  }
}

/// Generates query embeddings and calls the minimal Supabase search RPC.
class PetSearchService {
  static const int embeddingDimension = HuggingFaceService.embeddingDimension;
  static const int maxImageSizeBytes = 10 * 1024 * 1024;

  final SupabaseClient _supabase;
  final HuggingFaceService _embeddingService;
  final FirebaseSupabaseBridgeService _authBridge;

  PetSearchService(
      {SupabaseClient? supabaseClient,
      HuggingFaceService? huggingFaceService,
      FirebaseSupabaseBridgeService? authBridge})
      : _supabase = supabaseClient ?? Supabase.instance.client,
        _embeddingService = huggingFaceService ?? HuggingFaceService(),
        _authBridge = authBridge ?? FirebaseSupabaseBridgeService();

  Future<List<Pet>> searchSimilarPets(
      {required File queryImage,
      required String targetSpecies,
      double minSimilarityThreshold = .5,
      int limit = 30}) async {
    await _authBridge.ensureSupabaseRole();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('You must be logged in to search.');
    if (!await queryImage.exists()) throw StateError('Query image not found.');
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    if (minSimilarityThreshold < 0 || minSimilarityThreshold > 1) {
      throw ArgumentError.value(
          minSimilarityThreshold, 'minSimilarityThreshold');
    }
    final species = targetSpecies.trim().toLowerCase();
    if (species.isEmpty) throw ArgumentError('Target species cannot be empty.');
    final bytes = await queryImage.readAsBytes();
    if (bytes.isEmpty) throw StateError('Query image is empty.');
    if (bytes.length > maxImageSizeBytes) {
      throw StateError('Query image must be 10 MB or smaller.');
    }

    final embedding = await _embeddingService.embedImage(
        imageBytes: bytes, filename: queryImage.uri.pathSegments.last);
    validateEmbedding(embedding);
    final dynamic response = await _supabase.rpc('match_pets', params: {
      'query_embedding': embedding,
      'match_species': species,
      'match_threshold': minSimilarityThreshold,
      'match_count': limit,
      // Preserve existing behaviour: do not match the user's own posts.
      'exclude_owner_id': user.uid,
    });
    if (response == null) return const [];
    if (response is! List)
      throw FormatException('Unexpected match_pets response.');

    final matches = <Pet>[];
    for (final row in response) {
      try {
        if (row is! Map) throw const FormatException('RPC row is not a map.');
        final pet = Pet.fromMap(Map<String, dynamic>.from(row));
        // Defence in depth; exactly 50% remains included.
        if ((pet.score ?? -1) >= minSimilarityThreshold) matches.add(pet);
      } catch (error) {
        debugPrint('Skipping malformed match_pets row: $error');
      }
    }
    matches.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    return matches;
  }

  static void validateEmbedding(List<double> embedding) {
    if (embedding.length != embeddingDimension ||
        embedding.any((value) => !value.isFinite)) {
      throw StateError(
          'Expected a finite $embeddingDimension-dimensional embedding.');
    }
  }
}

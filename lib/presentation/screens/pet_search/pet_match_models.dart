import '../../../database/models/flare_model.dart';
import '../../../database/models/user_model.dart';
import '../../../database/services/pet_search_service.dart';

/// A vector-index hit enriched with authoritative Firebase data.
class PetMatchResult {
  const PetMatchResult(
      {required this.id,
      required this.flareId,
      required this.ownerId,
      required this.imageUrl,
      required this.similarity,
      required this.pet,
      required this.uploader});

  final String id, flareId, ownerId, imageUrl;
  final double similarity;
  final PetMatchPet pet;
  final PetMatchUploader uploader;

  int get similarityPercent => (similarity.clamp(0.0, 1.0) * 100).round();

  factory PetMatchResult.fromPet(Pet hit,
      {FlareModel? flare, UserModel? user}) {
    final authoritativeImage = flare?.photoUrl;
    return PetMatchResult(
      id: hit.id,
      flareId: hit.flareId,
      ownerId:
          flare?.authorUid.isNotEmpty == true ? flare!.authorUid : hit.ownerId,
      imageUrl: authoritativeImage?.isNotEmpty == true
          ? authoritativeImage!
          : hit.imageUrl,
      similarity: hit.score ?? 0,
      pet: PetMatchPet(
        name: flare?.petName ?? 'Unnamed pet',
        species: flare?.petType ?? hit.species,
        breed: flare?.breed ?? 'Breed unavailable',
        location: flare?.locationLabel ?? 'Location unavailable',
        gender: flare?.gender,
        age: flare?.age,
        lastSeen: flare?.dateTimeLost.toLocal().toString().split('.').first,
        note: flare?.description,
      ),
      uploader: PetMatchUploader(
        name: user?.fullName ?? flare?.authorName ?? 'Uploader unavailable',
        phone: user?.phone,
        email: user?.email,
      ),
    );
  }
}

class PetMatchPet {
  const PetMatchPet(
      {required this.name,
      required this.species,
      required this.breed,
      required this.location,
      this.color,
      this.gender,
      this.age,
      this.lastSeen,
      this.note});
  final String name, species, breed, location;
  final String? color, gender, age, lastSeen, note;
}

class PetMatchUploader {
  const PetMatchUploader(
      {required this.name,
      this.phone,
      this.email,
      this.location,
      this.avatarUrl,
      this.isVerified = false});
  final String name;
  final String? phone, email, location, avatarUrl;
  final bool isVerified;
}

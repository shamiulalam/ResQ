/// Whether a feed post is reporting a lost pet or a spotted stray.
enum PostType { lost, spotted }

/// A single post in the home feed.
///
/// NOTE: this is a local, UI-only model with mock data for now. Once the
/// "posters" and "sightings" Firestore collections are built (see
/// backend/routers + the proposal's data model), this will be replaced
/// by data read from Firestore via a PetRepository, following the same
/// pattern as UserModel in database/models/user_model.dart.
class FeedPostModel {
  final String id;
  final String authorName;
  final DateTime postedAt;
  final PostType type;
  final String petSpecies;
  final String caption;
  final String location;
  final int commentCount;

  const FeedPostModel({
    required this.id,
    required this.authorName,
    required this.postedAt,
    required this.type,
    required this.petSpecies,
    required this.caption,
    required this.location,
    required this.commentCount,
  });
}

/// Temporary mock feed data so the Home screen is fully scrollable and
/// visually complete before real posts exist.
List<FeedPostModel> mockFeedPosts() {
  final now = DateTime.now();
  return [
    FeedPostModel(
      id: '1',
      authorName: 'Sarah Ahmed',
      postedAt: now.subtract(const Duration(minutes: 12)),
      type: PostType.lost,
      petSpecies: 'Dog · Golden Retriever',
      caption: 'Max ran off near the park during our evening walk. He\'s '
          'friendly but scared right now — please don\'t chase, just call this number!',
      location: 'Dhanmondi, Dhaka',
      commentCount: 4,
    ),
    FeedPostModel(
      id: '2',
      authorName: 'Tanvir Rahman',
      postedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      type: PostType.spotted,
      petSpecies: 'Cat · Tabby',
      caption: 'Saw this cat wandering near the market for the past two days. '
          'Looks well-fed but no collar. Anyone missing her?',
      location: 'Mohammadpur, Dhaka',
      commentCount: 2,
    ),
    FeedPostModel(
      id: '3',
      authorName: 'Nusrat Jahan',
      postedAt: now.subtract(const Duration(hours: 5)),
      type: PostType.lost,
      petSpecies: 'Dog · Mixed breed',
      caption: 'Our dog Rocky slipped out of his collar this morning. '
          'Last seen heading toward the school gate.',
      location: 'Uttara Sector 7, Dhaka',
      commentCount: 9,
    ),
    FeedPostModel(
      id: '4',
      authorName: 'Imran Kabir',
      postedAt: now.subtract(const Duration(hours: 8)),
      type: PostType.spotted,
      petSpecies: 'Dog · Terrier mix',
      caption: 'Small terrier hanging around the tea stall since this '
          'afternoon, seems lost and a bit nervous around people.',
      location: 'Banani, Dhaka',
      commentCount: 1,
    ),
  ];
}

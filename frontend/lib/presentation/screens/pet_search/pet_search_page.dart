import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../database/services/pet_search_service.dart';
import '../../../database/services/flare_service.dart';
import '../../../database/services/firestore_service.dart';
import '../../widgets/app_background.dart';
import 'pet_match_details_screen.dart';
import 'pet_match_models.dart';
import 'pet_match_widgets.dart';

/// Search UI for an uploaded image. Results come from [PetSearchService], not
/// from widget-owned sample data, and are ready to be replaced by a repository.
class PetMatchSearchScreen extends StatefulWidget {
  const PetMatchSearchScreen({super.key, this.searchService});
  final PetSearchService? searchService;
  @override
  State<PetMatchSearchScreen> createState() => _PetMatchSearchScreenState();
}

class _PetMatchSearchScreenState extends State<PetMatchSearchScreen> {
  late final PetSearchService _service =
      widget.searchService ?? PetSearchService();
  final _picker = ImagePicker();
  File? _searchImage;
  bool _loading = false;
  bool _hasSearched = false;
  String _species = 'dog';
  List<PetMatchResult> _matches = const [];

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
        source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    if (image == null || !mounted) return;
    setState(() {
      _searchImage = File(image.path);
      _matches = const [];
      _hasSearched = false;
    });
  }

  Future<void> _chooseImage() async {
    await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  }),
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  }),
            ])));
  }

  Future<void> _findMatches() async {
    if (_searchImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a search image first.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final pets = await _service.searchSimilarPets(
          queryImage: _searchImage!,
          targetSpecies: _species,
          minSimilarityThreshold: .50,
          limit: 30);
      // Do not initialize Firebase-backed repositories merely by opening this
      // screen. They are only needed once Supabase has returned match IDs.
      final flareService = FlareService();
      final usersService = FirestoreService();
      final matches = (await Future.wait(pets.map((hit) async {
        final flare = await flareService.getFlare(hit.flareId);
        if (flare == null) return null;
        final uploader = await usersService.getUserProfile(flare.authorUid);
        return PetMatchResult.fromPet(hit, flare: flare, user: uploader);
      })))
          .whereType<PetMatchResult>()
          .where((match) => match.similarity >= .50)
          .toList()
        ..sort((a, b) => b.similarity.compareTo(a.similarity));
      if (mounted) {
        setState(() {
          _matches = matches;
          _hasSearched = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Search failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return AppBackground(
        showWatermark: false,
        child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Pet Match Search'), actions: [
              IconButton(
                  onPressed: _chooseImage, icon: const Icon(Icons.tune_rounded))
            ]),
            body: Stack(children: [
              ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SearchImagePanel(
                        image: _searchImage, onPick: _chooseImage),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _species,
                            dropdownColor: ext.cardBackground,
                            decoration: const InputDecoration(
                              labelText: 'Pet type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'dog',
                                child: Text('Dog'),
                              ),
                              DropdownMenuItem(
                                value: 'cat',
                                child: Text('Cat'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _species = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _searchImage == null ? null : _findMatches,
                              icon: const Icon(Icons.search),
                              label: const Text('Find Matches'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_hasSearched)
                      _SearchPrompt(hasImage: _searchImage != null)
                    else if (_matches.isEmpty)
                      const _NoMatchesFound()
                    else ...[
                      for (final match in _matches) ...[
                        MatchResultCard(
                            match: match,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => PetMatchDetailsScreen(
                                        searchImage: _searchImage!,
                                        match: match)))),
                        const SizedBox(height: 9)
                      ],
                    ],
                    if (_hasSearched) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Showing top matches above 50% similarity',
                          style:
                              TextStyle(color: ext.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ]),
              if (_loading)
                const Positioned.fill(
                    child: ColoredBox(
                        color: Color(0x99050A0D),
                        child: Center(child: CircularProgressIndicator()))),
            ])));
  }
}

class _SearchImagePanel extends StatelessWidget {
  const _SearchImagePanel({required this.image, required this.onPick});
  final File? image;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
        height: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ext.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Searching with this image',
              style: TextStyle(
                  color: ext.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Left — image
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 178,
                    child: MatchImage(
                      file: image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Right — camera exactly centered
                Expanded(
                  child: Center(
                    child: InkWell(
                      onTap: onPick,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ext.accentOrange,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]));
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({required this.hasImage});
  final bool hasImage;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ext.cardBorder)),
        child: Column(children: [
          Text('Ready to find a match?',
              style: TextStyle(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          const SizedBox(height: 8),
          Text(
              hasImage
                  ? 'Press Find Matches to search the database.'
                  : 'Choose a photo above to start searching.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ext.textSecondary, fontSize: 12)),
        ]));
  }
}

class _NoMatchesFound extends StatelessWidget {
  const _NoMatchesFound();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ext.cardBorder),
      ),
      child: Column(children: [
        Icon(Icons.search_off_rounded, color: ext.accentOrange, size: 42),
        const SizedBox(height: 10),
        Text('No match found',
            style: TextStyle(
                color: ext.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Try another clear photo or pet type.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ext.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

/// Compatibility name for existing imports while callers migrate.
typedef PetSearchPage = PetMatchSearchScreen;

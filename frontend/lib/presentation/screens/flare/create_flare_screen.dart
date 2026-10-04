import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/models/flare_model.dart';
import '../../../database/services/auth_service.dart';
import '../../../database/services/flare_service.dart';
import '../../../database/services/firestore_service.dart';
import '../../widgets/app_background.dart';
import 'flare_models.dart';
import 'widgets/flare_field.dart';
import 'widgets/flare_header.dart';
import 'widgets/flare_photo_section.dart';
import 'widgets/flare_publish_button.dart';

class CreateFlareScreen extends StatefulWidget {
  const CreateFlareScreen({super.key});

  @override
  State<CreateFlareScreen> createState() => _CreateFlareScreenState();
}

class _CreateFlareScreenState extends State<CreateFlareScreen> {
  PostType _postType = PostType.lost;
  PetType _petType = PetType.dog;

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  final _authService = AuthService();
  final _flareService = FlareService();
  final _usersSvc = FirestoreService();

  String? _gender;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double get _uploadProgress {
    if (_photos.isEmpty) return 0;
    final v = _photos.length / 5;
    return v > 1 ? 1 : v;
  }

  Future<void> _pickDateTime() async {
    await showFlareDateTimePicker(
      context: context,
      initialDate: _selectedDate,
      initialTime: _selectedTime,
      onSelected: (date, time) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only one photo allowed')),
      );
      return;
    }

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _photos.add(file));
  }

  void _showAddPhotoSheet() {
    showFlarePhotoSourceSheet(
      context,
      onGallery: () => _pickPhoto(ImageSource.gallery),
      onCamera: () => _pickPhoto(ImageSource.camera),
    );
  }

  Future<void> _handlePost() async {
    if (_nameController.text.trim().isEmpty ||
        _breedController.text.trim().isEmpty ||
        _ageController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _gender == null ||
        _photos.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields and add a photo'),
        ),
      );
      return;
    }

    final address = _addressController.text.trim();
    final addressParts = address.split(',').map((part) => part.trim()).toList();
    if (addressParts.length != 4 || addressParts.any((part) => part.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter address as: road no, block no, area, city'),
        ),
      );
      return;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post a flare')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateTimeLost = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final user = _authService.currentUser;
      // Prefer authoritative profile values from the users collection.
      final profile = await _usersSvc.getUserProfile(uid);
      final authorName = profile?.fullName ??
          user?.displayName ??
          user?.email?.split('@').first ??
          'ResQ User';

      final flare = FlareModel(
        id: '',
        authorUid: uid,
        authorName: authorName,
        postType: _postType.name,
        petType: _petType.name,
        petName: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        age: _ageController.text.trim(),
        gender: _gender!,
        description: _descriptionController.text.trim(),
        latitude: 0,
        longitude: 0,
        address: address,
        locationLabel: address,
        dateTimeLost: dateTimeLost,
        createdAt: DateTime.now(),
      );

      await _flareService.createFlare(flare, photo: _photos.first);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flare posted!')),
      );
      Navigator.of(context).maybePop();
    } on FlareGeocodingException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Flare saved'),
          content: Text(
            'The address was saved, but its coordinates could not be generated. '
            'Please contact support instead of posting it again.\n\n'
            'Flare ID: ${error.flareId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
    } on FlareIndexingException catch (error) {
      if (!mounted) return;
      await _handleIndexingFailure(error);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post flare: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleIndexingFailure(FlareIndexingException error) async {
    final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Flare posted successfully'),
            content: const Text(
              'Your Flare is live, but AI search indexing failed. '
              'You can retry indexing now without creating another Flare.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Done'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry indexing'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!shouldRetry) {
      Navigator.of(context).maybePop();
      return;
    }

    try {
      final savedFlare = await _flareService.getFlare(error.flareId);
      final photo = _photos.first;
      if (savedFlare == null || savedFlare.photoUrl?.isNotEmpty != true) {
        throw StateError(
            'The posted Flare or its image URL could not be loaded.');
      }
      await _flareService.indexFlare(
        flareId: error.flareId,
        ownerId: savedFlare.authorUid,
        species: savedFlare.petType,
        imageUrl: savedFlare.photoUrl!,
        imageBytes: await photo.readAsBytes(),
        filename: photo.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI search indexing completed.')),
      );
    } catch (retryError) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Flare posted successfully'),
          content: Text(
            'AI search indexing still failed. Your Flare remains live.\n\n'
            'Flare ID: ${error.flareId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
              children: [
                FlareHeader(
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FlarePostTypeRow(
                          value: _postType,
                          uploadProgress: _uploadProgress,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _postType = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        FlarePhotoSection(
                          photos: _photos,
                          petType: _petType,
                          onAddPhoto: _showAddPhotoSheet,
                          onRemovePhoto: (file) {
                            setState(() => _photos.remove(file));
                          },
                          onPetTypeChanged: (type) {
                            setState(() => _petType = type);
                          },
                        ),
                        const SizedBox(height: 12),
                        const FlareSectionTitle(title: 'Pet Details'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FlareInlineField(
                                label: 'Pet Name',
                                controller: _nameController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlareInlineField(
                                label: 'Breed',
                                controller: _breedController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FlareGenderDropdown(
                                value: _gender,
                                onChanged: (value) {
                                  setState(() => _gender = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlareInlineField(
                                label: 'Age',
                                controller: _ageController,
                                keyboardType: TextInputType.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FlareInlineField(
                          label: 'Anything to say?',
                          controller: _descriptionController,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        const FlareSectionTitle(title: 'Location & Time'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FlareInlineField(
                                label: 'Address',
                                controller: _addressController,
                                hintText: 'Road no, block no, area, city',
                                maxLines: 3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlareDateTimeCard(
                                date: _selectedDate,
                                time: _selectedTime,
                                onTap: _pickDateTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        FlarePublishButton(
                          isSubmitting: _isSubmitting,
                          onPressed: _handlePost,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

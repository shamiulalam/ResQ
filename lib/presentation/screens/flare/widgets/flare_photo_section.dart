import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import 'flare_field.dart';

/// Horizontal photo strip with add button, paired with pet type selector.
class FlarePhotoSection extends StatelessWidget {
  final List<XFile> photos;
  final PetType petType;
  final VoidCallback onAddPhoto;
  final void Function(XFile) onRemovePhoto;
  final ValueChanged<PetType> onPetTypeChanged;

  const FlarePhotoSection({
    super.key,
    required this.photos,
    required this.petType,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onPetTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...photos.map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(file.path),
                            width: 86,
                            height: 86,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemovePhoto(file),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onAddPhoto,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 98,
                    height: 86,
                    decoration: BoxDecoration(
                      color: ext.fieldFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ext.fieldBorder),
                    ),
                    child: Center(
                      child: Text(
                        '+ PET PHOTO',
                        style: TextStyle(
                          color: ext.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PetTypeSelector(
            selected: petType,
            onChanged: onPetTypeChanged,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for choosing camera or gallery.
void showFlarePhotoSourceSheet(
  BuildContext context, {
  required VoidCallback onGallery,
  required VoidCallback onCamera,
}) {
  final ext = Theme.of(context).extension<ResQThemeExtension>()!;
  showModalBottomSheet(
    context: context,
    backgroundColor: ext.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ext.fieldBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: ext.textPrimary),
            title: Text(
              'Choose from gallery',
              style: TextStyle(color: ext.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              onGallery();
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: ext.textPrimary),
            title: Text(
              'Take photo',
              style: TextStyle(color: ext.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              onCamera();
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

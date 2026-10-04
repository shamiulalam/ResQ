import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../flare_models.dart';
import 'flare_decorations.dart';

import '../../../../core/theme/app_theme.dart';

/// Section heading used for "Pet Details" and "Location & Time".
class FlareSectionTitle extends StatelessWidget {
  final String title;

  const FlareSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Text(
      title,
      style: TextStyle(
        color: ext.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Post type row at the top of the posting page — label + dropdown + upload ring.
class FlarePostTypeRow extends StatelessWidget {
  final PostType value;
  final double uploadProgress;
  final ValueChanged<PostType?> onChanged;

  const FlarePostTypeRow({
    super.key,
    required this.value,
    required this.uploadProgress,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final progressText = '${(uploadProgress * 100).round()}%';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 140,
          height: 78,
          child: FlarePostTypeDropdown(
            value: value,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 14),
        Transform.translate(
          offset: const Offset(
              130, -10), // Move right by 30 pixels, up by 10 pixels
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: uploadProgress,
                  strokeWidth: 5,
                  backgroundColor: ext.fieldBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ext.accentOrange,
                  ),
                ),
                Text(
                  progressText,
                  style: TextStyle(
                    color: ext.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Post type dropdown (Lost / Spotted / General) with "Post Type" label.
class FlarePostTypeDropdown extends StatelessWidget {
  final PostType value;
  final ValueChanged<PostType?> onChanged;

  const FlarePostTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 4),
      decoration: flareFieldBox(ext: ext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Post Type',
            style: TextStyle(
              color: ext.textSecondary,
              fontSize: 11,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<PostType>(
              value: value,
              isExpanded: true,
              dropdownColor: ext.cardBackground,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ext.accentOrange,
                size: 20,
              ),
              style: TextStyle(
                color: ext.inputTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              items: PostType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline text field with label stacked inside the box.
class FlareInlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final Widget? trailing;
  final TextInputType keyboardType;
  final String? hintText;

  const FlareInlineField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.trailing,
    this.keyboardType = TextInputType.text,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: flareFieldBox(ext: ext),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ext.textSecondary,
                    fontSize: 11,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: TextStyle(
                    color: ext.inputTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    hintStyle: TextStyle(color: ext.hintText, fontSize: 12),
                    contentPadding: const EdgeInsets.only(top: 2, bottom: 0),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

/// Gender dropdown — starts unset with "Select" placeholder.
class FlareGenderDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const FlareGenderDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _options = ['Female', 'Male'];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 4),
      decoration: flareFieldBox(ext: ext),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gender',
            style: TextStyle(
              color: ext.textSecondary,
              fontSize: 11,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              value: value,
              hint: Text(
                'Select',
                style: TextStyle(
                  color: ext.hintText,
                  fontSize: 13,
                ),
              ),
              isExpanded: true,
              dropdownColor: ext.cardBackground,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ext.accentOrange,
                size: 20,
              ),
              style: TextStyle(
                color: ext.inputTextColor,
                fontSize: 13,
              ),
              items: _options
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text(g)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-based pet type selector (Dog / Cat / Bird).
enum PetType { dog, cat, bird }

extension PetTypeLabel on PetType {
  String get label {
    switch (this) {
      case PetType.dog:
        return 'Dog';
      case PetType.cat:
        return 'Cat';
      case PetType.bird:
        return 'Bird';
    }
  }

  IconData get icon {
    switch (this) {
      case PetType.dog:
        return Icons.pets_outlined;
      case PetType.cat:
        return Icons.cruelty_free_outlined;
      case PetType.bird:
        return Icons.flutter_dash;
    }
  }
}

class PetTypeSelector extends StatelessWidget {
  final PetType selected;
  final ValueChanged<PetType> onChanged;

  const PetTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(50, -8),
          child: Text(
            'Pet Type',
            style: TextStyle(
              color: ext.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: PetType.values.map((type) {
            final isSelected = type == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: ext.fieldFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isSelected ? ext.accentOrange : ext.fieldBorder,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      ext.accentOrange.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        type.icon,
                        color:
                            isSelected ? ext.accentOrange : ext.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: ext.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Tappable mini-map preview using real OpenStreetMap tiles.
class FlareMiniMapCard extends StatelessWidget {
  final LatLng location;
  final String locationLabel;
  final VoidCallback onTap;

  const FlareMiniMapCard({
    super.key,
    required this.location,
    required this.locationLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        decoration: flareFieldBox(ext: ext),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.resq',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 32,
                        height: 32,
                        point: location,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 30,
                          color: AppColors.flareMapPin,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.flareMapPin,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date & time card — shows "Tap to select" until both are chosen.
class FlareDateTimeCard extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const FlareDateTimeCard({
    super.key,
    required this.date,
    required this.time,
    required this.onTap,
  });

  String _label(BuildContext context) {
    if (date == null || time == null) return 'Tap to select';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date!.month - 1]} ${date!.day} • ${time!.format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = date != null && time != null;
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: flareFieldBox(ext: ext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date & Time Lost',
              style: TextStyle(
                color: ext.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                _label(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasSelection ? ext.inputTextColor : ext.hintText,
                  fontSize: 13,
                  fontWeight: hasSelection ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Themed date/time picker dialogs matching the flare dark palette.
Future<void> showFlareDateTimePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required TimeOfDay? initialTime,
  required void Function(DateTime date, TimeOfDay time) onSelected,
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: DateTime(now.year - 1),
    lastDate: now,
    builder: (context, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.flareGradientStart,
          surface: AppColors.flareSurface,
        ),
      ),
      child: child!,
    ),
  );
  if (!context.mounted || date == null) return;

  final time = await showTimePicker(
    context: context,
    initialTime: initialTime ?? TimeOfDay.now(),
    builder: (context, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.flareGradientStart,
          surface: AppColors.flareSurface,
        ),
      ),
      child: child!,
    ),
  );
  if (!context.mounted || time == null) return;

  onSelected(date, time);
}

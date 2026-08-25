import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'pet_match_models.dart';

class MatchImage extends StatelessWidget {
  const MatchImage({super.key, this.file, this.imageUrl, required this.fit});
  final File? file;
  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Image.file(file!,
          fit: fit, width: double.infinity, height: double.infinity);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(imageUrl!,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const _ImageFallback());
    }
    return const _ImageFallback();
  }
}

class MatchResultCard extends StatelessWidget {
  const MatchResultCard({super.key, required this.match, required this.onTap});
  final PetMatchResult match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Material(
      color: ext.cardBackground,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ext.cardBorder)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: SizedBox(
            height: 88,
            child: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                      width: 88,
                      height: 88,
                      child: MatchImage(
                          imageUrl: match.imageUrl, fit: BoxFit.cover))),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(match.pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: ext.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(match.pet.breed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: ext.textSecondary, fontSize: 12)),
                    const SizedBox(height: 7),
                    Row(children: [
                      Icon(Icons.location_on_rounded,
                          color: ext.accentOrange, size: 15),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(match.pet.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: ext.textSecondary, fontSize: 11)))
                    ]),
                  ])),
              SizedBox(
                  width: 78,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PercentageBadge(value: match.similarityPercent),
                        const SizedBox(height: 10),
                        Text('View details  ›',
                            style: TextStyle(
                                color: ext.accentOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PercentageBadge extends StatelessWidget {
  const _PercentageBadge({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
            color: const Color(0xFF06777B),
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(color: Color(0x3308B8BC), blurRadius: 8)
            ]),
        child: Text('$value%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700)));
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => Container(
      color: const Color(0xFF132126),
      child: const Center(
          child: Icon(Icons.pets_rounded, color: Color(0xFF6E858A), size: 32)));
}

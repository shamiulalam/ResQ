import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../database/models/flare_model.dart';
import '../../../../database/services/flare_service.dart';
import 'post_card.dart';

/// The scrollable newsfeed shown on the Home tab.
///
/// Streams the current user's own flares from Firestore in real time,
/// newest first. Pass [scrollController] from [HomeScreen] so the
/// parent can detect scroll direction for bottom-nav hide/show.
class HomeFeedTab extends StatefulWidget {
  final ScrollController scrollController;

  const HomeFeedTab({super.key, required this.scrollController});

  @override
  State<HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<HomeFeedTab> {
  final _flareService = FlareService();

  // Cached once so identity stays stable across rebuilds. If this were
  // created inline inside build() (e.g. `stream: _flareService.watchUserFlares(uid)`),
  // every parent rebuild — including the ones triggered by HomeScreen's
  // scroll listener toggling nav visibility — would hand StreamBuilder a
  // *new* Stream object. StreamBuilder treats that as a different stream,
  // cancels the old subscription, resubscribes, and briefly falls back to
  // ConnectionState.waiting — which is what caused the flicker/"blink"
  // while scrolling.
  Stream<List<FlareModel>>? _flaresStream;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) {
      _flaresStream = _flareService.watchUserFlares(uid);
      // Backfill authorName for existing flares belonging to the current user.
      // Fire-and-forget: improves existing documents without blocking UI.
      _flareService.ensureAuthorNameForUid(uid).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null || _flaresStream == null) {
      return const Center(
        child: Text(
          'Please log in to see your posts.',
          style: TextStyle(color: AppColors.flareTextSecondary),
        ),
      );
    }

    return StreamBuilder<List<FlareModel>>(
      stream: _flaresStream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.flareAccentOrange,
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.flareTextSecondary),
                const SizedBox(height: 12),
                Text(
                  'Something went wrong:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.flareTextSecondary),
                ),
              ],
            ),
          );
        }

        final flares = snapshot.data ?? [];

        // Empty state
        if (flares.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.flareCardBackground,
                    border: Border.all(
                        color:
                            AppColors.flareAccentOrange.withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    size: 44,
                    color: AppColors.flareAccentOrange,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No flares yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap ＋ to report a lost or spotted pet.',
                  style: TextStyle(
                    color: AppColors.flareTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Feed list
        return RefreshIndicator(
          color: AppColors.flareAccentOrange,
          backgroundColor:
              AppColors.flareCardBackground.withValues(alpha: 0.18),
          onRefresh: () async {
            // StreamBuilder auto-refreshes; this just gives haptic feedback.
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            physics: const ClampingScrollPhysics(),
            itemCount: flares.length,
            itemBuilder: (context, index) {
              final flare = flares[index];
              return PostCard(
                key: ValueKey(flare.id),
                flare: flare,
              );
            },
          ),
        );
      },
    );
  }
}

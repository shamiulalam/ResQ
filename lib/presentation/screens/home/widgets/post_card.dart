import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../database/models/flare_model.dart';
import '../../../../database/services/flare_service.dart';
import '../../../../database/services/firestore_service.dart';
import '../comments_screen.dart';

/// A single card in the Home feed, built from a real [FlareModel].
///
/// Dark-themed to match the AppBackground palette.
/// Features:
///  - Author row with type badge (LOST / SPOTTED)
///  - Full post photo (base64) or a styled placeholder
///  - Pet name + description
///  - Love (heart) reaction with animated toggle
///  - Comment button → pushes CommentsScreen
///  - Share button (stub)
class PostCard extends StatefulWidget {
  final FlareModel flare;

  const PostCard({super.key, required this.flare});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  final _flareService = FlareService();
  late bool _loved;
  late int _loveCount;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  Uint8List? _photoBytes;
  String? _resolvedAuthorName;
  final _usersSvc = FirestoreService();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String get _displayAuthorName {
    if (widget.flare.authorName.isNotEmpty) {
      return widget.flare.authorName;
    }
    if (_currentUid == widget.flare.authorUid) {
      final user = FirebaseAuth.instance.currentUser;
      return user?.displayName ?? user?.email?.split('@').first ?? 'ResQ User';
    }
    return 'ResQ User';
  }

  @override
  void initState() {
    super.initState();
    _loved = _currentUid != null && widget.flare.lovedBy.contains(_currentUid);
    _loveCount = widget.flare.loveCount;

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _heartController, curve: Curves.easeOut));

    _loadPhotoBytes();
    _resolveAuthorName();
  }

  void _loadPhotoBytes() {
    final b64 = widget.flare.photoBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        _photoBytes = base64Decode(b64);
      } catch (_) {
        _photoBytes = null;
      }
    }
  }

  Future<void> _resolveAuthorName() async {
    // If the document already carries an authorName, use it immediately.
    if (widget.flare.authorName.isNotEmpty) {
      if (mounted) {
        setState(() => _resolvedAuthorName = widget.flare.authorName);
      }
      return;
    }

    try {
      final profile = await _usersSvc.getUserProfile(widget.flare.authorUid);
      final name = profile?.fullName;
      if (mounted) {
        setState(() => _resolvedAuthorName =
            (name != null && name.isNotEmpty) ? name : null);
      }
    } catch (_) {
      // Ignore — we'll fall back to display name or 'ResQ User'.
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _toggleLove() async {
    final uid = _currentUid;
    if (uid == null) return;

    final wasLoved = _loved;
    setState(() {
      _loved = !_loved;
      _loveCount += _loved ? 1 : -1;
    });
    if (_loved) _heartController.forward(from: 0);

    try {
      await _flareService.toggleLove(widget.flare.id, uid, wasLoved);
    } catch (_) {
      // Roll back on error
      if (mounted) {
        setState(() {
          _loved = wasLoved;
          _loveCount += wasLoved ? 1 : -1;
        });
      }
    }
  }

  void _openComments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommentsScreen(flare: widget.flare),
      ),
    );
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(widget.flare.createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get _isLost => widget.flare.postType == 'lost';
  Color get _typeColor =>
      _isLost ? AppColors.statusActive : AppColors.secondaryCoral;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.flareCardBackground.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuthorRow(),
            _buildPhoto(),
            _buildCaption(),
            const Divider(height: 1, color: AppColors.flareBorder),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Author row
  // ---------------------------------------------------------------------------
  Widget _buildAuthorRow() {
    final name =
        (_resolvedAuthorName != null && _resolvedAuthorName!.isNotEmpty)
            ? _resolvedAuthorName!
            : _displayAuthorName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.flareGradientStart,
                  AppColors.flareGradientEnd
                ],
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + location/time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: AppColors.flareAccentOrange),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${widget.flare.locationLabel.isNotEmpty ? widget.flare.locationLabel : 'Unknown location'} · $_timeAgo',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.flareTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _typeColor.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              _isLost ? 'LOST' : 'SPOTTED',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _typeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------
  Widget _buildPhoto() {
    final photoUrl = widget.flare.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoPlaceholder(),
        ),
      );
    }

    if (_photoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Image.memory(
          _photoBytes!,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _photoPlaceholder(),
        ),
      );
    }

    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.flareActionPanelBg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 52,
                color: _typeColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 6),
              const Text(
                'No photo attached',
                style: TextStyle(
                  color: AppColors.flareHintText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Caption
  // ---------------------------------------------------------------------------
  Widget _buildCaption() {
    final petLabel = [
      if (widget.flare.petName.isNotEmpty) widget.flare.petName,
      widget.flare.petType,
      if (widget.flare.breed.isNotEmpty) widget.flare.breed,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (petLabel.isNotEmpty) ...[
            Text(
              petLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.flareAccentOrange,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            widget.flare.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.flareTextSecondary,
              height: 1.4,
            ),
          ),
          // Love count
          if (_loveCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 14, color: Color(0xFFFF4C78)),
                const SizedBox(width: 4),
                Text(
                  '$_loveCount',
                  style: const TextStyle(
                    color: AppColors.flareTextSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.flare.commentCount > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.mode_comment_outlined,
                      size: 13, color: AppColors.flareHintText),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.flare.commentCount} comments',
                    style: const TextStyle(
                      color: AppColors.flareHintText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action row
  // ---------------------------------------------------------------------------
  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // Love button
          _ActionBtn(
            onTap: _toggleLove,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    _loved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: _loved
                        ? const Color(0xFFFF4C78)
                        : AppColors.flareTextSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Love',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _loved
                        ? const Color(0xFFFF4C78)
                        : AppColors.flareTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(width: 1, height: 28, color: AppColors.flareBorder),

          // Comment button
          _ActionBtn(
            onTap: _openComments,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mode_comment_outlined,
                    size: 19, color: AppColors.flareTextSecondary),
                const SizedBox(width: 6),
                Text(
                  widget.flare.commentCount > 0
                      ? 'Comment (${widget.flare.commentCount})'
                      : 'Comment',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.flareTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(width: 1, height: 28, color: AppColors.flareBorder),

          // Share button
          _ActionBtn(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share — coming soon')),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ios_share_rounded,
                    size: 18, color: AppColors.flareTextSecondary),
                SizedBox(width: 6),
                Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.flareTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim action button that expands evenly across the row.
class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _ActionBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

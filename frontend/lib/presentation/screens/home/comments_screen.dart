import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../database/models/comment_model.dart';
import '../../../database/models/flare_model.dart';
import '../../../database/services/flare_service.dart';

/// Full-screen comments page for a Flare post.
///
/// Pushed from PostCard. Shows a live-updating list of comments and
/// a pinned text-field at the bottom to submit new ones.
class CommentsScreen extends StatefulWidget {
  final FlareModel flare;

  const CommentsScreen({super.key, required this.flare});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _flareService = FlareService();
  bool _sending = false;

  String get _typeLabel => widget.flare.postType == 'lost' ? 'LOST' : 'SPOTTED';
  Color get _typeColor => widget.flare.postType == 'lost'
      ? AppColors.statusActive
      : AppColors.secondaryCoral;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final comment = CommentModel(
        id: '',
        authorUid: user.uid,
        authorName: user.displayName ?? user.email ?? 'User',
        text: text,
        createdAt: DateTime.now(),
      );
      await _flareService.addComment(widget.flare.id, comment);
      _controller.clear();
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.flareScreenBackground,
      appBar: AppBar(
        backgroundColor: AppColors.flareCardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              '${widget.flare.petName.isNotEmpty ? widget.flare.petName : widget.flare.petType} · ${widget.flare.authorName}',
              style: const TextStyle(
                color: AppColors.flareTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _typeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              _typeLabel,
              style: TextStyle(
                color: _typeColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Comment list
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _flareService.watchComments(widget.flare.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.flareAccentOrange,
                    ),
                  );
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 56,
                          color: AppColors.flareTextSecondary
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No comments yet',
                          style: TextStyle(
                            color: AppColors.flareTextSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: AppColors.flareHintText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: comments.length,
                  itemBuilder: (context, index) =>
                      _CommentTile(comment: comments[index]),
                );
              },
            ),
          ),

          // Divider
          const Divider(height: 1, color: AppColors.flareBorder),

          // Input field
          Container(
            color: AppColors.flareCardBackground,
            padding: EdgeInsets.only(
              left: 16,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? 10
                  : 10 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.flareAccentOrange.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.flareAccentOrange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      hintStyle: const TextStyle(
                          color: AppColors.flareHintText, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.flareScreenBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.flareAccentOrange,
                        ),
                      )
                    : GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            gradient: AppColors.flarePublishGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  const _CommentTile({required this.comment});

  String get _timeAgo {
    final diff = DateTime.now().difference(comment.createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final initials = comment.authorName.isNotEmpty
        ? comment.authorName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.flareGradientEnd.withValues(alpha: 0.35),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.flareCardBackground,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          color: AppColors.flareAccentOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        comment.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    _timeAgo,
                    style: const TextStyle(
                      color: AppColors.flareHintText,
                      fontSize: 11.5,
                    ),
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

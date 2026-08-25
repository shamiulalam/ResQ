import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../database/models/flare_model.dart';
import '../../../database/models/user_model.dart';
import '../../../database/services/firestore_service.dart';
import '../../../database/services/flare_service.dart';
import '../../../database/services/chat_service.dart';
import '../chat/chat_window_screen.dart';
import '../home/widgets/post_card.dart';
import '../pet_search/pet_search_page.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final ScrollController? scrollController;

  const ProfileScreen({super.key, this.userId, this.scrollController});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _users = FirestoreService();
  final _flares = FlareService();
  Stream<UserModel?>? _profileStream;
  Stream<List<FlareModel>>? _timelineStream;
  String? _profileUid;

  @override
  void initState() {
    super.initState();
    _profileUid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    final uid = _profileUid;
    if (uid != null) {
      _profileStream = _users.watchUserProfile(uid);
      _timelineStream = _flares.watchUserFlares(uid);
    }
  }

  bool get _isOwn => FirebaseAuth.instance.currentUser?.uid == _profileUid;

  @override
  Widget build(BuildContext context) {
    if (_profileUid == null || _profileStream == null) {
      return const _MessageState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to view your profile',
        message: 'Your profile and pet timeline will appear after you sign in.',
      );
    }

    return StreamBuilder<UserModel?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _ProfileLoadingView();
        }
        if (profileSnapshot.hasError) {
          return _MessageState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load profile',
            message: _friendlyError(profileSnapshot.error),
          );
        }
        final user = profileSnapshot.data;
        if (user == null) {
          return const _MessageState(
            icon: Icons.person_off_outlined,
            title: 'Profile not found',
            message: 'This user profile may have been removed.',
          );
        }

        return StreamBuilder<List<FlareModel>>(
          stream: _timelineStream,
          builder: (context, timelineSnapshot) {
            final posts = timelineSnapshot.data ?? const <FlareModel>[];
            return CustomScrollView(
              key: PageStorageKey<String>('profile-${user.uid}'),
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _topBar(context)),
                SliverToBoxAdapter(child: _ProfileHeader(user: user)),
                SliverToBoxAdapter(
                  child: _StatsRow(
                    posts: posts.length,
                    followers: user.followersCount,
                    following: user.followingCount,
                  ),
                ),
                SliverToBoxAdapter(child: _actions(context, user)),
                SliverToBoxAdapter(
                  child: _AboutCard(user: user, isOwnProfile: _isOwn),
                ),
                const SliverToBoxAdapter(child: _TimelineHeading()),
                if (timelineSnapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: _TimelineLoading())
                else if (timelineSnapshot.hasError)
                  SliverToBoxAdapter(
                    child: _InlineError(
                        message: _friendlyError(timelineSnapshot.error)),
                  )
                else if (posts.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyTimeline())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => PostCard(
                          key: ValueKey(posts[index].id),
                          flare: posts[index],
                        ),
                        childCount: posts.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            if (canPop)
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 12),
            const Text('Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Search pets',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PetSearchPage()),
              ),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Profile options',
              onPressed: _isOwn ? () => _showSettings(context) : null,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, UserModel user) {
    if (_isOwn) {
      return _ProfileActions(
        primaryLabel: 'Edit Profile',
        primaryIcon: Icons.edit_rounded,
        onPrimary: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => EditProfileScreen(user: user)),
        ),
        secondaryLabel: 'Settings',
        secondaryIcon: Icons.settings_outlined,
        onSecondary: () => _showSettings(context),
      );
    }
    return _ProfileActions(
      primaryLabel: 'Message',
      primaryIcon: Icons.chat_bubble_outline_rounded,
      onPrimary: () async {
        try {
          final id =
              await ChatService().openOrCreateDirectConversation(user.uid);
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChatWindowScreen(
                    conversationId: id,
                    otherUid: user.uid,
                    contactName: user.fullName.trim().isEmpty
                        ? 'ResQ User'
                        : user.fullName,
                    avatarUrl: user.profileImage)));
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$error')));
          }
        }
      },
    );
  }

  void _showSettings(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ext.cardBackground,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (_) => false);
            }
          },
        ),
      ),
    );
  }

  static String _friendlyError(Object? error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied')) {
      return 'You do not have permission to view this information.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Check your connection and try again.';
    }
    return 'Please try again in a moment.';
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final name =
        user.fullName.trim().isEmpty ? 'ResQ User' : user.fullName.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 380;
          final avatar = _ProfileAvatar(user: user, size: narrow ? 112 : 126);
          final details = Column(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 27, fontWeight: FontWeight.w700))),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded,
                        color: ext.accentOrange, size: 23),
                  ],
                ],
              ),
              if (user.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(user.subtitle,
                    style: TextStyle(
                        color: ext.accentOrange,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500)),
              ],
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(user.bio,
                    style: TextStyle(
                        color: ext.textSecondary, fontSize: 14, height: 1.45)),
              ],
            ],
          );
          if (narrow) {
            return Column(
                children: [avatar, const SizedBox(height: 14), details]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            avatar,
            const SizedBox(width: 22),
            Expanded(child: details)
          ]);
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  const _ProfileAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final firstInitial = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final lastInitial = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final initials = '$firstInitial$lastInitial'.toUpperCase();
    Widget fallback() => ColoredBox(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Center(
              child: Text(initials.isEmpty ? 'R' : initials,
                  style: TextStyle(
                      color: accent,
                      fontSize: 34,
                      fontWeight: FontWeight.w800))),
        );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2.5)),
      child: ClipOval(
        child: user.profileImage.isEmpty
            ? fallback()
            : Image.network(user.profileImage,
                fit: BoxFit.cover,
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                frameBuilder: (context, child, frame, _) =>
                    frame == null ? fallback() : child,
                errorBuilder: (_, __, ___) => fallback()),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;
  const _StatsRow(
      {required this.posts, required this.followers, required this.following});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _Stat(icon: Icons.article_outlined, count: posts, label: 'Posts'),
          const _StatDivider(),
          _Stat(
              icon: Icons.people_outline_rounded,
              count: followers,
              label: 'Followers'),
          const _StatDivider(),
          _Stat(
              icon: Icons.person_add_alt_1_rounded,
              count: following,
              label: 'Following'),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _Stat({required this.icon, required this.count, required this.label});
  String get value => count >= 1000
      ? '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K'
      : '$count';
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Expanded(
        child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: ext.accentOrange),
        const SizedBox(width: 7),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
      ]),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12.5, color: ext.textSecondary)),
    ]));
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 46, color: Theme.of(context).dividerColor);
}

class _ProfileActions extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  const _ProfileActions(
      {required this.primaryLabel,
      required this.primaryIcon,
      required this.onPrimary,
      this.secondaryLabel,
      this.secondaryIcon,
      this.onSecondary});
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    Widget button(String label, IconData icon, VoidCallback tap, bool filled) =>
        Expanded(
            child: SizedBox(
                height: 48,
                child: filled
                    ? ElevatedButton.icon(
                        onPressed: tap,
                        icon: Icon(icon, size: 19),
                        label: Text(label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)))
                    : OutlinedButton.icon(
                        onPressed: tap,
                        icon: Icon(icon, size: 19),
                        label: Text(label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: ext.textPrimary,
                            side: BorderSide(color: ext.cardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))))));
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Row(children: [
          button(primaryLabel, primaryIcon, onPrimary, true),
          if (secondaryLabel != null) ...[
            const SizedBox(width: 12),
            button(secondaryLabel!, secondaryIcon!, onSecondary!, false)
          ]
        ]));
  }
}

class _AboutCard extends StatelessWidget {
  final UserModel user;
  final bool isOwnProfile;
  const _AboutCard({required this.user, required this.isOwnProfile});
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final place = [user.location, user.city]
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .join(', ');
    final rows = <Widget>[
      if (place.isNotEmpty)
        _AboutRow(icon: Icons.home_rounded, text: 'Lives in $place'),
      _AboutRow(
          icon: Icons.calendar_month_outlined,
          text:
              'Joined ${_month(user.createdAt.month)} ${user.createdAt.year}'),
      if (user.email.isNotEmpty && (isOwnProfile || user.isEmailPublic))
        _AboutRow(icon: Icons.mail_outline_rounded, text: user.email),
      if (user.phone.isNotEmpty && (isOwnProfile || user.isPhonePublic))
        _AboutRow(icon: Icons.phone_outlined, text: user.phone),
    ];
    return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ext.cardBorder)),
        child: Column(children: rows));
  }

  static String _month(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][month - 1];
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14)))
      ]));
}

class _TimelineHeading extends StatelessWidget {
  const _TimelineHeading();
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(children: [
          Icon(Icons.pets_rounded, color: ext.accentOrange, size: 25),
          const SizedBox(width: 10),
          const Text('Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 14),
          Expanded(child: Divider(color: ext.accentOrange))
        ]));
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    Widget bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(12)));
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bar(100, 28),
              const SizedBox(height: 32),
              Row(children: [
                Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: ext.cardBackground)),
                const SizedBox(width: 22),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  bar(160, 26),
                  const SizedBox(height: 12),
                  bar(120, 16),
                  const SizedBox(height: 12),
                  bar(180, 14)
                ])
              ]),
              const SizedBox(height: 30),
              bar(double.infinity, 70),
              const SizedBox(height: 18),
              bar(double.infinity, 120)
            ])));
  }
}

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()));
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 120),
        child: Column(children: [
          Icon(Icons.pets_outlined,
              size: 54, color: ext.accentOrange.withValues(alpha: .7)),
          const SizedBox(height: 14),
          const Text('No pet posts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(
              'Lost and spotted pet posts created by this user will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ext.textSecondary, height: 1.4))
        ]));
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(30),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded),
        const SizedBox(width: 10),
        Flexible(child: Text(message))
      ]));
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _MessageState(
      {required this.icon, required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 54, color: ext.accentOrange),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(color: ext.textSecondary),
                  textAlign: TextAlign.center)
            ])));
  }
}

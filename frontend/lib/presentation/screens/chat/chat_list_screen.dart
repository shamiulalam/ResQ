import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../database/models/chat_models.dart';
import '../../../database/models/user_model.dart';
import '../../../database/services/chat_service.dart';
import '../../../database/services/chat_directory_service.dart';
import '../../../database/services/firestore_service.dart';
import '../../widgets/app_background.dart';
import 'chat_window_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final FirestoreService _usersService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<UserModel?>> _profiles = {};

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService.updatePresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chatService.updatePresence(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view chats.')),
      );
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              if (_isSearching) _buildSearchField(),
              Expanded(child: _buildInbox(currentUid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'ResQ CHATS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isSearching = !_isSearching),
            icon: const Icon(
              Icons.search,
              color: AppColors.flareAccentOrange,
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NewChatScreen(),
              ),
            ),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.flareAccentOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search conversations',
        ),
      ),
    );
  }

  Widget _buildInbox(String currentUid) {
    return StreamBuilder<List<Conversation>>(
      stream: _chatService.watchInbox(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InboxState(
            icon: Icons.cloud_off,
            text: 'Could not load chats: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final conversations = snapshot.data!;
        for (final conversation in conversations) {
          final deliveredAt = conversation.lastDeliveredAt[currentUid];
          final lastMessageAt = conversation.lastMessageAt;
          final needsDeliveryReceipt =
              conversation.lastMessageSenderId != currentUid &&
                  lastMessageAt != null &&
                  (deliveredAt == null || deliveredAt.isBefore(lastMessageAt));
          if (needsDeliveryReceipt) {
            unawaited(_chatService.markDelivered(conversation.id));
          }
        }
        if (conversations.isEmpty) {
          return const _InboxState(
            icon: Icons.forum_outlined,
            text: 'No conversations yet. Message someone from their profile '
                'or Pet Match.',
          );
        }

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: AppColors.flareBorder,
            indent: 20,
            endIndent: 20,
          ),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final otherUid = conversation.otherUid(currentUid);
            _profiles.putIfAbsent(
              otherUid,
              () => _usersService.getUserProfile(otherUid),
            );
            return _buildProfileRow(
              conversation,
              otherUid,
              currentUid,
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(
    Conversation conversation,
    String otherUid,
    String currentUid,
  ) {
    return FutureBuilder<UserModel?>(
      future: _profiles[otherUid],
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.fullName.trim().isNotEmpty == true
            ? user!.fullName
            : 'ResQ User';
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty && !name.toLowerCase().contains(query)) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<ConversationPreference>(
          stream: _chatService.watchPreference(conversation.id),
          builder: (context, preferenceSnapshot) {
            final preference =
                preferenceSnapshot.data ?? const ConversationPreference();
            if (preference.archived) {
              return const SizedBox.shrink();
            }
            return _ConversationTile(
              conversation: conversation,
              currentUid: currentUid,
              otherUid: otherUid,
              name: name,
              user: user,
              preference: preference,
            );
          },
        );
      },
    );
  }
}

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final ChatService _chatService = ChatService();
  final ChatDirectoryService _directoryService = ChatDirectoryService();
  final TextEditingController _search = TextEditingController();
  late final Future<List<UserModel>> _users = _directoryService.listUsers();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('New chat')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search people',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<UserModel>>(
                future: _users,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Could not load people.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final query = _search.text.trim().toLowerCase();
                  final users = snapshot.data!
                      .where((user) => user.uid != currentUid)
                      .where(
                        (user) =>
                            query.isEmpty ||
                            user.fullName.toLowerCase().contains(query),
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImage.isEmpty
                              ? null
                              : NetworkImage(user.profileImage),
                          child: user.profileImage.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user.fullName),
                        onTap: () => _openChat(user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(UserModel user) async {
    try {
      final id = await _chatService.openOrCreateDirectConversation(user.uid);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatWindowScreen(
            conversationId: id,
            otherUid: user.uid,
            contactName:
                user.fullName.trim().isEmpty ? 'ResQ User' : user.fullName,
            avatarUrl: user.profileImage,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUid,
    required this.otherUid,
    required this.name,
    required this.user,
    required this.preference,
  });

  final Conversation conversation;
  final String currentUid;
  final String otherUid;
  final String name;
  final UserModel? user;
  final ConversationPreference preference;

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.unreadCounts[currentUid] ?? 0;
    final hasAvatar = user?.profileImage.isNotEmpty == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: hasAvatar ? NetworkImage(user!.profileImage) : null,
        child: hasAvatar ? null : const Icon(Icons.person),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (preference.pinned)
            const Icon(
              Icons.push_pin,
              size: 15,
              color: AppColors.flareAccentOrange,
            ),
          if (preference.muted)
            const Icon(Icons.volume_off, size: 15, color: Colors.grey),
        ],
      ),
      subtitle: Text(
        conversation.lastMessageText.isEmpty
            ? 'New conversation'
            : conversation.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.flareTextSecondary),
      ),
      trailing: unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.flareAccentOrange,
              child: Text(
                '$unreadCount',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            )
          : Text(
              _relativeTime(conversation.lastMessageAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatWindowScreen(
            conversationId: conversation.id,
            otherUid: otherUid,
            contactName: name,
            avatarUrl: user?.profileImage,
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}

class _InboxState extends StatelessWidget {
  const _InboxState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.flareAccentOrange),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../database/models/chat_models.dart';
import '../../../database/services/chat_media_service.dart';
import '../../../database/services/chat_notification_service.dart';
import '../../../database/services/chat_service.dart';
import '../../widgets/app_background.dart';

enum _LocalSendState { sending, sent, failed }

class ChatWindowScreen extends StatefulWidget {
  const ChatWindowScreen({
    super.key,
    required this.conversationId,
    required this.otherUid,
    required this.contactName,
    this.avatarUrl,
    this.contextFlareId,
  });

  final String conversationId;
  final String otherUid;
  final String contactName;
  final String? avatarUrl;
  final String? contextFlareId;

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen>
    with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final ChatMediaService _mediaService = ChatMediaService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, _PendingSend> _pending = {};
  final Map<String, GlobalKey> _messageKeys = {};
  final List<ChatMessage> _olderMessages = [];

  Timer? _typingTimer;
  MessageReply? _reply;
  bool _typingSent = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _markingRead = false;

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onComposerChanged);
    _scrollController.addListener(_onScroll);
    ChatNotificationService.instance.setOpenConversation(widget.conversationId);
    unawaited(_markConversationOpened());
  }

  @override
  void dispose() {
    ChatNotificationService.instance.setOpenConversation(null);
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    unawaited(_chatService.setTyping(widget.conversationId, false));
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      _chatService.updatePresence(state == AppLifecycleState.resumed),
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_markConversationOpened());
    } else {
      unawaited(_chatService.setTyping(widget.conversationId, false));
    }
  }

  Future<void> _markConversationOpened() async {
    if (_markingRead) return;
    _markingRead = true;
    try {
      await _chatService.markDelivered(widget.conversationId);
      await _chatService.markRead(widget.conversationId);
    } catch (_) {
      // The real-time listener will retry read state on its next update.
    } finally {
      _markingRead = false;
    }
  }

  void _onComposerChanged() {
    if (!_typingSent && _controller.text.trim().isNotEmpty) {
      _typingSent = true;
      unawaited(_chatService.setTyping(widget.conversationId, true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _typingSent = false;
      unawaited(_chatService.setTyping(widget.conversationId, false));
    });
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loadingOlder) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = _reply;
    final messageId = _chatService.newMessageId(widget.conversationId);
    final message = ChatMessage(
      id: messageId,
      senderId: _currentUid,
      type: ChatMessageType.text,
      text: text,
      clientCreatedAt: DateTime.now(),
      clientMessageId: messageId,
      replyTo: reply,
    );
    _controller.clear();
    setState(() {
      _reply = null;
      _pending[messageId] = _PendingSend(message: message);
    });
    unawaited(_performSend(messageId, () {
      return _chatService.sendText(
        widget.conversationId,
        text,
        reply: reply,
        messageId: messageId,
      );
    }));
  }

  Future<void> _performSend(
    String messageId,
    Future<String> Function() operation,
  ) async {
    setState(() {
      _pending[messageId]?.state = _LocalSendState.sending;
      _pending[messageId]?.retry = operation;
    });
    try {
      await operation();
      if (!mounted) return;
      setState(() => _pending[messageId]?.state = _LocalSendState.sent);
      unawaited(
        ChatNotificationService.instance.dispatch(
          widget.conversationId,
          messageId,
        ),
      );
      unawaited(_chatService.setTyping(widget.conversationId, false));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final pending = _pending[messageId];
        pending?.state = _LocalSendState.failed;
        pending?.error = error.toString();
      });
    }
  }

  Future<void> _pickAttachment() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            // Voice messages are intentionally disabled until audio recording,
            // playback, cancellation, and microphone lifecycle are complete.
          ],
        ),
      ),
    );
    if (selection == null) return;
    XFile? picked;
    if (selection == 'image' || selection == 'camera') {
      picked = await _imagePicker.pickImage(
        source:
            selection == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 2048,
      );
    } else if (selection == 'video') {
      picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );
      final path = result?.files.single.path;
      if (path != null) picked = XFile(path);
    }
    if (picked == null) return;
    await _sendAttachment(File(picked.path), picked.name, selection);
  }

  Future<void> _sendAttachment(
    File file,
    String fileName,
    String selection,
  ) async {
    final messageId = _chatService.newMessageId(widget.conversationId);
    final type = switch (selection) {
      'image' || 'camera' => ChatMessageType.image,
      'video' => ChatMessageType.video,
      _ => ChatMessageType.file,
    };
    final reply = _reply;
    final localMedia = {
      'localPath': file.path,
      'fileName': fileName,
      'sizeBytes': await file.length(),
    };
    final message = ChatMessage(
      id: messageId,
      senderId: _currentUid,
      type: type,
      text: '',
      clientCreatedAt: DateTime.now(),
      clientMessageId: messageId,
      replyTo: reply,
      media: localMedia,
    );
    setState(() {
      _reply = null;
      _pending[messageId] = _PendingSend(message: message);
    });
    UploadedChatMedia? uploaded;
    Future<String> operation() async {
      uploaded ??= await _mediaService.upload(
          conversationId: widget.conversationId,
          messageId: messageId,
          file: file,
          fileName: fileName);
      return _chatService.sendMessage(
        widget.conversationId,
        type: type,
        media: uploaded!.toMap(),
        reply: reply,
        messageId: messageId,
      );
    }

    unawaited(_performSend(messageId, operation));
  }

  Future<void> _loadOlder() async {
    final loaded = _combinedRemoteMessages;
    if (loaded.isEmpty || _loadingOlder || !_hasMore) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _chatService.loadOlderMessages(
        widget.conversationId,
        loaded.last.effectiveCreatedAt,
      );
      if (!mounted) return;
      setState(() {
        _hasMore = page.length == 30;
        for (final message in page) {
          if (!_olderMessages.any((item) => item.id == message.id)) {
            _olderMessages.add(message);
          }
        }
      });
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  List<ChatMessage> _recentMessages = const [];

  List<ChatMessage> get _combinedRemoteMessages {
    final byId = <String, ChatMessage>{};
    for (final message in [..._recentMessages, ..._olderMessages]) {
      byId[message.id] = message;
    }
    final result = byId.values.toList()
      ..sort((a, b) => b.effectiveCreatedAt.compareTo(a.effectiveCreatedAt));
    return result;
  }

  Future<void> _jumpToMessage(String messageId) async {
    for (var page = 0; page < 20; page++) {
      final key = _messageKeys[messageId];
      final targetContext = key?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          alignment: .5,
        );
        return;
      }
      if (!_hasMore) break;
      await _loadOlder();
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is unavailable.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildConversation()),
              if (_reply != null) _buildReplyPreview(),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<bool>(
      stream: _chatService.watchTyping(
        widget.conversationId,
        widget.otherUid,
      ),
      builder: (context, snapshot) => ListTile(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.contactName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          snapshot.data == true ? 'typing…' : 'ResQ chat',
          style: TextStyle(
            color: snapshot.data == true
                ? AppColors.flareAccentOrange
                : Colors.grey,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: _handleConversationMenu,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'mute', child: Text('Mute')),
            PopupMenuItem(value: 'pin', child: Text('Pin')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
            PopupMenuItem(value: 'block', child: Text('Block user')),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    return StreamBuilder<Conversation?>(
      stream: _chatService.watchConversation(widget.conversationId),
      builder: (context, conversationSnapshot) {
        final conversation = conversationSnapshot.data;
        if ((conversation?.unreadCounts[_currentUid] ?? 0) > 0) {
          unawaited(_markConversationOpened());
        }
        return StreamBuilder<List<ChatMessage>>(
          stream: _chatService.watchRecentMessages(widget.conversationId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load messages: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData && _pending.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            _recentMessages = snapshot.data ?? const [];
            final remote = _combinedRemoteMessages;
            final remoteIds = remote.map((message) => message.id).toSet();
            final localOnly = _pending.values
                .where((pending) => !remoteIds.contains(pending.message.id))
                .map((pending) => pending.message);
            final messages = [...remote, ...localOnly]..sort(
                (a, b) => b.effectiveCreatedAt.compareTo(a.effectiveCreatedAt),
              );
            return ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: messages.length + (_loadingOlder ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final message = messages[index];
                final olderNeighbor =
                    index + 1 < messages.length ? messages[index + 1] : null;
                final showDate = olderNeighbor == null ||
                    !_sameDay(
                      message.effectiveCreatedAt,
                      olderNeighbor.effectiveCreatedAt,
                    );
                _messageKeys.putIfAbsent(message.id, GlobalKey.new);
                return KeyedSubtree(
                  key: _messageKeys[message.id],
                  child: Column(
                    children: [
                      if (showDate) _DateSeparator(message.effectiveCreatedAt),
                      _MessageBubble(
                        message: message,
                        isMe: message.senderId == _currentUid,
                        mediaService: _mediaService,
                        conversationId: widget.conversationId,
                        localState: _pending[message.id]?.state,
                        deliveryLabel: _deliveryLabel(message, conversation),
                        onRetry: _pending[message.id]?.retry == null
                            ? null
                            : () => _performSend(
                                  message.id,
                                  _pending[message.id]!.retry!,
                                ),
                        onLongPress: () => _showMessageActions(message),
                        onReplyTap: message.replyTo == null
                            ? null
                            : () => _jumpToMessage(
                                  message.replyTo!.messageId,
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String? _deliveryLabel(ChatMessage message, Conversation? conversation) {
    if (message.senderId != _currentUid) return null;
    final pendingState = _pending[message.id]?.state;
    if (pendingState == _LocalSendState.sending) return 'Sending';
    if (pendingState == _LocalSendState.failed) return 'Failed';
    final readAt = conversation?.lastReadAt[widget.otherUid];
    if (readAt != null && !message.effectiveCreatedAt.isAfter(readAt)) {
      return 'Seen';
    }
    final deliveredAt = conversation?.lastDeliveredAt[widget.otherUid];
    if (deliveredAt != null &&
        !message.effectiveCreatedAt.isAfter(deliveredAt)) {
      return 'Delivered';
    }
    return 'Sent';
  }

  Widget _buildReplyPreview() {
    return Container(
      color: AppColors.flareCardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.reply, color: AppColors.flareAccentOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _reply!.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _reply = null),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach',
            onPressed: _pickAttachment,
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.flareAccentOrange,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message…',
                filled: true,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: canSend ? _sendText : null,
            icon: Icon(
              Icons.send_rounded,
              color: canSend ? AppColors.flareAccentOrange : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.flareCardBackground,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['❤️', '👍', '😂', '😮', '😢', '😡']
                      .map(
                        (emoji) => IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              _chatService.react(
                                widget.conversationId,
                                message.id,
                                emoji,
                              ),
                            );
                          },
                          icon: Text(
                            emoji,
                            style: const TextStyle(fontSize: 25),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.reply,
                    label: 'Reply',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _setReply(message);
                    },
                  ),
                  _ActionChip(
                    icon: Icons.delete_outline,
                    label: 'Delete for me',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      unawaited(
                        _chatService.deleteForMe(
                          widget.conversationId,
                          message.id,
                        ),
                      );
                    },
                  ),
                  if (message.senderId == _currentUid &&
                      message.type == ChatMessageType.text &&
                      !message.deletedForEveryone)
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(_editMessage(message));
                      },
                    ),
                  if (message.senderId == _currentUid &&
                      !message.deletedForEveryone)
                    _ActionChip(
                      icon: Icons.undo,
                      label: 'Unsend',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(
                          _chatService.unsend(
                            widget.conversationId,
                            message.id,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setReply(ChatMessage message) {
    setState(() {
      _reply = MessageReply(
        messageId: message.id,
        senderId: message.senderId,
        type: message.type.name,
        preview: message.deletedForEveryone
            ? 'Message unsent'
            : message.text.isNotEmpty
                ? message.text
                : message.type.name,
      );
    });
  }

  Future<void> _editMessage(ChatMessage message) async {
    final editController = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: editController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    editController.dispose();
    if (result?.trim().isNotEmpty == true) {
      await _chatService.edit(widget.conversationId, message.id, result!);
    }
  }

  Future<void> _handleConversationMenu(String value) async {
    if (value == 'mute') {
      await _chatService.setPreference(widget.conversationId, muted: true);
    } else if (value == 'pin') {
      await _chatService.setPreference(widget.conversationId, pinned: true);
    } else if (value == 'archive') {
      await _chatService.setPreference(widget.conversationId, archived: true);
      if (mounted) Navigator.pop(context);
    } else if (value == 'block') {
      await _chatService.setBlocked(widget.otherUid, true);
      if (mounted) Navigator.pop(context);
    }
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _PendingSend {
  _PendingSend({required this.message});
  final ChatMessage message;
  _LocalSendState state = _LocalSendState.sending;
  Future<String> Function()? retry;
  String? error;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.mediaService,
    required this.conversationId,
    required this.onLongPress,
    this.localState,
    this.deliveryLabel,
    this.onRetry,
    this.onReplyTap,
  });

  final ChatMessage message;
  final bool isMe;
  final ChatMediaService mediaService;
  final String conversationId;
  final _LocalSendState? localState;
  final String? deliveryLabel;
  final VoidCallback? onRetry;
  final VoidCallback onLongPress;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final reactionCounts = <String, int>{};
    for (final emoji in message.reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (reactionCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 3),
              child: Wrap(
                spacing: 4,
                children: reactionCounts.entries
                    .map((entry) => Text(
                        '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}'))
                    .toList(),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.flareGradientEnd
                    : AppColors.flareCardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    InkWell(
                      onTap: onReplyTap,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          message.replyTo!.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  if (message.deletedForEveryone)
                    const Text(
                      'Message unsent',
                      style: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    _MessageContent(
                      message: message,
                      conversationId: conversationId,
                      mediaService: mediaService,
                    ),
                ],
              ),
            ),
          ),
          if (isMe && deliveryLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 5, bottom: 3),
              child: InkWell(
                onTap: localState == _LocalSendState.failed ? onRetry : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (localState == _LocalSendState.sending)
                      const SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(strokeWidth: 1.2),
                      ),
                    if (localState == _LocalSendState.failed)
                      const Icon(Icons.error_outline,
                          size: 13, color: Colors.red),
                    const SizedBox(width: 3),
                    Text(
                      localState == _LocalSendState.failed
                          ? 'Failed · Tap to retry'
                          : deliveryLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        color: localState == _LocalSendState.failed
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.conversationId,
    required this.mediaService,
  });

  final ChatMessage message;
  final String conversationId;
  final ChatMediaService mediaService;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.text) {
      return Text(message.text, style: const TextStyle(color: Colors.white));
    }
    final localPath = message.media?['localPath'] as String?;
    if (message.type == ChatMessageType.image && localPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(localPath), width: 210, fit: BoxFit.cover),
      );
    }
    final objectPath = message.media?['objectPath'] as String?;
    if (message.type == ChatMessageType.image && objectPath != null) {
      return FutureBuilder<String>(
        future: mediaService.signedUrl(conversationId, objectPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                snapshot.data!,
                width: 210,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Text('Image unavailable'),
              ),
            );
          }
          if (snapshot.hasError) return const Text('Image unavailable');
          return const SizedBox(
            width: 80,
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    final fileName = message.media?['fileName']?.toString() ??
        (message.type == ChatMessageType.video ? 'Video' : 'Attachment');
    return InkWell(
      onTap: objectPath == null
          ? null
          : () async {
              final url = await mediaService.signedUrl(
                conversationId,
                objectPath,
              );
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            message.type == ChatMessageType.video
                ? Icons.play_circle_outline
                : Icons.insert_drive_file_outlined,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    final label = value == today
        ? 'Today'
        : value == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${date.day}/${date.month}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        onPressed: onTap,
      );
}

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../../auth/logic/session_provider.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({
    required this.friendId,
    required this.friendName,
    this.friendAvatarUrl,
    this.friendInitials,
    this.friendSport,
    super.key,
  });

  final String friendId;
  final String friendName;
  final String? friendAvatarUrl;
  final String? friendInitials;
  final String? friendSport;

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Polling tiap 2.5 detik agar chat bisa saling berbalas secara real-time
    _poller = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _pollMessages();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    // Sinkronisasi ulang saat keluar dari layar chat agar status unread ter-update
    ref.read(localStateProvider.notifier).refreshSync();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final api = ref.read(authApiClientProvider);
    final msgs = await api.getDirectMessages(widget.friendId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
      // Tandai percakapan ini sudah dibaca di local state
      ref.read(localStateProvider.notifier).markConversationRead(widget.friendId);
    }
  }

  Future<void> _pollMessages() async {
    final api = ref.read(authApiClientProvider);
    final msgs = await api.getDirectMessages(widget.friendId);
    if (mounted && msgs.length != _messages.length) {
      setState(() {
        _messages = msgs;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    // Optimistic UI update
    final now = DateTime.now();
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'isMe': true,
      'message': text,
      'createdAt': now.toIso8601String(),
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    try {
      final api = ref.read(authApiClientProvider);
      final sent = await api.sendDirectMessage(widget.friendId, text);
      if (sent != null && mounted) {
        // Otomatis refresh jika ada balasan/id dari database
        _pollMessages();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              name: widget.friendName,
              avatarUrl: widget.friendAvatarUrl,
              initials: widget.friendInitials,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendName,
                    style: textStyle(15, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.friendSport != null
                        ? '${widget.friendSport} · Teman'
                        : 'Teman Aktif',
                    style: textStyle(11, color: secondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Security / Connection Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pesan langsung pribadi dan aman tersimpan di server KLIK',
                    style: textStyle(11, color: accent, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Messages List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 32,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada obrolan',
                              style: textStyle(14, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sapa ${widget.friendName} dan mulai rencanakan mabar!',
                              style: textStyle(12, color: secondary(context)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['isMe'] == true;
                          final text = msg['message'] as String? ?? '';
                          final createdStr = msg['createdAt'] as String?;
                          final timeText = createdStr != null
                              ? timeLabel(DateTime.parse(createdStr).toLocal())
                              : '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  UserAvatar(
                                    name: widget.friendName,
                                    avatarUrl: widget.friendAvatarUrl,
                                    initials: widget.friendInitials,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (isMe && timeText.isNotEmpty) ...[
                                  Text(
                                    timeText,
                                    style: textStyle(10, color: secondary(context)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? accent
                                          : Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                      border: isMe
                                          ? null
                                          : Border.all(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.15),
                                            ),
                                    ),
                                    child: Text(
                                      text,
                                      style: textStyle(
                                        13,
                                        color: isMe
                                            ? Colors.white
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ).copyWith(height: 1.35),
                                    ),
                                  ),
                                ),
                                if (!isMe && timeText.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    timeText,
                                    style: textStyle(10, color: secondary(context)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onSubmitted: (_) => _sendMessage(),
                      cursorColor: accent,
                      style: textStyle(13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2124)
                            : const Color(0xFFF3F4F6),
                        hintText: 'Tulis pesan ke ${widget.friendName}...',
                        hintStyle: textStyle(13, color: secondary(context)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: accent,
                    borderRadius: BorderRadius.circular(22),
                    elevation: 1,
                    child: InkWell(
                      onTap: _sendMessage,
                      borderRadius: BorderRadius.circular(22),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.send_rounded,
                            size: 19,
                            color: Color(0xFF171B12),
                          ),
                        ),
                      ),
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

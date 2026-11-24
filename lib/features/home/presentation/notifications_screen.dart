import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(localStateProvider.notifier).refreshSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final notifications = (data['notifications'] as List? ?? [])
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
    final joined = (data['joined'] as List).cast<String>();
    final items = activitiesOf(data).where((a) => joined.contains(a.id)).toList();
    final players = (data['players'] as List? ?? []).cast<Map>();
    final friends = (data['friends'] as List? ?? []).cast<String>();
    final incoming = (data['incomingRequests'] as List? ?? []).cast<String>();

    final hasContent = notifications.isNotEmpty || items.isNotEmpty;

    return KPage(
      title: 'Notifikasi',
      children: [
        if (!hasContent)
          const EmptyState(
            'Belum ada notifikasi',
            'Permintaan teman dan pembaruan kegiatan kamu akan tampil di sini.',
          ),
        if (notifications.isNotEmpty) ...[
          const SectionTitle('Riwayat Notifikasi'),
          for (final notif in notifications)
            _NotificationCard(
              notification: notif,
              players: players,
              friends: friends,
              incoming: incoming,
            ),
        ],
        if (items.isNotEmpty) ...[
          SectionTitle('Aktivitas yang diikuti (${items.length})'),
          for (final a in items)
            KCard(
              onTap: () => context.push('/activity/${a.id}'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: const Icon(Icons.event_available_outlined, color: Color(0xFF171B12)),
                ),
                title: Text(
                  'Kamu bergabung: ${a.title}',
                  style: textStyle(14, weight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${a.sport} • ${a.venue}',
                  style: textStyle(12, color: secondary(context)),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
              ),
            ),
        ],
        const LocalNotice(),
      ],
    );
  }
}

class _NotificationCard extends ConsumerStatefulWidget {
  const _NotificationCard({
    required this.notification,
    required this.players,
    required this.friends,
    required this.incoming,
  });

  final Map<String, dynamic> notification;
  final List<Map> players;
  final List<String> friends;
  final List<String> incoming;

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  bool busy = false;

  String? _findRequesterPlayerId() {
    final notif = widget.notification;
    final actionId = notif['actionId'] as String?;
    if (actionId != null && actionId.isNotEmpty) {
      return actionId;
    }
    // Fallback: match sender from notification body
    final body = (notif['body'] as String? ?? '');
    for (final p in widget.players) {
      final name = p['name'] as String? ?? '';
      if (name.isNotEmpty && body.startsWith(name)) {
        return p['id'] as String;
      }
    }
    // Or if there is an incoming request
    if (widget.incoming.isNotEmpty) {
      return widget.incoming.first;
    }
    return null;
  }

  Map<String, dynamic>? _findRequesterPlayer(String? playerId) {
    if (playerId == null) return null;
    final matches = widget.players.where((p) => p['id'] == playerId);
    return matches.isNotEmpty ? Map<String, dynamic>.from(matches.first) : null;
  }

  void _showNotificationDetailModal(
    BuildContext context, {
    required String? requesterId,
    required Map<String, dynamic>? player,
    required bool isFriendRequest,
    required bool isPending,
    required bool isFriend,
  }) {
    // Mark as read when opened
    final id = widget.notification['id'];
    if (id != null) {
      ref.read(localStateProvider.notifier).markNotificationRead(id);
    }

    final title = widget.notification['title'] as String? ?? 'Notifikasi';
    final body = widget.notification['body'] as String? ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: accent,
                          radius: 22,
                          child: Icon(
                            isFriendRequest
                                ? Icons.person_add_rounded
                                : Icons.notifications_rounded,
                            color: const Color(0xFF171B12),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: textStyle(16, weight: FontWeight.w800),
                              ),
                              Text(
                                isPending
                                    ? 'Menunggu responmu'
                                    : isFriend
                                        ? 'Sudah berteman'
                                        : 'Notifikasi sistem',
                                style: textStyle(12, color: secondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      body,
                      style: textStyle(14),
                    ),
                    if (player != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: accent,
                              child: Text(
                                player['initials'] as String? ?? 'P',
                                style: textStyle(14, weight: FontWeight.w800, color: const Color(0xFF171B12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['name'] as String,
                                    style: textStyle(14, weight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${player['sport']} • ${player['level']} • ${player['city']}',
                                    style: textStyle(12, color: secondary(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (isPending && requesterId != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: KButton(
                              'Terima Pertemanan',
                              busy: busy,
                              onPressed: () async {
                                setModalState(() => busy = true);
                                setState(() => busy = true);
                                await perform(
                                  context,
                                  () => ref
                                      .read(localStateProvider.notifier)
                                      .acceptFriend(requesterId),
                                  success: 'Sekarang kamu berteman dengan ${player?['name'] ?? requesterId}!',
                                );
                                if (mounted) setState(() => busy = false);
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KButton(
                              'Tolak',
                              secondary: true,
                              busy: busy,
                              onPressed: () async {
                                setModalState(() => busy = true);
                                setState(() => busy = true);
                                await perform(
                                  context,
                                  () => ref
                                      .read(localStateProvider.notifier)
                                      .rejectFriend(requesterId),
                                  success: 'Permintaan pertemanan ditolak.',
                                );
                                if (mounted) setState(() => busy = false);
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (player != null)
                      KButton(
                        'Lihat Profil Pemain',
                        secondary: true,
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          context.push('/player/${player['id']}');
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.notification['title'] as String? ?? 'Pemberitahuan';
    final body = widget.notification['body'] as String? ?? '';
    final isRead = widget.notification['isRead'] == true;
    final createdAtStr = widget.notification['createdAt'] as String?;
    final notifType = widget.notification['type'] as String? ?? '';

    final isFriendRequest = notifType == 'friend_request' ||
        title.toLowerCase().contains('permintaan');
    final isFriendAccepted = notifType == 'friend_accepted' ||
        title.toLowerCase().contains('diterima');

    final requesterId = _findRequesterPlayerId();
    final player = _findRequesterPlayer(requesterId);

    final isFriend = requesterId != null && widget.friends.contains(requesterId);
    final isPending = requesterId != null && widget.incoming.contains(requesterId);

    IconData iconData = Icons.notifications_outlined;
    if (isFriendRequest) {
      iconData = Icons.person_add_outlined;
    } else if (isFriendAccepted) {
      iconData = Icons.how_to_reg_outlined;
    }

    String formattedTime = '';
    if (createdAtStr != null) {
      final dt = DateTime.tryParse(createdAtStr)?.toLocal();
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          formattedTime = 'Baru saja';
        } else if (diff.inMinutes < 60) {
          formattedTime = '${diff.inMinutes}m lalu';
        } else if (diff.inHours < 24) {
          formattedTime = '${diff.inHours}j lalu';
        } else {
          formattedTime = '${diff.inDays}h lalu';
        }
      }
    }

    return KCard(
      onTap: () {
        _showNotificationDetailModal(
          context,
          requesterId: requesterId,
          player: player,
          isFriendRequest: isFriendRequest,
          isPending: isPending,
          isFriend: isFriend,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isRead
                    ? Theme.of(context).dividerColor.withValues(alpha: 0.3)
                    : accent,
                child: Icon(
                  iconData,
                  color: const Color(0xFF171B12),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: textStyle(
                              14,
                              weight: isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (formattedTime.isNotEmpty)
                          Text(
                            formattedTime,
                            style: textStyle(11, color: secondary(context)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: textStyle(
                        13,
                        color: isRead ? secondary(context) : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          // Actions for pending friend request
          if (isFriendRequest) ...[
            const SizedBox(height: 12),
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      'Terima',
                      busy: busy,
                      onPressed: () async {
                        setState(() => busy = true);
                        final id = widget.notification['id'];
                        if (id != null) {
                          await ref
                              .read(localStateProvider.notifier)
                              .markNotificationRead(id);
                        }
                        if (context.mounted) {
                          await perform(
                            context,
                            () => ref
                                .read(localStateProvider.notifier)
                                .acceptFriend(requesterId),
                            success: 'Sekarang kamu berteman dengan ${player?['name'] ?? requesterId}!',
                          );
                        }
                        if (context.mounted) setState(() => busy = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KButton(
                      'Tolak',
                      secondary: true,
                      busy: busy,
                      onPressed: () async {
                        setState(() => busy = true);
                        final id = widget.notification['id'];
                        if (id != null) {
                          await ref
                              .read(localStateProvider.notifier)
                              .markNotificationRead(id);
                        }
                        if (context.mounted) {
                          await perform(
                            context,
                            () => ref
                                .read(localStateProvider.notifier)
                                .rejectFriend(requesterId),
                            success: 'Permintaan pertemanan ditolak.',
                          );
                        }
                        if (context.mounted) setState(() => busy = false);
                      },
                    ),
                  ),
                ],
              ),
            ] else if (isFriend) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF171B12)),
                    const SizedBox(width: 6),
                    Text(
                      'Sudah berteman',
                      style: textStyle(12, weight: FontWeight.w700, color: const Color(0xFF171B12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Permintaan telah ditanggapi',
                style: textStyle(12, color: secondary(context)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/activity.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({required this.sport, super.key});
  final String sport;

  @override
  ConsumerState<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _userMessages = [];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(localStateProvider).requireValue;
    final userName = user['name'] as String? ?? 'Kamu';
    final now = DateTime.now();

    setState(() {
      _userMessages.add({
        'sender': userName,
        'senderInitials': userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
        'isMe': true,
        'text': text,
        'time': timeLabel(now),
      });
      _msgController.clear();
    });

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

  void _shareEventToChat(Activity act) {
    final user = ref.read(localStateProvider).requireValue;
    final userName = user['name'] as String? ?? 'Kamu';
    final now = DateTime.now();

    setState(() {
      _userMessages.add({
        'sender': userName,
        'senderInitials': userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
        'isMe': true,
        'sharedEvent': act,
        'time': timeLabel(now),
      });
    });

    Navigator.pop(context); // Tutup bottom sheet

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

  void _showShareEventSheet(List<Activity> matchingEvents) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bagikan Event ke Komunitas',
                    style: textStyle(16, weight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih event atau jadwal ${widget.sport} untuk dibagikan ke anggota grup.',
                style: textStyle(12, color: secondary(context)),
              ),
              const SizedBox(height: 12),
              if (matchingEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada event ${widget.sport} yang dapat dibagikan.',
                      style: textStyle(12, color: secondary(context)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: matchingEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = matchingEvents[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: textStyle(13, weight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.venue} · ${timeLabel(item.startsAt)}',
                                    style: textStyle(11, color: secondary(context)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _shareEventToChat(item),
                              child: Text(
                                'Bagikan',
                                style: textStyle(11, weight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSportIconName(String sport) {
    final idx = sports.indexOf(sport);
    if (idx >= 0 && idx < sportIcons.length) {
      return sportIcons[idx];
    }
    return 'football';
  }

  List<Map<String, dynamic>> _getPredefinedCommunityChats(String sport, List<Activity> events) {
    // Obrolan dinamis realistis sesuai masing-masing komunitas olahraga
    switch (sport) {
      case 'Futsal':
        return [
          {
            'name': 'Kapten Futsal ID',
            'initials': 'KF',
            'isBot': false,
            'text': 'Halo agan-agan pecinta Futsal! Mabar rutin tiap Rabu & Sabtu malam ya di Lapangan Cilandak.',
            'time': '14:20',
          },
          {
            'name': 'Faris Daffa',
            'initials': 'FD',
            'isBot': false,
            'text': 'Siap capt! Nanti malam ada slot kosong ga buat 2 orang lagi?',
            'time': '14:25',
          },
          {
            'name': 'Kapten Futsal ID',
            'initials': 'KF',
            'isBot': false,
            'text': 'Ada bro! Cek event di bawah atau langsung daftar di room yang dishare yaa 🔥',
            'time': '14:28',
          },
        ];
      case 'Basket':
        return [
          {
            'name': 'Coach Budi',
            'initials': 'CB',
            'isBot': false,
            'text': 'Selamat datang di grup Basket KLIK! Kita lagi cari tim buat sparring 3x3 weekend ini.',
            'time': '10:05',
          },
          {
            'name': 'Aldi Pratama',
            'initials': 'AP',
            'isBot': false,
            'text': 'Tim kampus kami siap Coach! Main di lapangan mana?',
            'time': '10:12',
          },
        ];
      case 'Bulu Tangkis':
        return [
          {
            'name': 'Badminton Club',
            'initials': 'BC',
            'isBot': false,
            'text': 'Halo badminton mania! Ada info sewa karpet bareng untuk ganda campuran hari Minggu nih.',
            'time': '09:00',
          },
          {
            'name': 'Siti Rahma',
            'initials': 'SR',
            'isBot': false,
            'text': 'Mau ikutan dong min, shuttlecock pakai merk apa biasanya?',
            'time': '09:15',
          },
        ];
      case 'Padel':
        return [
          {
            'name': 'Padel Pro Community',
            'initials': 'PP',
            'isBot': false,
            'text': 'Selamat datang di komunitas Padel! Yang baru mau coba main pertama kali bisa gabung sesi coaching gratis.',
            'time': '11:00',
          },
          {
            'name': 'Jessica',
            'initials': 'JS',
            'isBot': false,
            'text': 'Wah seru banget, raketnya sudah disediakan di tempat ya?',
            'time': '11:20',
          },
        ];
      default:
        return [
          {
            'name': 'Admin Komunitas $sport',
            'initials': sport.isNotEmpty ? sport[0].toUpperCase() : 'A',
            'isBot': false,
            'text': 'Halo rekan-rekan olahraga $sport! Selamat bergabung di ruang obrolan resmi.',
            'time': '08:30',
          },
          {
            'name': 'Rian Perkasa',
            'initials': 'RP',
            'isBot': false,
            'text': 'Salam kenal semua! Senang bisa ketemu teman sehobi $sport di sini.',
            'time': '08:45',
          },
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateData = ref.watch(localStateProvider).requireValue;
    final allActivities = activitiesOf(stateData);

    // Ambil semua event & room yang sesuai dengan olahraga komunitas ini
    final matchingEvents = allActivities.where((a) => a.sport == widget.sport).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconName = _getSportIconName(widget.sport);
    final communityChats = _getPredefinedCommunityChats(widget.sport, matchingEvents);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: FigmaIcon(
                    iconName,
                    color: accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Komunitas ${widget.sport}',
                    style: textStyle(15, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${matchingEvents.length} Event/Jadwal Aktif · Grup Komunitas',
                    style: textStyle(11, color: secondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Bagikan Event',
            onPressed: () => _showShareEventSheet(matchingEvents),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update otomatis: Event & jadwal mabar ${widget.sport} langsung diinfokan di sini!',
                    style: textStyle(11, weight: FontWeight.w600, color: accent),
                  ),
                ),
              ],
            ),
          ),
          // Area Chat
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Pesan Selamat Datang dari Bot
                _buildSystemNotice(
                  'Anda telah bergabung ke dalam Komunitas ${widget.sport}. Selamat berbagi info jadwal & event!',
                ),
                const SizedBox(height: 12),

                // Notifikasi Otomatis Bot tentang Event yang sesuai komunitas
                if (matchingEvents.isNotEmpty) ...[
                  for (final ev in matchingEvents) ...[
                    _buildEventAnnouncement(ev),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  _buildBotMessage(
                    'Saat ini belum ada event atau jadwal baru untuk cabang ${widget.sport}. Begitu ada yang membuat event baru, notifikasinya akan langsung dikirim di grup ini!',
                    '08:00',
                  ),
                  const SizedBox(height: 12),
                ],

                // Pesan Diskusi Dinamis Khusus Komunitas Ini
                for (final chat in communityChats) ...[
                  _buildMemberMessage(
                    name: chat['name'] as String,
                    initials: chat['initials'] as String,
                    text: chat['text'] as String,
                    time: chat['time'] as String,
                  ),
                  const SizedBox(height: 8),
                ],

                // Pesan User yang Baru Dikirim
                for (final msg in _userMessages) ...[
                  if (msg['sharedEvent'] != null)
                    _buildUserSharedEventBubble(msg['sharedEvent'] as Activity, msg['time'] as String)
                  else
                    _buildUserBubble(msg),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // Input Bar dengan tombol Share Event
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
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: accent, size: 24),
                    tooltip: 'Bagikan Event ke Chat',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _showShareEventSheet(matchingEvents),
                  ),
                  const SizedBox(width: 6),
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
                        hintText: 'Tulis pesan di komunitas ${widget.sport}...',
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

  Widget _buildSystemNotice(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textStyle(11, color: secondary(context)),
        ),
      ),
    );
  }

  Widget _buildBotMessage(String text, String time) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.smart_toy_rounded, size: 18, color: accent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bot Info ${widget.sport}',
                    style: textStyle(11, weight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: textStyle(10, color: secondary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  text,
                  style: textStyle(12).copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventAnnouncement(Activity activity) {
    final isEvent = activity.isEvent;
    final dateStr = '${dayLabel(activity.startsAt)} · ${timeLabel(activity.startsAt)}';
    final priceStr = activity.price > 0 ? 'Rp ${activity.price}' : 'Gratis';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.campaign_rounded, size: 18, color: accent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bot Info Event ${widget.sport}',
                    style: textStyle(11, weight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Resmi',
                      style: textStyle(9, weight: FontWeight.w700, color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEvent ? Icons.event_available_rounded : Icons.sports_soccer_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEvent ? 'Ada Event Baru!' : 'Jadwal Mabar Tersedia!',
                            style: textStyle(11, weight: FontWeight.w700, color: accent),
                          ),
                        ],
                      ),
                    ),
                    // Detail Info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: textStyle(14, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: secondary(context)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${activity.venue}, ${activity.city}',
                                  style: textStyle(11, color: secondary(context)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: secondary(context)),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: textStyle(11, color: secondary(context)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 14, color: secondary(context)),
                              const SizedBox(width: 4),
                              Text(
                                'Biaya: $priceStr · Slot: ${activity.occupied}/${activity.capacity} terisi',
                                style: textStyle(11, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => context.push('/activity/${activity.id}'),
                              child: Text(
                                isEvent ? 'Lihat Acara & Daftar' : 'Lihat Ruang & Gabung',
                                style: textStyle(11, weight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserSharedEventBubble(Activity activity, String time) {
    final isEvent = activity.isEvent;
    final dateStr = '${dayLabel(activity.startsAt)} · ${timeLabel(activity.startsAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Membagikan event',
              style: textStyle(10, weight: FontWeight.w600, color: secondary(context)),
            ),
            const SizedBox(width: 6),
            Text(
              time,
              style: textStyle(10, color: secondary(context)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: MediaQuery.sizeOf(context).width * 0.78,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      isEvent ? 'Event Rekomendasi' : 'Jadwal Main Rekomendasi',
                      style: textStyle(11, weight: FontWeight.w700, color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activity.title,
                  style: textStyle(13, weight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.venue} · $dateStr',
                  style: textStyle(11, color: secondary(context)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () => context.push('/activity/${activity.id}'),
                    child: Text(
                      'Lihat Detail',
                      style: textStyle(11, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberMessage({
    required String name,
    required String initials,
    required String text,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(name: name, initials: initials, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: textStyle(11, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: textStyle(10, color: secondary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  text,
                  style: textStyle(12).copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(Map<String, dynamic> msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          msg['time'] as String,
          style: textStyle(10, color: secondary(context)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: Text(
              msg['text'] as String,
              style: textStyle(12, color: Colors.white).copyWith(height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}

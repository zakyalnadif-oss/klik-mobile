import 'package:material_ui/material_ui.dart';

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/components/activity_card.dart';
import '../../../shared/components/event_carousel.dart';
import '../../../shared/components/ranking_preview.dart';
import '../../../shared/widgets/klik_ui.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String sport = 'Futsal';
  final ScrollController _sportScrollController = ScrollController();
  double _sportScrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _sportScrollController.addListener(_onSportScroll);
  }

  void _onSportScroll() {
    if (_sportScrollController.hasClients &&
        _sportScrollController.position.maxScrollExtent > 0) {
      final progress = (_sportScrollController.offset /
              _sportScrollController.position.maxScrollExtent)
          .clamp(0.0, 1.0);
      if ((progress - _sportScrollProgress).abs() > 0.01) {
        setState(() => _sportScrollProgress = progress);
      }
    }
  }

  @override
  void dispose() {
    _sportScrollController.removeListener(_onSportScroll);
    _sportScrollController.dispose();
    super.dispose();
  }

  Widget locationLink(BuildContext context, String city) => InkWell(
    onTap: () => context.push('/edit-profile'),
    child: Row(
      children: [
        FigmaIcon('location', color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            city,
            style: textStyle(13, weight: FontWeight.w600).copyWith(height: 1.2),
          ),
        ),
        FigmaIcon('chevron', color: Theme.of(context).colorScheme.onSurface),
      ],
    ),
  );

  Widget sportSelector(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Tampilkan 3 kartu penuh dan kartu ke-4 sedikit mengintip (~35%) di sisi kanan
    final cardWidth = math.max(92.0, (screenWidth - 48 - 25) / 3.35);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          controller: _sportScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: List.generate(
              sports.length,
              (i) => Padding(
                padding: EdgeInsets.only(
                  right: i == sports.length - 1 ? 0 : 10,
                ),
                child: Semantics(
                  selected: sport == sports[i],
                  button: true,
                  child: InkWell(
                    onTap: () {
                      setState(() => sport = sports[i]);
                      if (_sportScrollController.hasClients &&
                          _sportScrollController.position.maxScrollExtent > 0) {
                        final targetOffset = (i * (cardWidth + 10))
                            .clamp(0.0, _sportScrollController.position.maxScrollExtent);
                        _sportScrollController.animateTo(
                          targetOffset,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: sport == sports[i]
                            ? accent
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: sport == sports[i]
                            ? null
                            : Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.15),
                                width: 1,
                              ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 23,
                            child: Center(
                              child: sportIcons[i] == 'padel'
                                  ? SizedBox(
                                      width: 23,
                                      height: 23,
                                      child: ClipRect(
                                        child: Center(
                                          child: Transform.rotate(
                                            angle: 38 * math.pi / 180,
                                            child: FigmaIcon(
                                              'padel',
                                              color: sport == sports[i]
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : FigmaIcon(
                                      sportIcons[i],
                                      color: sport == sports[i]
                                          ? Colors.white
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sports[i],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle(
                              12,
                              weight: FontWeight.w600,
                              color: sport == sports[i]
                                  ? const Color(0xFF171B12)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 44,
            height: 3.5,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFE2DDD5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment(-1.0 + (_sportScrollProgress * 2.0), 0.0),
              child: Container(
                width: 18,
                height: 3.5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final activities = activitiesOf(data)
        .where((a) => a.sport == sport)
        .toList();
    final events = activities.where((a) => a.isEvent).toList(),
        rooms = activities.where((a) => !a.isEvent).toList();
    final joined = data['joined'] as List;
    final expandedHeader =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(13) > 18;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            navigationBottomInset(context),
          ),
          children: [
            Column(
              children: [
                Row(
                  children: [
                    UserAvatar(
                      name: data['name'] as String? ?? 'KLIK User',
                      avatarUrl: data['avatarUrl'] as String?,
                      size: 44,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] as String? ?? 'klik',
                            style: textStyle(
                              18,
                              weight: FontWeight.w800,
                            ).copyWith(height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!expandedHeader) ...[
                            const SizedBox(height: 5),
                            locationLink(context, data['city'] as String),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Ganti tema',
                      child: InkResponse(
                        onTap: () => perform(
                          context,
                          () => ref
                              .read(themeModeProvider.notifier)
                              .toggle(Theme.of(context).brightness),
                        ),
                        child: Theme.of(context).brightness == Brightness.light
                            ? const FigmaIcon('theme')
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.light_mode_outlined,
                                  size: 22,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final notifs = (data['notifications'] as List? ?? []);
                        final incoming = (data['incomingRequests'] as List? ?? []);
                        final hasUnread = notifs.any((n) => n is Map && n['isRead'] != true) || incoming.isNotEmpty;
                        return Tooltip(
                          message: 'Notifikasi',
                          child: InkResponse(
                            onTap: () => context.push('/notifications'),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const FigmaIcon('notification'),
                                if (hasUnread)
                                  Positioned(
                                    right: 11,
                                    top: 10,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF8D28),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.surface,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (expandedHeader) ...[
                  const SizedBox(height: 12),
                  locationLink(context, data['city'] as String),
                ],
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => context.push('/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    FigmaIcon('search', color: secondary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cari ruang, pemain, lapangan, acara…',
                        style: textStyle(13, color: secondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            sportSelector(context),
            const SizedBox(height: 16),
            SectionTitle(
              'Events',
              action: 'Lihat Semua',
              onAction: () => context.push('/search?tab=Acara'),
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              EmptyState(
                'Belum ada event $sport',
                'Buat event pertamamu.',
                action: 'Buat Event',
                onAction: () => context.push('/new/event'),
              )
            else
              EventCarousel(
                events: events,
                joined: joined.cast<String>().toSet(),
              ),
            const SizedBox(height: 8),
            SectionTitle(
              'Ruang Terdekat',
              action: 'Lihat Semua',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 10),
            if (rooms.isEmpty)
              const EmptyState(
                'Belum ada ruang',
                'Coba olahraga lain atau buat ruang baru.',
              ),
            for (final room in rooms.take(2)) ...[
              ActivityCard(room, joined: joined.contains(room.id)),
              const SizedBox(height: 12),
            ],
            RankingPreview(sport: sport),
            const SizedBox(height: 16),
            const LocalNotice(),
          ],
        ),
      ),
    );
  }
}

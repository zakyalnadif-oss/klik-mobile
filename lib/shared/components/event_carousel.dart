import 'package:material_ui/material_ui.dart';

import '../../data/models/activity.dart';
import '../widgets/klik_ui.dart';
import 'activity_card.dart';

class EventCarousel extends StatefulWidget {
  const EventCarousel({
    required this.events,
    this.joined = const {},
    super.key,
  });
  final List<Activity> events;
  final Set<String> joined;

  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  late final ScrollController _scrollController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || widget.events.isEmpty) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemExtent = screenWidth - 58.0 + 12.0;
    final index =
        (_scrollController.offset / itemExtent).round().clamp(0, widget.events.length - 1);
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemExtent = screenWidth - 58.0 + 12.0;
    final target =
        (index * itemExtent).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.events.length > 1;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Tampilkan kartu utama dan kartu berikutnya mengintip rapi di sisi kanan
    final cardWidth = screenWidth - 58.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.events.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == widget.events.length - 1 ? 0 : 12,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      child: ActivityCard(
                        widget.events[i],
                        joined: widget.joined.contains(widget.events[i].id),
                        fillHeight: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasMultiple) ...[
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.events.length,
                (i) {
                  final isSelected = i == _currentIndex;
                  return GestureDetector(
                    onTap: () => _scrollToIndex(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                      color: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 24 : 6,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.16)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

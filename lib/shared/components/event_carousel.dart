import 'package:material_ui/material_ui.dart';

import '../../data/models/activity.dart';
import 'activity_card.dart';

class EventCarousel extends StatelessWidget {
  const EventCarousel({
    required this.events,
    this.joined = const {},
    super.key,
  });
  final List<Activity> events;
  final Set<String> joined;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 70,
                child: ActivityCard(
                  event,
                  joined: joined.contains(event.id),
                  fillHeight: true,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

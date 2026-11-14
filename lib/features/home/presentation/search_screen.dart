import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/components/activity_card.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../../social/presentation/social_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialTab = 'Ruang', super.key});
  final String initialTab;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late String tab;
  String query = '', sport = 'Semua', mode = 'Semua';
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    tab = ['Ruang', 'Rekan', 'Lapangan', 'Acara'].contains(widget.initialTab)
        ? widget.initialTab
        : 'Ruang';
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final found = activitiesOf(data)
        .where(
          (a) =>
              (tab == 'Acara' ? a.isEvent : !a.isEvent) &&
              (sport == 'Semua' || a.sport == sport) &&
              (mode == 'Semua' || a.mode == mode) &&
              '${a.title} ${a.venue} ${a.city}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final people = (data['players'] as List)
        .cast<Map>()
        .where(
          (p) =>
              (sport == 'Semua' || p['sport'] == sport) &&
              '${p['name']} ${p['handle']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final venues = (data['venues'] as List)
        .cast<Map>()
        .where(
          (p) =>
              (sport == 'Semua' || p['sport'] == sport) &&
              '${p['name']} ${p['address']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return KPage(
      title: 'Pencarian',
      children: [
        TextField(
          controller: search,
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'Cari ruang, pemain, lapangan, acara…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: () {
                      search.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final name in ['Ruang', 'Rekan', 'Lapangan', 'Acara'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: tab == name,
                    onSelected: (_) => setState(() => tab = name),
                  ),
                ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: sport,
          decoration: const InputDecoration(labelText: 'Olahraga'),
          items: [
            'Semua',
            ...sports,
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => sport = v!),
        ),
        if (tab == 'Ruang' || tab == 'Acara')
          Wrap(
            spacing: 8,
            children: [
              for (final m in ['Semua', 'Berperingkat', 'Kasual'])
                ChoiceChip(
                  label: Text(m),
                  selected: mode == m,
                  onSelected: (_) => setState(() => mode = m),
                ),
            ],
          ),
        if (tab == 'Ruang' || tab == 'Acara') ...[
          Text(
            '${found.length} hasil ditemukan',
            style: textStyle(12, color: secondary(context)),
          ),
          if (found.isEmpty)
            const EmptyState(
              'Tidak ada hasil',
              'Coba kata kunci atau pilihan olahraga lain.',
            ),
          for (final a in found)
            ActivityCard(a, joined: (data['joined'] as List).contains(a.id)),
        ],
        if (tab == 'Rekan') ...[
          if (people.isEmpty)
            const EmptyState(
              'Pemain tidak ditemukan',
              'Coba nama atau olahraga lain.',
            ),
          for (final p in people) PlayerTile(Map<String, dynamic>.from(p)),
        ],
        if (tab == 'Lapangan') ...[
          if (venues.isEmpty)
            const EmptyState(
              'Lapangan tidak ditemukan',
              'Coba kata kunci lain.',
            ),
          for (final v in venues)
            KCard(
              onTap: () => context.push(
                '/venue/${Uri.encodeComponent(v['name'] as String)}',
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(v['name'] as String),
                subtitle: Text(v['address'] as String),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
        const LocalNotice(),
      ],
    );
  }
}

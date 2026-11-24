import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/local_state.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/search_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/events/presentation/create_screen.dart';
import '../../features/events/presentation/activity_detail_screen.dart';
import '../../features/events/presentation/activity_form_screen.dart';
import '../../features/social/presentation/social_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/team_screen.dart';
import '../../features/tanding/presentation/matches_screen.dart';
import '../../features/tanding/presentation/score_screen.dart';
import '../../features/tanding/presentation/match_teams_screen.dart';
import '../../features/tanding/presentation/score_example_screen.dart';
import '../../features/venues/presentation/venue_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/payments/presentation/checkout_screen.dart';
import '../../features/social/presentation/community_chat_screen.dart';
import '../../features/social/presentation/direct_chat_screen.dart';
import '../../shared/components/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation:
        ref.read(localStateProvider).asData?.value['onboarded'] == true
        ? '/'
        : '/welcome',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/social', builder: (c, s) => const SocialScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/create', builder: (c, s) => const CreateScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (c, s) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (c, s) => const AuthScreen()),
      GoRoute(
        path: '/register',
        builder: (c, s) => const AuthScreen(mode: 'register'),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (c, s) => const AuthScreen(mode: 'reset'),
      ),
      GoRoute(
        path: '/search',
        builder: (c, s) =>
            SearchScreen(initialTab: s.uri.queryParameters['tab'] ?? 'Ruang'),
      ),
      GoRoute(
        path: '/new/:kind',
        builder: (c, s) => ActivityFormScreen(
          kind: s.pathParameters['kind'] == 'event' ? 'event' : 'room',
        ),
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (c, s) => ActivityDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/checkout/:id',
        builder: (c, s) => CheckoutScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:id',
        builder: (c, s) => PlayerScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/score/:id',
        builder: (c, s) => ScoreScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match-teams/:id',
        builder: (c, s) => MatchTeamsScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/venue/:name',
        builder: (c, s) => VenueScreen(name: s.pathParameters['name']!),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (c, s) => const EditProfileScreen(),
      ),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/team', builder: (c, s) => const TeamScreen()),
      GoRoute(
        path: '/score-example',
        builder: (c, s) => const ScoreExampleScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (c, s) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/community-chat/:sport',
        builder: (c, s) {
          final rawSport = s.pathParameters['sport'] ?? 'Futsal';
          return CommunityChatScreen(
            sport: Uri.decodeComponent(rawSport),
          );
        },
      ),
      GoRoute(
        path: '/community-chat',
        builder: (c, s) {
          final sport = s.uri.queryParameters['sport'] ?? 'Futsal';
          return CommunityChatScreen(sport: sport);
        },
      ),
      GoRoute(
        path: '/chat/:friendId',
        builder: (c, s) {
          final friendId = s.pathParameters['friendId']!;
          final q = s.uri.queryParameters;
          return DirectChatScreen(
            friendId: friendId,
            friendName: q['name'] ?? 'Teman',
            friendAvatarUrl: q['avatarUrl'],
            friendInitials: q['initials'],
            friendSport: q['sport'],
          );
        },
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(
        child: TextButton(
          onPressed: () => c.go('/'),
          child: const Text('Kembali ke Beranda'),
        ),
      ),
    ),
  );
  ref.listen(localStateProvider, (previous, next) {
    if (previous?.asData == null &&
        next.asData?.value['onboarded'] == true &&
        router.routeInformationProvider.value.uri.path == '/welcome') {
      router.go('/');
    }
  });
  ref.onDispose(router.dispose);
  return router;
});

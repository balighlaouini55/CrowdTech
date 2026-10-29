import 'package:flutter/material.dart';

import '../models/crowd_models.dart';
import '../modules/events/events_screen.dart';
import '../modules/funding/funding_screen.dart';
import '../modules/marketplace/marketplace_screen.dart';
import '../modules/news/news_screen.dart';
import '../modules/profile/profile_screen.dart';
import 'auth_pages.dart';

class CrowdTechApp extends StatelessWidget {
  const CrowdTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrowdTech',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const WelcomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (context) => _homeForRoute(context),
        '/news': (context) => _homeForRoute(context, initialIndex: 0),
        '/funding': (context) => _homeForRoute(context, initialIndex: 1),
        '/marketplace': (context) => _homeForRoute(context, initialIndex: 2),
        '/events': (context) => _homeForRoute(context, initialIndex: 3),
        '/profile': (context) => _homeForRoute(context, initialIndex: 4),
      },
    );
  }
}

HomePage _homeForRoute(BuildContext context, {int initialIndex = 0}) {
  final arguments = ModalRoute.of(context)?.settings.arguments;
  final user = arguments is CrowdUser
      ? arguments
      : const CrowdUser(
          name: 'Invité',
          email: 'demo@crowdtech.app',
          role: 'Lecteur',
        );
  return HomePage(user: user, initialIndex: initialIndex);
}

class HomePage extends StatefulWidget {
  final CrowdUser user;
  final int initialIndex;
  const HomePage({required this.user, this.initialIndex = 0, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int currentIndex = widget.initialIndex;

  late final screens = [
    NewsScreen(accountKey: widget.user.email),
    FundingScreen(accountKey: widget.user.email),
    MarketplaceScreen(accountKey: widget.user.email),
    EventsScreen(accountKey: widget.user.email),
    ProfileScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) => setState(() => currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.newspaper_rounded),
            label: 'Actus',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_rounded),
            label: 'Crowd',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_rounded),
            label: 'Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_rounded),
            label: 'Événements',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

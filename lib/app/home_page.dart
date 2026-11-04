// Page d'accueil après connexion : tableau de bord et barre de navigation
// entre les modules.

import 'dart:ui' show ImageFilter;

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/app/dashboard_screen.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/modules/events/presentation/events_screen.dart';
import 'package:crowdtech/modules/funding/presentation/funding_screen.dart';
import 'package:crowdtech/modules/marketplace/presentation/marketplace_screen.dart';
import 'package:crowdtech/modules/news/presentation/news_screen.dart';
import 'package:crowdtech/modules/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final CrowdUser user;
  final int initialIndex;
  const HomePage({
    required this.user,
    this.initialIndex = HomeTab.dashboard,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int currentIndex = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    CrowdTechSession.start(widget.user);
  }

  void openTab(int index) => setState(() => currentIndex = index);

  late final screens = [
    // Le tableau de bord est reconstruit à chaque changement d'onglet pour
    // relire ses chiffres quand il redevient visible.
    null,
    NewsScreen(accountKey: widget.user.email),
    FundingScreen(accountKey: widget.user.email),
    MarketplaceScreen(accountKey: widget.user.email),
    EventsScreen(accountKey: widget.user.email),
    ProfileScreen(user: widget.user),
  ];

  /// Couleur de l'indicateur de chaque onglet, dans l'ordre de la barre.
  static const palettes = [
    ModulePalette.home,
    ModulePalette.news,
    ModulePalette.funding,
    ModulePalette.store,
    ModulePalette.events,
    ModulePalette.profile,
  ];

  static const destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Accueil'),
    (Icons.newspaper_outlined, Icons.newspaper_rounded, 'Actus'),
    (Icons.trending_up_rounded, Icons.trending_up_rounded, 'Crowd'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Store'),
    (Icons.event_outlined, Icons.event_rounded, 'Agenda'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = palettes[currentIndex];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: [
          DashboardScreen(
            user: widget.user,
            onOpenTab: openTab,
            active: currentIndex == HomeTab.dashboard,
          ),
          for (final screen in screens.skip(1)) screen!,
        ],
      ),
      // Barre flottante en verre dépoli sombre.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: NavigationBarTheme(
                    data: NavigationBarTheme.of(context).copyWith(
                      backgroundColor: AppColors.surface.withValues(
                        alpha: 0.86,
                      ),
                      indicatorColor: palette.start.withValues(alpha: 0.16),
                      height: 66,
                      iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                          size: 22,
                          color: states.contains(WidgetState.selected)
                              ? palette.start
                              : AppColors.subtle,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      elevation: 0,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      selectedIndex: currentIndex,
                      onDestinationSelected: openTab,
                      destinations: [
                        for (final (icon, selected, label) in destinations)
                          NavigationDestination(
                            icon: Icon(icon),
                            selectedIcon: Icon(selected),
                            label: label,
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
    );
  }
}

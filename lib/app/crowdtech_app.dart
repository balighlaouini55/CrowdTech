// Racine de l'application : thème et routes nommées (/welcome, /login, /news…).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/app/dashboard_screen.dart';
import 'package:crowdtech/app/home_page.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/modules/auth/presentation/login_page.dart';
import 'package:crowdtech/modules/auth/presentation/register_page.dart';
import 'package:crowdtech/modules/auth/presentation/welcome_page.dart';
import 'package:flutter/material.dart';

class CrowdTechApp extends StatelessWidget {
  const CrowdTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrowdTech',
      theme: buildAppTheme(),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const WelcomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (context) => _homeForRoute(context),
        '/news': (context) =>
            _homeForRoute(context, initialIndex: HomeTab.news),
        '/funding': (context) =>
            _homeForRoute(context, initialIndex: HomeTab.funding),
        '/marketplace': (context) =>
            _homeForRoute(context, initialIndex: HomeTab.store),
        '/events': (context) =>
            _homeForRoute(context, initialIndex: HomeTab.events),
        '/profile': (context) =>
            _homeForRoute(context, initialIndex: HomeTab.profile),
      },
    );
  }
}

/// Les écrans de l'application exigent un utilisateur connecté : sans compte
/// (par exemple une adresse saisie directement dans le navigateur), on revient
/// à la page de bienvenue au lieu d'ouvrir une session « invité ».
Widget _homeForRoute(
  BuildContext context, {
  int initialIndex = HomeTab.dashboard,
}) {
  final arguments = ModalRoute.of(context)?.settings.arguments;
  if (arguments is! CrowdUser) return const WelcomePage();
  return HomePage(user: arguments, initialIndex: initialIndex);
}

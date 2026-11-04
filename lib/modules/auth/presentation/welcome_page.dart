// Page de bienvenue : logo, promesse, modules de la plateforme, garanties
// et boutons Connexion / Inscription.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/widgets/fade_slide_in.dart';
import 'package:crowdtech/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const features = [
    (
      ModulePalette.funding,
      Icons.trending_up_rounded,
      'Crowdfunding',
      'Financez des fonctionnalités avec des jetons',
    ),
    (
      ModulePalette.news,
      Icons.fact_check_outlined,
      'Actualités vérifiées',
      'Score de fiabilité calculé par la communauté',
    ),
    (
      ModulePalette.store,
      Icons.storefront_outlined,
      'Marketplace',
      'Paiement sous séquestre jusqu’à réception',
    ),
    (
      ModulePalette.events,
      Icons.qr_code_2_rounded,
      'Événements',
      'Billets et badges d’accès chiffrés',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1),
            radius: 1.3,
            colors: [Color(0xFF231F52), AppColors.background],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.1, 1.1),
              radius: 1.1,
              colors: [Color(0x332DD4A7), Color(0x002DD4A7)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FadeSlideIn(child: _Logo()),
                      const SizedBox(height: 36),
                      const FadeSlideIn(
                        index: 1,
                        child: Text(
                          'Investissez dans\nl’innovation tech.',
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.9,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 2,
                        child: Text(
                          'Projets, actualités, matériel et événements : '
                          'tout l’écosystème tech dans une seule application.',
                          style: AppText.body.copyWith(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        index: 3,
                        child: Container(
                          decoration: cardDecoration(),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (final (index, (palette, icon, title, text))
                                  in features.indexed) ...[
                                if (index > 0)
                                  const Divider(indent: 72, height: 1),
                                _FeatureRow(
                                  palette: palette,
                                  icon: icon,
                                  title: title,
                                  text: text,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        index: 4,
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/login'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text('Se connecter'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/register'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text('Créer un compte'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: AppColors.subtle,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Mots de passe chiffrés · données sécurisées',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subtle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Logo : monogramme en dégradé et nom de la plateforme.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.success],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'CrowdTech',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final ModulePalette palette;
  final IconData icon;
  final String title;
  final String text;
  const _FeatureRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ModuleIcon(icon: icon, palette: palette, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.subtitle.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(text, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

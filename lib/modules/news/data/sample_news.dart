// Actualités d'exemple insérées au premier lancement : sources et niveaux
// de fiabilité variés (très fiable ≥ 75 %, fiable ≥ 50 %, à vérifier).

import 'package:crowdtech/modules/news/domain/news_item.dart';

const sampleNews = [
  NewsItem(
    title: 'L’IA générative transforme le développement',
    source: 'Tech Daily',
    credibility: 96,
    tag: 'IA',
    summary: 'Les assistants de code accélèrent les tâches répétitives.',
    author: 'Sarah Ben Ali',
    publishedAt: '2026-10-28',
  ),
  NewsItem(
    title: 'Les startups renforcent leur sécurité par passkeys',
    source: 'Cyber Weekly',
    credibility: 92,
    tag: 'Sécurité',
    summary: 'Les entreprises migrent vers des mécanismes plus sûrs.',
    author: 'Karim Haddad',
    publishedAt: '2026-10-25',
  ),
  NewsItem(
    title: 'Le cloud hybride gagne du terrain',
    source: 'Cloud Lab',
    credibility: 90,
    tag: 'Cloud',
    summary: 'Les PME cherchent un équilibre coût-flexibilité.',
    author: 'Lina Trabelsi',
    publishedAt: '2026-10-20',
  ),
  NewsItem(
    title: 'La Tunisie lance un fonds d’amorçage pour les startups deep tech',
    source: 'Startup Maghreb',
    credibility: 88,
    tag: 'Startups',
    summary:
        'Un fonds public-privé de 50 M€ cible l’IA, la santé numérique et '
        'l’agritech, avec des tickets de 100 000 à 500 000 €.',
    author: 'Youssef Mejri',
    publishedAt: '2026-10-30',
  ),
  NewsItem(
    title: 'Des puces RISC-V dans les ordinateurs portables grand public',
    source: 'Hardware Insider',
    credibility: 84,
    tag: 'Matériel',
    summary:
        'Deux fabricants annoncent des portables basés sur l’architecture '
        'ouverte RISC-V pour le premier semestre 2027.',
    author: 'Marc Dubois',
    publishedAt: '2026-10-27',
  ),
  NewsItem(
    title: 'Flutter 4 : rendu plus rapide et nouvelles animations',
    source: 'Mobile Dev Mag',
    credibility: 91,
    tag: 'Mobile',
    summary:
        'Le nouveau moteur de rendu réduit les saccades sur les téléphones '
        'd’entrée de gamme.',
    author: 'Amira Gharbi',
    publishedAt: '2026-10-22',
  ),
  NewsItem(
    title: 'Les centres de données passent au refroidissement liquide',
    source: 'Green IT Report',
    credibility: 79,
    tag: 'Green tech',
    summary:
        'La consommation d’eau et d’énergie baisse de 30 % dans les sites '
        'pilotes européens.',
    author: 'Nadia Bouzid',
    publishedAt: '2026-10-18',
  ),
  NewsItem(
    title: 'Fuite de données chez un réseau social : 2 millions de comptes',
    source: 'Cyber Weekly',
    credibility: 73,
    tag: 'Sécurité',
    summary:
        'Les mots de passe étaient chiffrés, mais les emails et numéros de '
        'téléphone ont été exposés. Changez vos identifiants par précaution.',
    author: 'Karim Haddad',
    publishedAt: '2026-10-15',
  ),
  NewsItem(
    title: 'Les paiements par jetons séduisent le crowdfunding',
    source: 'FinTech Lab',
    credibility: 68,
    tag: 'Fintech',
    summary:
        'De plus en plus de plateformes financent les projets fonctionnalité '
        'par fonctionnalité, avec des jetons à prix fixe.',
    author: 'Hichem Ayari',
    publishedAt: '2026-10-12',
  ),
  NewsItem(
    title: 'Un smartphone qui se recharge en 5 minutes ?',
    source: 'Gadget Buzz',
    credibility: 56,
    tag: 'Mobile',
    summary:
        'Un prototype chinois promet une charge complète en 5 minutes. Les '
        'mesures indépendantes ne sont pas encore publiées.',
    author: 'Rédaction Gadget Buzz',
    publishedAt: '2026-10-10',
  ),
  NewsItem(
    title: 'Une IA aurait remplacé toute une équipe de développeurs',
    source: 'Forum TechTalk',
    credibility: 41,
    tag: 'IA',
    summary:
        'Rumeur partagée sur les réseaux sociaux, démentie en partie par '
        'l’entreprise concernée. À vérifier avant de la partager.',
    author: 'Anonyme',
    publishedAt: '2026-10-08',
  ),
  NewsItem(
    title: 'Le bitcoin interdit dans toute l’Afrique du Nord ?',
    source: 'Crypto Rumeurs',
    credibility: 28,
    tag: 'Fintech',
    summary:
        'Aucune source officielle ne confirme cette information : les '
        'lecteurs la signalent comme trompeuse.',
    author: 'Anonyme',
    publishedAt: '2026-10-05',
  ),
];

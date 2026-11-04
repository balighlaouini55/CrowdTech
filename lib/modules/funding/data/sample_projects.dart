// Projets d'exemple insérés au premier lancement : secteurs, villes et
// avancements variés. La progression correspond au montant collecté.

import 'package:crowdtech/modules/funding/domain/funding_project.dart';

const _cdn = 'https://cdn.dummyjson.com/product-images';

const sampleProjects = [
  FundingProject(
    title: 'AI Ops Dashboard',
    company: 'NovaStack',
    amountRaised: 42000,
    goal: 80000,
    tokenPrice: 45,
    progress: 52,
    feature: 'Supprimer les tâches répétitives',
    category: 'IA',
    description:
        'Un tableau de bord qui détecte et automatise les opérations '
        'répétitives des équipes DevOps.',
    deadline: '2027-06-30',
    stage: 'Prototype',
    location: 'Paris',
    teamSize: 6,
    imageUrl:
        '$_cdn/laptops/asus-zenbook-pro-dual-screen-laptop/thumbnail.webp',
  ),
  FundingProject(
    title: 'Green Pulse Sensor',
    company: 'EcoByte',
    amountRaised: 65000,
    goal: 95000,
    tokenPrice: 30,
    progress: 68,
    feature: 'Analyse des données environnementales',
    category: 'Green tech',
    description:
        'Capteurs connectés à bas coût pour mesurer la qualité de l’air '
        'dans les villes.',
    deadline: '2027-09-15',
    stage: 'Lancé',
    location: 'Tunis',
    teamSize: 4,
    imageUrl: '$_cdn/home-decoration/house-showpiece-plant/thumbnail.webp',
  ),
  FundingProject(
    title: 'MediScan Mobile',
    company: 'HealthLoop',
    amountRaised: 18500,
    goal: 60000,
    tokenPrice: 25,
    progress: 31,
    feature: 'Lecture des ordonnances par la caméra',
    category: 'Santé',
    description:
        'Application qui lit une ordonnance, rappelle les prises de '
        'médicaments et alerte en cas d’interaction dangereuse.',
    deadline: '2027-05-20',
    stage: 'Idée',
    location: 'Sfax',
    teamSize: 3,
    imageUrl: '$_cdn/smartphones/oppo-f19-pro-plus/thumbnail.webp',
  ),
  FundingProject(
    title: 'AgriDrone Tunisie',
    company: 'SkyFarm',
    amountRaised: 88000,
    goal: 110000,
    tokenPrice: 60,
    progress: 80,
    feature: 'Carte d’irrigation parcelle par parcelle',
    category: 'Agritech',
    description:
        'Drones qui photographient les oliveraies et indiquent les zones à '
        'irriguer pour économiser jusqu’à 25 % d’eau.',
    deadline: '2027-03-31',
    stage: 'Lancé',
    location: 'Sousse',
    teamSize: 8,
    imageUrl:
        '$_cdn/mobile-accessories/tv-studio-camera-pedestal/thumbnail.webp',
  ),
  FundingProject(
    title: 'SafeKey Passwordless',
    company: 'CipherNest',
    amountRaised: 27000,
    goal: 50000,
    tokenPrice: 40,
    progress: 54,
    feature: 'Connexion sans mot de passe par passkey',
    category: 'Cybersécurité',
    description:
        'Module à intégrer dans n’importe quelle application pour remplacer '
        'les mots de passe par des passkeys.',
    deadline: '2027-04-15',
    stage: 'Prototype',
    location: 'Lyon',
    teamSize: 5,
    imageUrl: '$_cdn/mobile-accessories/apple-iphone-charger/thumbnail.webp',
  ),
  FundingProject(
    title: 'EduCode Kids',
    company: 'LearnPixel',
    amountRaised: 9600,
    goal: 30000,
    tokenPrice: 15,
    progress: 32,
    feature: 'Parcours de programmation pour les 8–12 ans',
    category: 'Éducation',
    description:
        'Jeux de logique qui apprennent à coder sans écran au début, puis '
        'sur tablette, en français et en arabe.',
    deadline: '2027-08-31',
    stage: 'Idée',
    location: 'Tunis',
    teamSize: 3,
    imageUrl: '$_cdn/tablets/samsung-galaxy-tab-white/thumbnail.webp',
  ),
  FundingProject(
    title: 'VoltShare Recharge',
    company: 'GridMates',
    amountRaised: 51000,
    goal: 75000,
    tokenPrice: 35,
    progress: 68,
    feature: 'Réservation de bornes entre voisins',
    category: 'Mobilité',
    description:
        'Les particuliers partagent leur borne de recharge électrique et '
        'sont payés à la minute.',
    deadline: '2027-07-10',
    stage: 'Prototype',
    location: 'Marseille',
    teamSize: 7,
    imageUrl:
        '$_cdn/mobile-accessories/apple-airpower-wireless-charger/thumbnail.webp',
  ),
  FundingProject(
    title: 'HomeVoice Assistant',
    company: 'Smartia',
    amountRaised: 36000,
    goal: 40000,
    tokenPrice: 20,
    progress: 90,
    feature: 'Commandes vocales hors connexion',
    category: 'IoT',
    description:
        'Assistant vocal qui fonctionne sans Internet : les conversations '
        'restent dans la maison.',
    deadline: '2027-02-28',
    stage: 'Lancé',
    location: 'Bordeaux',
    teamSize: 5,
    imageUrl: '$_cdn/mobile-accessories/amazon-echo-plus/thumbnail.webp',
  ),
];

// Événements d'exemple insérés au premier lancement : conférences,
// ateliers, salons et hackathons, gratuits ou payants, en France et en
// Tunisie (adresses réelles, placées sur la carte par Nominatim).

import 'package:crowdtech/modules/events/domain/event_item.dart';

const sampleEvents = [
  EventItem(
    title: 'Tech Innovation Summit',
    date: '12/03/2027',
    city: 'Paris',
    seats: 80,
    time: '09:30',
    venue: 'Station F, 5 parvis Alan Turing',
    price: 0,
    category: 'Conférence',
    description: 'Keynotes et démonstrations des startups deep tech.',
  ),
  EventItem(
    title: 'Startup & AI Forum',
    date: '18/04/2027',
    city: 'Lyon',
    seats: 36,
    time: '14:00',
    venue: 'H7, 70 quai Perrache',
    price: 25,
    category: 'Atelier',
    description: 'Ateliers pratiques pour intégrer l’IA dans un produit.',
  ),
  EventItem(
    title: 'Hackathon FinTech 48 h',
    date: '05/12/2026',
    city: 'Tunis',
    seats: 60,
    time: '09:00',
    venue: 'Cité de l’innovation, Les Berges du Lac',
    price: 10,
    category: 'Hackathon',
    description:
        'Équipes de 4 : construire en 48 h un service de paiement ou de '
        'crowdfunding. 3 prix pour les meilleurs prototypes.',
  ),
  EventItem(
    title: 'Salon des objets connectés',
    date: '22/01/2027',
    city: 'Sfax',
    seats: 150,
    time: '10:00',
    venue: 'Parc des expositions de Sfax',
    price: 5,
    category: 'Salon',
    description:
        'Plus de 40 exposants : domotique, santé connectée, agriculture '
        'intelligente.',
  ),
  EventItem(
    title: 'Masterclass cybersécurité',
    date: '14/02/2027',
    city: 'Paris',
    seats: 25,
    time: '18:30',
    venue: 'Campus Cyber, 5 rue Bellini, Puteaux',
    price: 40,
    category: 'Atelier',
    description:
        'Deux heures pour tester ses applications contre les attaques les '
        'plus courantes, avec un expert en sécurité.',
  ),
  EventItem(
    title: 'Meetup Flutter Tunisie',
    date: '10/12/2026',
    city: 'Sousse',
    seats: 12,
    time: '19:00',
    venue: 'Novation City, Sousse',
    price: 0,
    category: 'Meetup',
    description:
        'Présentations courtes et échanges entre développeurs mobiles. '
        'Petite salle : inscrivez-vous vite !',
  ),
  EventItem(
    title: 'Journée Green IT',
    date: '20/03/2027',
    city: 'Bordeaux',
    seats: 70,
    time: '09:00',
    venue: 'Darwin Écosystème, 87 quai des Queyries',
    price: 15,
    category: 'Conférence',
    description:
        'Réduire l’empreinte carbone du numérique : mesure, sobriété et '
        'retours d’expérience.',
  ),
  EventItem(
    title: 'Pitch Night Investisseurs',
    date: '28/05/2027',
    city: 'Marseille',
    seats: 45,
    time: '19:30',
    venue: 'The Camp, Aix-en-Provence',
    price: 20,
    category: 'Networking',
    description:
        'Dix startups présentent leur projet en 5 minutes devant un jury '
        'd’investisseurs, puis cocktail.',
  ),
];

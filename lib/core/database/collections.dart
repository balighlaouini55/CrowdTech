// Liste des collections enregistrées dans SQLite, avec leur module et leur
// nom lisible (utilisés par le journal des opérations).

/// Collection → module de l'application.
const collectionModules = {
  'news': 'Actualités',
  'news_comments': 'Actualités',
  'news_votes': 'Actualités',
  'funding': 'Crowdfunding',
  'investments': 'Crowdfunding',
  'token_packs': 'Crowdfunding',
  'simulations': 'Crowdfunding',
  'products': 'Marketplace',
  'cart': 'Marketplace',
  'orders': 'Marketplace',
  'events': 'Événements',
  'reservations': 'Événements',
  'profiles': 'Profil',
  'accounts': 'Compte',
};

/// Collection → nom d'un élément (« Ajout produit », « Suppression projet »…).
const collectionEntities = {
  'news': 'actualité',
  'news_comments': 'commentaire',
  'news_votes': 'évaluation',
  'funding': 'projet',
  'investments': 'investissement',
  'token_packs': 'pack de jetons',
  'simulations': 'simulation',
  'products': 'produit',
  'cart': 'article du panier',
  'orders': 'commande',
  'events': 'événement',
  'reservations': 'réservation',
  'profiles': 'profil',
  'accounts': 'compte',
};

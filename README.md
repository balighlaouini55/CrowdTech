# CrowdTech

CrowdTech est une application Flutter qui réunit quatre espaces : actualités
tech et évaluation de crédibilité, financement par jetons, marketplace et
réservations d’événements. Les contenus des quatre modules sont stockés dans une
base SQLite locale via sqflite. L’application n’est pas encore reliée à Firebase
ni aux services externes du sujet.

## Lancer l’application

Depuis ce dossier, avec Flutter installé :

```powershell
flutter pub get
flutter devices
flutter run -d <ID_APPAREIL>
```

## Plateformes et installation

Sqflite fonctionne avec Android et iOS (ainsi que macOS). Pour le Web, le
projet utilise `sqflite_common_ffi_web`, qui conserve SQLite dans le stockage
IndexedDB du navigateur.
L’application et ses tests utilisent les dépendances déjà déclarées dans
`pubspec.yaml` : `sqflite` et `path`. La base SQLite est embarquée ; il n’y a pas
de serveur SQLite à installer.

1. Installer Flutter et Android Studio.
2. Dans Android Studio, installer Android SDK, Platform-Tools et créer un
   émulateur, ou brancher un téléphone avec le débogage USB activé.
3. Depuis `C:\Users\MSI\CrowdTech`, exécuter `flutter pub get`, puis
   `dart run sqflite_common_ffi_web:setup` pour installer les fichiers SQLite
   Web dans `web`. Exécuter également `flutter doctor --android-licenses` et
   accepter les licences Android si tu utilises Android.
4. Vérifier l’appareil avec `flutter devices`, puis lancer
   `flutter run -d <ID_APPAREIL>`.
5. Pour iOS, ouvrir et construire le projet sur macOS avec Xcode installé.

Pour Chrome, lancer `flutter run -d chrome`. La base Web est conservée dans
l’IndexedDB du navigateur et dépend de l’adresse et du port utilisés
(par exemple `localhost:8080` et `localhost:8081` ont des bases différentes).
Windows desktop ne prend pas en charge le plugin configuré. La compilation
iOS/macOS nécessite un Mac avec Xcode.

## Persistance SQLite

- `lib/data/crowdtech_database.dart` ouvre `crowdtech.db` dans le répertoire
  privé de l’application mobile ou dans IndexedDB pour Chrome. La version de
  schéma est gérée à l’ouverture (`2`) avec une migration d’index.
- Les contenus initiaux sont insérés une seule fois par module. Actualités,
  projets, produits et événements ajoutés depuis l’interface sont relus au
  prochain démarrage.
- Les commentaires sont enregistrés et rechargés depuis SQLite.
- Les évaluations positives des actualités mettent à jour leur score dans
  SQLite.
- Le panier est restauré au démarrage ; la commande et le vidage du panier sont
  enregistrés ensemble dans une transaction SQLite.
- Les réservations et numéros de pass de démonstration sont enregistrés ; les
  places et l’état « Réservé » sont restaurés au prochain lancement.
- Le nom et l’email du profil sont sauvegardés localement par utilisateur de
  démonstration.
- Chaque investissement et la mise à jour de la collecte sont enregistrés
  ensemble dans SQLite.
- Le service propose lecture, insertion, mise à jour et suppression pour les
  données.

Pour vérifier les tests et l’analyse :

```powershell
flutter test
flutter analyze
```

## Parcours disponibles

- Routes nommées : `/welcome`, `/login`, `/register`, `/home`, `/news`,
  `/funding`, `/marketplace`, `/events` et `/profile`.
- Le code est réparti par responsabilité : `lib/main.dart` démarre l’app,
  `lib/app/` contient les routes et l’authentification de démonstration,
  `lib/modules/` sépare Actualités, Crowdfunding, Marketplace, Événements et
  Profil, et `lib/models/` contient les modèles. Chaque module a ses propres
  formulaires et sa propre page de gestion CRUD : par exemple
  `news_article_form_page.dart` et `news_management_page.dart`, sans formulaire
  ou actions Modifier/Supprimer génériques partagés entre les étudiants. Le
  Marketplace sépare également le panier, la commande, le catalogue et le profil
  vendeur. Les fichiers de gestion sont :
  `modules/news/news_management_page.dart` et `news_article_form_page.dart`,
  `modules/funding/funding_management_page.dart` et
  `funding_project_form_page.dart`,
  `modules/marketplace/marketplace_management_page.dart` et
  `marketplace_product_form_page.dart`, `modules/events/events_management_page.dart`
  et `event_form_page.dart`. Le financement, les commentaires et les réservations
  ont aussi leurs formulaires dédiés. `lib/data/crowdtech_database.dart` reste le
  service SQLite commun ; `lib/shared/` ne contient que les vues secondaires
  réutilisées (détails, historiques et erreurs). Une future API pourra remplacer
  ce service de persistance ; les appels des modules devront alors être adaptés
  à cette API.
- Accueil et navigation vers connexion ou inscription.
- Validation des champs, des formats d’email et d’un mot de passe d’au moins
  huit caractères contenant une lettre et un chiffre.
- Navigation par onglets entre Actus, Crowd, Store, Événements et Profil.
- Chargement des exemples et persistance locale des contenus des quatre modules
  avec SQLite.
- Recherche locale dans les actualités et vote positif de démonstration.
- Détails, création, modification et suppression des articles depuis la page
  « Gérer tous les articles », avec les pages de discussion et de scores.
- Saisie et filtrage local des commentaires : longueur minimale, limite de
  caractères et rejet des liens dans la démonstration.
- Ajout d’actualités via le bouton « + » de l’écran Actualités ; le nouvel
  article est marqué « À vérifier » jusqu’à une évaluation.
- Saisie du nombre de jetons, contrôle du plafond de financement et mise à jour
  de la collecte et de l’historique d’investissements dans SQLite.
- Ajout de projets avec nom, entreprise, objectif, prix par jeton et
  fonctionnalité financée.
- Détails et gestion des projets, historique/portefeuille des investissements
  et simulateur de rendement.
- Recherche de produits, ajout au panier, calcul du total et formulaire de
  commande validant le nom, l’email et l’adresse.
- Ajout de produits avec nom, catégorie et prix ; les nouveaux produits sont
  affichés sans avis.
- Pages dédiées aux détails produits, au panier, au paiement simulé, au suivi
  et à l’historique des commandes, aux produits du vendeur et à son profil.
- Formulaire de réservation événementielle avec validation du nom et de l’email,
  puis affichage d’un pass de démonstration.
- Ajout d’événements avec nom, date, ville et nombre de places.
- Détails et gestion des événements, liste des billets, page de badge QR de
  démonstration et contrôle local des entrées.
- Modification locale du nom et de l’email du profil avec validation.
- Pages dédiées à la modification du profil, à la réinitialisation simulée du
  mot de passe et à l’historique des achats.
- Page de gestion des utilisateurs et rôles en démonstration uniquement.

## Limites du prototype

Toutes les données présentées comme sauvegardées dans la section SQLite restent
uniquement sur l’appareil et ne sont pas synchronisées avec d’autres appareils.
La connexion et l’inscription ne créent ni ne vérifient encore de vrais comptes.
Le paiement et le billet QR restent des démonstrations et ne sont pas valables
pour une transaction ou un accès réel. Le rôle Admin ne peut pas être
choisi depuis l’inscription ; l’écran local de gestion des rôles n’accorde
aucune autorisation réelle et un serveur doit contrôler les rôles.
Les commandes, investissements, votes, billets et réinitialisations sont des
simulations et ne doivent pas être utilisés comme services réels. Les chiffres
du profil non disponibles sont affichés comme « — » plutôt qu’inventés.

Pour ajouter du contenu, ouvrez Actualités, Crowdfunding, Marketplace ou
Événements, appuyez sur l’icône « + » en haut à droite et remplissez le
formulaire. Les champs obligatoires et les montants sont validés avant
l’enregistrement dans SQLite. Pour modifier les exemples proposés lors du
premier lancement, changez les listes `sampleItems`, `sampleProjects`,
`marketplaceSampleProducts` ou `sampleEvents` dans les fichiers respectifs
`lib/modules/news/news_screen.dart`,
`lib/modules/funding/funding_screen.dart`,
`lib/modules/marketplace/marketplace_catalog.dart` et
`lib/modules/events/events_screen.dart`.

## À configurer avant une utilisation réelle

1. **Firebase Auth et Firestore** : créer un projet Firebase, configurer les
   applications Android/iOS/Web, ajouter les fichiers d’options Firebase avec
   FlutterFire CLI, activer les méthodes d’authentification nécessaires, puis
   définir des règles Firestore vérifiant l’identité et les rôles côté serveur.
   Ne jamais considérer un rôle venant du formulaire comme une autorisation.
2. **Données et API** : connecter les actus à Hacker News API, les images à
   Firebase Storage, les taux de change à ExchangeRate-API et les événements
   aux services de carte/géocodage. Vérifier les licences, limites de requêtes
   et politiques de confidentialité avant de publier.
3. **Financement et marketplace** : définir le modèle métier et le paiement avec
   un fournisseur adapté. Ne pas traiter des paiements ou promettre un ROI avec
   les calculs de démonstration. L’escrow réel requiert un backend et des
   garanties juridiques.
4. **Billets et notifications** : générer et valider les QR côté serveur avec
   une signature et une expiration ; configurer Firebase Cloud Messaging et
   demander les autorisations de notification sur les appareils.
5. **Persistance, sécurité et livraison** : ajouter les dépôts/services par
   module, les règles d’accès, la gestion des erreurs réseau, les tests
   d’intégration, les secrets de configuration hors du dépôt et les tests sur
   appareils Android/iOS réels.

Les tests disponibles vérifient les validations, les routes, les onglets et les
parcours de démonstration. Ils ne remplacent pas les tests contre Firebase ni
les essais sur appareils physiques.

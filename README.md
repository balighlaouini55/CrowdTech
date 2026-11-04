# CrowdTech

CrowdTech est une application Flutter qui réunit quatre espaces : actualités
tech et évaluation de crédibilité, financement par jetons, marketplace et
réservations d’événements. Les contenus sont stockés dans une base SQLite locale
via sqflite, et partagés entre appareils par Firebase (plan Spark) lorsque
`config.json` est renseigné.

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

**Windows (recommandé pour une vraie base unique)** : `flutter run -d windows`.
SQLite est utilisé via FFI et toutes les données sont dans un seul fichier,
`%APPDATA%\CrowdTech\crowdtech.db`, conservé entre les lancements. Le
« Mode développeur » de Windows doit être activé (`start ms-settings:developers`).

Pour Chrome, lancer `flutter run -d chrome --web-port 8080`. La base Web est
conservée dans l’IndexedDB du navigateur et dépend de l’adresse et du port
utilisés (`localhost:8080` et `localhost:8081` ont des bases différentes) :
il faut donc toujours garder le même port. La compilation iOS/macOS nécessite
un Mac avec Xcode.

## Persistance SQLite

- `lib/core/database/crowdtech_database.dart` ouvre `crowdtech.db` dans le répertoire
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
- Les packs de jetons du crowdfunding (collection `token_packs`) sont
  enregistrés dans SQLite et gérés depuis Crowd → menu → « Gérer les packs de
  jetons » (ajout, modification, suppression, validation des valeurs).

## Interface et champs métier

- Thème unique dans `lib/app/app_theme.dart` (couleurs, champs, boutons,
  cartes, navigation) et composants partagés dans
  `lib/shared/widgets/` et `lib/shared/utils/` (badges de statut, sections de formulaire,
  sélecteur de date, état vide, formats de date et de montant).
- Formulaires organisés en sections, bouton « Enregistrer » toujours visible,
  validations détaillées.
- Champs par gestion :

| Gestion | Champs |
|---|---|
| Actualités | titre, source, catégorie, résumé, auteur, lien (http/https), date de publication |
| Projets | nom, entreprise, objectif, prix du jeton (≤ objectif), fonctionnalité, catégorie, description, date limite |
| Produits | nom, catégorie, prix, marque, stock, état (neuf / reconditionné / occasion), description |
| Événements | nom, date, ville, places, heure, lieu, prix du billet (0 = gratuit), type, programme |
| Profil | nom, email, téléphone, ville, entreprise / école, bio |

- Règles métier : collecte clôturée après la date limite (investissement
  bloqué), statut Financé / En cours / Clôturé et compte à rebours J-n ;
  stock contrôlé à l’ajout au panier et diminué dans la même transaction que
  la commande ; badge de fiabilité coloré selon le score ; jauge de
  remplissage et état « Complet » pour les événements.
- Les pages de gestion ont une recherche et un compteur ; la page de détail
  masque les champs techniques et affiche dates et montants formatés.

## Inscription

Le formulaire d’inscription (`lib/modules/auth/presentation/register_page.dart`) demande :

| Section | Champs |
|---|---|
| L’essentiel | nom complet, email, mot de passe + confirmation, rôle (Lecteur, Investisseur, Porteur de projet) |
| Mes coordonnées | date de naissance (16 ans minimum), téléphone, adresse, ville, code postal (4–5 chiffres), pays |
| Pour finir | code de parrainage (facultatif), case « J’accepte les conditions d’utilisation » |

Tous ces champs sont obligatoires (sauf le code de parrainage). Ils sont
enregistrés avec le compte puis repris dans le profil, où ils restent modifiables (Profil → « Modifier mon profil »).

## Préremplissage des commandes et réservations

`AccountService.contactOf` réunit les coordonnées du compte : le profil est
prioritaire et chaque champ vide est complété par les informations de
l’inscription.

- **Commande** (`checkout_page.dart`) : nom, email, téléphone, adresse,
  ville, code postal et pays sont préremplis et restent modifiables.
  « Reprendre mes infos » rétablit les valeurs du compte ; la case
  « Enregistrer cette adresse dans mon profil » (cochée par défaut si aucune
  adresse n’est connue) mémorise l’adresse pour la prochaine commande.
- **Réservation d’événement** : nom et email du participant préremplis.
- **Profil** : une carte « Complétez votre profil » indique les informations
  facultatives encore manquantes.

## Rôles et droits d’accès

Les règles sont centralisées dans `lib/core/auth/permissions.dart`.

| Action | Qui peut ? |
|---|---|
| Lire, commenter, acheter, investir, réserver | Tout le monde |
| Publier une actualité, vendre un produit | Tout le monde |
| Publier un projet, organiser un événement | Porteur de projet, Admin |
| Modifier / supprimer un élément | Son auteur, Admin |
| Packs de jetons, rôles, import Internet, contrôle des billets | Admin uniquement |

- Un compte administrateur est créé automatiquement :
  **admin@crowdtech.app / Admin1234**. Ce mot de passe doit être changé dès la
  première connexion. Personne ne peut s’inscrire directement comme Admin.
- Seul l’administrateur change le rôle d’un compte (Profil → « Utilisateurs
  et rôles ») ; le badge du profil suit ce rôle à la prochaine connexion.
- Chaque utilisateur a son propre panier, ses propres réservations et ne peut
  évaluer une actualité qu’une seule fois.

## Comptes et journal des opérations

- `lib/core/auth/account_service.dart` enregistre les comptes dans la collection
  `accounts` : email unique (insensible à la casse), mot de passe jamais stocké
  en clair (SHA-256 salé, 2 000 itérations, paquet `crypto`). La connexion
  vérifie l’email et le mot de passe.
- « Mot de passe oublié ? » exige une preuve : lien par email avec Firebase ;
  en mode local, date de naissance et téléphone donnés à l’inscription. Cette
  vérification locale est plus faible qu’un email. Un compte administrateur
  change son mot de passe uniquement une fois connecté.
- Chaque écriture SQLite (ajout, modification, suppression, achat de pack,
  commande, import Internet, connexion, échec de connexion, déconnexion,
  simulation) est ajoutée automatiquement à la collection `activity_log` avec
  l’utilisateur, le module, l’action et la date.
- Profil → « Historique des opérations » affiche ce journal, filtrable par
  module. Les statistiques du profil (projets, jetons, opérations) sont
  calculées à partir de SQLite.

## Communication HTTP

`lib/core/network/crowdtech_api.dart` utilise le paquet `http` pour interroger des API
publiques sans clé. Chaque page de gestion a un bouton dans sa barre d’outils ;
les données reçues sont enregistrées dans SQLite (sans doublons, dans une
transaction) et restent disponibles hors connexion.

| Gestion | API | Action |
|---|---|---|
| Actualités | Hacker News | Importe les meilleurs articles tech |
| Crowdfunding | GitHub Search | Importe des projets open source IA |
| Marketplace | DummyJSON | Importe ordinateurs et smartphones |
| Événements | Open-Meteo Geocoding | Vérifie les villes, enregistre pays et coordonnées |

Les erreurs réseau (pas de connexion, délai de 15 s, réponse invalide) sont
affichées à l’utilisateur. Les tests remplacent `CrowdTechApi.client` par un
`MockClient` : aucun appel réseau réel n’est fait pendant `flutter test`.

Pour vérifier les tests et l’analyse :

```powershell
flutter test
flutter analyze
```

## Architecture du code

Règles suivies partout, pour que le projet soit simple à lire et à apprendre :

1. **Un fichier = une responsabilité** (une page, un composant ou un modèle).
2. **Le nom de la classe correspond au nom du fichier** :
   `project_form_page.dart` contient `ProjectFormPage`.
3. **Chaque fichier commence par un commentaire** qui explique son rôle.
4. **Mêmes noms de pages dans chaque module** : `<module>_screen` (écran
   principal), `<élément>_form_page` (formulaire d’ajout / modification),
   `<élément>_management_page` (liste à modifier / supprimer) et `widgets/`
   (cartes et petits composants du module).

L’arborescence à jour est décrite dans « Organisation du code ».

Le parcours d’une donnée, par exemple l’ajout d’un produit :
`marketplace_screen` (bouton +) → `product_form_page` (saisie + validation) →
`MarketplaceRepository` (SQLite + journal) → retour à la liste.

## Parcours disponibles

- Routes nommées : `/welcome`, `/login`, `/register`, `/home`, `/news`,
  `/funding`, `/marketplace`, `/events` et `/profile`.
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
- Achat de packs de jetons (bonus, réduction), contrôle du plafond de financement et mise à jour
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
Les comptes sont locaux à l’appareil (aucun serveur d’authentification).
Le paiement et le billet QR restent des démonstrations et ne sont pas valables
pour une transaction ou un accès réel. Le rôle Admin ne peut pas être
choisi depuis l’inscription ; l’écran local de gestion des rôles n’accorde
aucune autorisation réelle et un serveur doit contrôler les rôles.
Les commandes, investissements, votes, billets et réinitialisations sont des
simulations et ne doivent pas être utilisés comme services réels. Les chiffres
du profil sont calculés à partir des données SQLite de l’utilisateur.

Pour ajouter du contenu, ouvrez Actualités, Crowdfunding, Marketplace ou
Événements, appuyez sur l’icône « + » en haut à droite et remplissez le
formulaire. Les champs obligatoires et les montants sont validés avant
l’enregistrement dans SQLite. Pour modifier les exemples proposés lors du
premier lancement, changez les fichiers `sample_*.dart` du dossier `data/` de
chaque module.

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

## Assistant Crowdy (Gemini)

Dans Crowdfunding, l’icône 🤖 « Assistant Crowdy » ouvre un chatbot qui ne
répond qu’aux questions sur le crowdfunding, les projets, les packs de jetons
et l’investissement (`lib/modules/funding/domain/crowd_assistant.dart`).

- IA : Google Gemini, offre gratuite. Créer une clé sur
  https://aistudio.google.com/apikey puis la coller dans `config.json`
  (fichier ignoré par git, modèle : `config.example.json`).
- Lancement : `flutter run -d windows --dart-define-from-file=config.json`
  (déjà configuré dans `.vscode/launch.json`).
- Modèles essayés dans l’ordre : gemini-3.6-flash, puis les « Lite »
  (gemini-flash-lite-latest, gemini-3.1-flash-lite), qui ont leur propre
  quota gratuit. Un modèle au quota épuisé (429) ou trop lent est mis de côté
  10 minutes. `GEMINI_MODEL` permet d’imposer un modèle.
- En mode secours, la bulle indique la raison : quota épuisé, clé absente
  ou refusée, délai dépassé, pas de connexion.
- Bouton 💡 : idées de questions par thème (agir, mon compte, choisir un
  projet, argent et risques, fonctionnement). Crowdy connaît aussi les
  données du compte : investissements, plafond, profil, favoris, code de
  parrainage. « Ajoute … à mes favoris » suit un projet.
- Hors sujet : un filtre local refuse la question sans appeler Gemini, et les
  consignes envoyées à Gemini imposent la même règle.
- Sans clé ou sans connexion : réponses de secours calculées à partir des
  données de l’application.
- Questions d’argent (« comment gagner de l’argent ? », « j’ai 200 € ») :
  acceptées, et la réponse reste centrée sur CrowdTech.
- Achat dans le chat : « Achète le pack Découverte de Green Pulse Sensor » ou
  « Investis 200 € dans AI Ops » affiche une carte (choix du projet ou du pack
  s’ils manquent, récapitulatif, Confirmer / Annuler). La demande est
  reconnue par l’application, jamais par l’IA. L’achat passe par
  `CrowdRules.buyPack`, avec les mêmes règles que le bouton « Investir ».

## Fonctionnalités métier du crowdfunding

Règles regroupées dans `lib/modules/funding/domain/crowd_rules.dart` (testées dans
`test/crowd_features_test.dart`).

| # | Fonctionnalité | Où |
|---|---|---|
| 1 | Tout ou rien : remboursement automatique si l’objectif n’est pas atteint à la date limite | à l’ouverture de Crowd ; badge « Échoué – remboursé » |
| 2 | Validation des projets par l’admin (en attente / validé / refusé avec motif) | ⋮ → Projets à valider |
| 3 | Actualités publiées par le porteur | Détails du projet → Espace du projet |
| 4 | Contreparties : Supporter 100 €, Ambassadeur 500 €, Mécène 2 000 € | Détails du projet, portefeuille |
| 5 | Projets suivis ❤️ et filtre « Suivis » | cartes de projet |
| 6 | Questions-réponses avec le porteur | Espace du projet |
| 7 | Profil investisseur et plafond par projet | ⋮ → Mon profil investisseur |
| 8 | Attestation d’investissement en PDF | Mon portefeuille → historique |
| 9 | Tableau de bord porteur (collecte sur 14 jours) | ⋮ → Tableau de bord porteur |
| 10 | Jalons : fonds débloqués après vote des investisseurs | Espace du projet → Jalons et votes |
| 11 | Marché des jetons (revente entre investisseurs) | ⋮ → Marché des jetons ; Portefeuille → Revendre |
| 12 | Parrainage : +10 % de jetons offerts au parrain et au filleul | ⋮ → Parrainage ; code à l’inscription |

## Conformité au cahier des charges

Toutes les API utilisées sont **gratuites (0 €)** et sans clé, sauf Firebase
(plan Spark gratuit, clé du projet à fournir).

| Module | Exigence | Implémentation |
|---|---|---|
| Commun | Firebase Auth, rôles, mot de passe oublié | `core/firebase/firebase_rest.dart` (Auth REST : inscription, connexion, email de réinitialisation) + comptes SQLite chiffrés ; rôles dans `permissions.dart` |
| Actus | Score de fiabilité | `article_feedback.dart`, `news_feedback.dart` : moyenne bayésienne entre le score de la source et les notes ⭐ des pairs (poids de la source : 3 avis) |
| Actus | Modération et filtrage des commentaires | `comment_moderation.dart` : mots interdits masqués (avec ou sans accents), spam / majuscules refusés, signalements, masquage auto au 3ᵉ signalement, rétablissement admin, tri « Pertinents / Récents » |
| Actus | Recherche et indexation par confiance | `news_search.dart` : index inversé, recherche par début de mot, pertinence × fiabilité, filtres 🟢 Très fiables / 🟡 Fiables / 🔴 À vérifier |
| Actus | Hacker News API, Firestore REST | `crowdtech_api.dart`, `firebase_sync.dart` |
| Crowd | Entité FeatureProjet + déblocage par seuils | `funding/domain/project_feature.dart`, `feature_unlock.dart` (déblocage séquentiel, seuils croissants et atteignables), page « Fonctionnalités à débloquer » |
| Crowd | Prix du jeton et conversion | `currency_service.dart` : prix suggéré, jetons émis, budget → jetons dans 7 devises |
| Crowd | Portefeuille et ROI | `portfolio_analytics.dart`, graphiques du portefeuille et du simulateur |
| Crowd | ExchangeRate-API, QuickChart | `open.er-api.com` (cache 12 h + taux de secours), `quickchart.io` |
| Store | Recherche multi-critères | `product_search.dart` + panneau « Filtres et tri » (prix, catégories, état, marque, note, stock, réputation vendeur, 6 tris) |
| Store | Machine à états Escrow | `order_escrow.dart` : Fonds bloqués → Expédiée → Terminée, Annulée, Litige → Remboursée / libérée, libération auto après 14 jours, stock rendu |
| Store | Réputation vendeur | `seller_reputation.dart` : moyenne bayésienne des avis (70 %) + taux de commandes réussies (30 %), niveaux 🌱 → 🏆 |
| Store | Firebase Storage, QR Code API | photos produits envoyées si Storage configuré ; QR des commandes via `api.qrserver.com` |
| Événements | Jauge et file d'attente dynamique | `event_access.dart` (`EventCapacity`) : liste d'attente, promotion automatique à l'annulation |
| Événements | Badges cryptés horodatés | `AccessBadge` : badge `CTB2.<nonce>.<données chiffrées AES-256-GCM + tag>` (paquet gratuit `pointycastle`), horodaté, date de validité, usage unique au contrôle |
| Événements | Rappels et notifications | `Reminders` : J-7, J-1, jour J + notification de place obtenue ; cloche 🔔 dans Événements |
| Événements | OpenStreetMap / Nominatim | géocodage Nominatim (Open-Meteo en secours), mini-carte OSM dans le détail d'un événement |

### API supplémentaires (gratuites, sans clé)

En plus des 2 API par module du cahier, chaque module en utilise 2 autres :

| Module | API | Utilisation | Code |
|---|---|---|---|
| Actus | DEV Community (`dev.to`) | 2ᵉ source d'articles, fiabilité de départ selon réactions et commentaires (Gestion des actualités → import DEV) | `news/data/news_web_api.dart`, `news/domain/source_check.dart` |
| Actus | Wikipédia REST | carte « Vérifier sur Wikipédia » dans la discussion : notions reconnues dans le titre, mots techniques, catégorie ; résultats hors sujet et homonymies écartés | idem, `widgets/wiki_context_card.dart` |
| Crowd | Frankfurter (BCE) | évolution du prix du jeton sur 30 jours dans 7 devises + graphique QuickChart (page Prix du jeton) | `funding/data/funding_web_api.dart`, `widgets/rate_history_section.dart` |
| Crowd | Banque mondiale | inflation du pays → rendement réel (équation de Fisher) dans le simulateur ROI | idem, `portfolio_analytics.dart` |
| Store | OSRM | distance routière depuis l'entrepôt → frais (4 € + 0,02 €/km, max 25 €, offerts dès 500 €) et délai à la commande | `marketplace/data/delivery_api.dart`, `domain/delivery_quote.dart` |
| Store | Zippopotam (+ Nominatim pour la Tunisie) | vérifie que le code postal correspond à la ville | idem |
| Événements | Open-Meteo Forecast | météo prévue le jour J et conseil (pluie, chaleur, froid) dans le détail | `events/data/events_web_api.dart`, `domain/event_planning.dart` |
| Événements | Nager.Date | avertit dans le formulaire si la date est un jour férié du pays | idem, `widgets/holiday_hint.dart` |
| Commun | Have I Been Pwned | refuse à l'inscription un mot de passe déjà divulgué (seuls 5 caractères de l'empreinte SHA-1 sont envoyés) | `core/auth/password_breach.dart` |
| Commun | DiceBear | avatar illustré des comptes sans photo (empreinte de l'email, jamais l'email) | `shared/widgets/user_avatar.dart` |
| Commun | LanguageTool | bouton « Corriger l'orthographe » sous chaque commentaire, avis et description : pour chaque faute, choisir une correction ou garder son mot | `core/network/spell_checker.dart`, `shared/widgets/spell_check_button.dart` |

Les fonctionnalités en plus du cahier (jalons votés, revente de jetons,
parrainage, questionnaire investisseur, certificats PDF, assistant Gemini…)
sont conservées.

**Push FCM** : l'envoi de notifications push Firebase demande un serveur
(Cloud Functions, qui nécessite le plan payant Blaze). Pour rester à 0 €,
les rappels sont générés dans l'application (centre de notifications).

## Activer Firebase (gratuit, plan Spark)

1. Sur <https://console.firebase.google.com>, créer un projet (plan Spark).
2. Authentication → Méthode de connexion → activer **E-mail/Mot de passe**.
3. Firestore Database → créer la base (édition Standard, ID `(default)`).
   Storage est facultatif (souvent réservé au plan payant) : sans lui, les
   photos restent sur l'appareil.
4. Paramètres du projet → Général → « Ajouter une application Web » et
   récupérer `apiKey`, `projectId`, `storageBucket`.
5. Firestore Database → Règles : coller le contenu de `firestore.rules` puis
   publier. Ces règles bloquent l’accès anonyme et protègent les données
   personnelles ; sans serveur, les collections partagées restent modifiables
   par tout compte connecté.
6. Copier `config.example.json` en `config.json` (ignoré par git) et
   le remplir (`BADGE_SECRET` : phrase secrète qui signe les badges ; la changer
   invalide les badges déjà émis), puis lancer avec la configuration VS Code
   « CrowdTech (Windows) » ou :

```powershell
flutter run -d windows --dart-define-from-file=config.json
```

Sans `config.json`, tout fonctionne en local (SQLite). Le statut est
affiché dans Profil → Sécurité et administration → Firebase.

### Partage des données entre appareils (`lib/core/firebase/firebase_sync.dart`)

- SQLite reste la base de travail : l'application marche hors ligne.
- **Envoi** : chaque ajout, modification ou suppression est copié dans
  Firestore. Un envoi échoué est gardé et renvoyé plus tard.
- **Réception** : à la connexion puis toutes les 2 minutes, seuls les
  documents changés depuis la dernière fois sont lus (heure du serveur,
  champ `syncedAt`). Les écrans se rechargent tout seuls.
- **Numéros communs** (`lib/core/database/shared_ids.dart`) : un élément a le
  même numéro sur tous les téléphones, les liens restent valides (une note
  pointe vers son article). Les exemples de démonstration ont des numéros
  fixes et ne sont jamais envoyés deux fois.
- **Suppression** : le document reste avec `deleted: true` pour que les
  autres appareils l'apprennent.
- Restent sur l'appareil : mots de passe, panier, profil, journal, photos.
  La fiche publique du compte (nom, rôle, coordonnées) est dans `users/{uid}`.
- Les données créées **avant** l'activation de Firebase restent locales :
  pour repartir proprement, videz les données du navigateur ou supprimez
  `crowdtech.db`.

## Organisation du code (architecture modulaire)

```
lib/
├── main.dart                  Point d'entrée (Firebase inactif sans config.json, notifications)
├── app/                       Application, thème, navigation entre les modules
├── core/                      Services communs à tous les modules
│   ├── auth/                  Comptes, session, rôles et droits (module commun)
│   ├── database/              SQLite (mobile, ordinateur, Web) et journal des opérations
│   ├── firebase/              Firebase Auth / Firestore / Storage (REST, plan Spark)
│   ├── network/               API publiques gratuites (Hacker News, ExchangeRate, Nominatim…)
│   └── notifications/         Rappels programmés sur l'appareil
├── modules/                   Un dossier par module métier
│   ├── news/                  Étudiant 1 : Actus & fact-checking
│   ├── funding/               Étudiant 2 : Crowdfunding & jetons
│   ├── marketplace/           Étudiant 3 : Marketplace (escrow, réputation)
│   ├── events/                Étudiant 4 : Événements (jauge, badges, rappels)
│   ├── auth/  profile/        Écrans du module commun
│   │   ├── domain/            Entités et règles métier (sans interface graphique)
│   │   ├── data/              Dépôt du module (accès aux collections) et données de départ
│   │   └── presentation/      Écrans et widgets
└── shared/                    Composants d'interface, formats et validations réutilisables
```

Les écrans et les règles métier lisent et écrivent les données par
les dépôts (`NewsRepository`, `FundingRepository`, `MarketplaceRepository`,
`EventsRepository`, `ProfileRepository`, `AccountRepository`), construits sur
`core/database/collection_repository.dart`. Seuls ces dépôts parlent à
SQLite : changer de stockage (par exemple Firestore) ne touche qu'eux.

Les règles métier (`domain/`) sont testées directement
(`test/spec_features_test.dart`). Les imports sont triés
automatiquement (`directives_ordering`).

Entités du cahier des charges : `NewsItem` (ArticleTech), `ArticleComment`
(CommentaireActualite), `FundingProject` (ProjetCrowd), `ProjectFeature`
(FeatureProjet), `ProductItem` (ProduitTech), `ProductOrder`
(CommandeProduit), `EventItem` (EvenementTech), `EventTicket`
(TicketParticipation).

## Notifications et scan QR

- **Rappels programmés** (`core/notifications/system_notifications.dart`) :
  J-7 et J-1 à 10 h, jour J à 8 h, affichés même application fermée
  (Android, iOS, macOS, Windows, Linux). Sur le Web, les rappels restent
  dans la cloche 🔔 de l'application.
- **Scan du badge** : Événements → Contrôle des entrées → « Scanner le QR
  code » (caméra sur Android, iOS, macOS et Web ; saisie du code ailleurs).
- Le push FCM depuis un serveur exige le plan payant Blaze : il est
  remplacé par ces rappels programmés, gratuits.

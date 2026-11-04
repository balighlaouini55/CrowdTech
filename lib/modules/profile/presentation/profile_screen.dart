// Écran Profil : informations, statistiques et menus du compte.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/firebase/firebase_sync.dart';
import 'package:crowdtech/modules/auth/presentation/password_reset_page.dart';
import 'package:crowdtech/modules/events/presentation/my_passes_page.dart';
import 'package:crowdtech/modules/events/presentation/notifications_page.dart';
import 'package:crowdtech/modules/funding/data/funding_repository.dart';
import 'package:crowdtech/modules/marketplace/presentation/orders_page.dart';
import 'package:crowdtech/modules/marketplace/presentation/seller_profile_page.dart';
import 'package:crowdtech/modules/profile/data/profile_repository.dart';
import 'package:crowdtech/modules/profile/presentation/activity_log_page.dart';
import 'package:crowdtech/modules/profile/presentation/admin_roles_page.dart';
import 'package:crowdtech/modules/profile/presentation/profile_edit_page.dart';
import 'package:crowdtech/modules/profile/presentation/widgets/profile_widgets.dart';
import 'package:crowdtech/shared/pages/record_list_page.dart';
import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:crowdtech/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final CrowdUser user;
  const ProfileScreen({required this.user, super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name = widget.user.name;
  late String email = widget.user.email;
  String phone = '';
  String city = '';
  String company = '';
  String bio = '';
  String birthDate = '';
  String address = '';
  String postalCode = '';
  String country = '';
  String imageUrl = '';
  String imageData = '';
  int? profileId;
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      await loadStats();
      final profiles = await ProfileRepository.profiles.all();
      final saved = profiles.where(
        (profile) => profile['accountKey'] == widget.user.email,
      );
      if (saved.isNotEmpty) {
        final profile = saved.first;
        if (!mounted) return;
        setState(() {
          profileId = profile['id']! as int;
          name = profile['name']! as String;
          email = profile['email']! as String;
          phone = profile['phone']?.toString() ?? '';
          city = profile['city']?.toString() ?? '';
          company = profile['company']?.toString() ?? '';
          bio = profile['bio']?.toString() ?? '';
          birthDate = profile['birthDate']?.toString() ?? '';
          address = profile['address']?.toString() ?? '';
          postalCode = profile['postalCode']?.toString() ?? '';
          country = profile['country']?.toString() ?? '';
          imageUrl = profile['imageUrl']?.toString() ?? '';
          imageData = profile['imageData']?.toString() ?? '';
          loading = false;
        });
        return;
      }

      // Premier affichage : le profil reprend les informations saisies à
      // l'inscription (date de naissance, téléphone, adresse…).
      final details = await AccountService.detailsOf(widget.user.email);
      final newProfile = {
        'accountKey': widget.user.email,
        'name': widget.user.name,
        'email': widget.user.email,
        'role': widget.user.role,
        ...details,
      };
      final id = await ProfileRepository.profiles.add(newProfile);
      if (!mounted) return;
      setState(() {
        profileId = id;
        phone = details['phone'] ?? '';
        city = details['city'] ?? '';
        birthDate = details['birthDate'] ?? '';
        address = details['address'] ?? '';
        postalCode = details['postalCode'] ?? '';
        country = details['country'] ?? '';
        loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = 'Impossible de charger le profil : $error';
      });
    }
  }

  int projectCount = 0;
  int tokenCount = 0;
  int operationCount = 0;

  /// Statistiques calculées à partir des données SQLite de l’utilisateur.
  Future<void> loadStats() async {
    final key = widget.user.email;
    final projects = await FundingRepository.projects.all();
    final investments = await FundingRepository.investments.all();
    final operations = await ProfileRepository.activityLog.all();
    if (!mounted) return;
    setState(() {
      projectCount = projects.where((row) => row['ownerKey'] == key).length;
      tokenCount = investments
          .where((row) => row['ownerKey'] == key)
          .fold(0, (sum, row) => sum + ((row['tokens'] as num?)?.toInt() ?? 0));
      operationCount = operations.where((row) => row['ownerKey'] == key).length;
    });
  }

  Future<void> openAndRefresh(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await loadStats();
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('👋', style: TextStyle(fontSize: 36)),
        title: const Text('Se déconnecter ?'),
        content: const Text('À très vite sur CrowdTech !'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rester'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AccountService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  Future<void> editProfile() async {
    final values = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(
          name: name,
          email: email,
          phone: phone,
          city: city,
          company: company,
          bio: bio,
          address: address,
          postalCode: postalCode,
          country: country,
          birthDate: birthDate,
          imageUrl: imageUrl,
          imageData: imageData,
        ),
      ),
    );
    if (!mounted || values == null) return;
    final id = profileId;
    if (id == null) return;
    try {
      final rowsUpdated = await ProfileRepository.profiles.update(id, {
        'accountKey': widget.user.email,
        'name': values['name'],
        'email': values['email'],
        'role': widget.user.role,
        'phone': values['phone'],
        'city': values['city'],
        'company': values['company'],
        'bio': values['bio'],
        'address': values['address'],
        'postalCode': values['postalCode'],
        'country': values['country'],
        'birthDate': values['birthDate'],
        'imageUrl': values['imageUrl'],
        'imageData': values['imageData'],
      });
      if (rowsUpdated != 1) {
        throw Exception('Le profil à modifier est introuvable.');
      }
      await AccountService.updateAccount(
        widget.user.email,
        name: values['name'],
      );
    } on Exception catch (error) {
      if (!mounted) return;
      context.showMessage('Erreur SQLite : $error');
      return;
    }
    setState(() {
      name = values['name']!;
      email = values['email']!;
      phone = values['phone'] ?? '';
      city = values['city'] ?? '';
      company = values['company'] ?? '';
      bio = values['bio'] ?? '';
      address = values['address'] ?? '';
      postalCode = values['postalCode'] ?? '';
      country = values['country'] ?? '';
      birthDate = values['birthDate'] ?? '';
      imageUrl = values['imageUrl'] ?? '';
      imageData = values['imageData'] ?? '';
    });
    if (!mounted) return;
    context.showMessage('Profil mis à jour ✨');
  }

  /// Informations facultatives encore vides, pour la carte de complétion.
  List<String> get missingInfo => [
    if (phone.isEmpty) 'téléphone',
    if (address.isEmpty || city.isEmpty) 'adresse',
    if (birthDate.isEmpty) 'date de naissance',
    if (!ItemImage.hasPhoto(imageUrl, imageData)) 'photo',
  ];

  Widget completionCard() {
    final missing = missingInfo;
    if (missing.isEmpty) return const SizedBox.shrink();
    final progress = 1 - missing.length / 5;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: editProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: ModulePalette.profile.start,
                      backgroundColor: ModulePalette.profile.soft,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ModulePalette.profile.start,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complétez votre profil 🌱',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ajoutez : ${missing.join(', ')}. '
                      'Votre adresse sera reprise automatiquement à la commande.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget menuTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = AppColors.ink,
  }) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color == AppColors.ink
            ? AppColors.primarySoft
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        size: 21,
        color: color == AppColors.ink ? AppColors.primary : color,
      ),
    ),
    title: Text(label, style: TextStyle(color: color, fontSize: 15)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    onTap: onTap,
  );

  void openPage(Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: loading
          ? const LoadingSkeleton()
          : loadError != null
          ? DatabaseErrorView(message: loadError!, onRetry: loadProfile)
          : RefreshIndicator(
              onRefresh: loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    clipBehavior: Clip.antiAlias,
                    decoration: cardDecoration(
                      gradient: ModulePalette.profile.panel,
                      borderColor: ModulePalette.profile.start.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Photo de profil si elle existe, sinon les initiales.
                        ItemImage.hasPhoto(imageUrl, imageData)
                            ? Container(
                                width: 72,
                                height: 72,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderStrong,
                                    width: 3,
                                  ),
                                ),
                                child: ItemImage(
                                  imageUrl: imageUrl,
                                  imageData: imageData,
                                  icon: Icons.person_rounded,
                                  colors: [
                                    ModulePalette.profile.start,
                                    ModulePalette.profile.end,
                                  ],
                                ),
                              )
                            // Sans photo : avatar illustré DiceBear.
                            : UserAvatar(name: name, email: widget.user.email),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MON COMPTE', style: AppText.overline),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: AppText.title.copyWith(fontSize: 21),
                              ),
                              const SizedBox(height: 8),
                              StatusBadge(
                                widget.user.role,
                                icon: Icons.verified_user_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileStatCard(
                          label: 'Projets',
                          value: '$projectCount',
                          icon: Icons.rocket_launch_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProfileStatCard(
                          label: 'Jetons',
                          value: '$tokenCount',
                          icon: Icons.toll_outlined,
                          palette: ModulePalette.store,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProfileStatCard(
                          label: 'Opérations',
                          value: '$operationCount',
                          icon: Icons.receipt_long_outlined,
                          palette: ModulePalette.events,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const ProfileSectionTitle('Informations personnelles'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfileInfoRow(label: 'Email', value: email),
                          if (birthDate.isNotEmpty)
                            ProfileInfoRow(
                              label: 'Date de naissance',
                              value: formatDate(birthDate),
                            ),
                          ProfileInfoRow(
                            label: 'Téléphone',
                            value: phone.isEmpty ? 'Non renseigné' : phone,
                          ),
                          ProfileInfoRow(
                            label: 'Adresse',
                            value:
                                [
                                      address,
                                      [postalCode, city]
                                          .where((part) => part.isNotEmpty)
                                          .join(' '),
                                      country,
                                    ]
                                    .where((part) => part.isNotEmpty)
                                    .join(', ')
                                    .ifEmpty('Non renseignée'),
                          ),
                          ProfileInfoRow(
                            label: 'Entreprise / école',
                            value: company.isEmpty ? 'Non renseignée' : company,
                          ),
                          if (bio.isNotEmpty)
                            ProfileInfoRow(label: 'Bio', value: bio),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: editProfile,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Modifier mon profil'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  completionCard(),
                  const ProfileSectionTitle('Mon activité'),
                  Card(
                    child: Column(
                      children: [
                        menuTile(
                          Icons.history_rounded,
                          'Historique des opérations',
                          () => openAndRefresh(
                            ActivityLogPage(accountKey: widget.user.email),
                          ),
                        ),
                        menuTile(
                          Icons.receipt_long_outlined,
                          'Historique des achats',
                          () => openPage(
                            RecordListPage(
                              title: 'Historique des achats',
                              collection: 'orders',
                              emptyMessage: 'Aucun achat enregistré.',
                              ownedOnly: true,
                              accountKey: widget.user.email,
                            ),
                          ),
                        ),
                        menuTile(
                          Icons.confirmation_number_outlined,
                          'Mes billets',
                          () => openPage(
                            RecordListPage(
                              title: 'Mes billets',
                              collection: 'reservations',
                              emptyMessage: 'Aucun billet réservé.',
                              ownedOnly: true,
                              accountKey: widget.user.email,
                            ),
                          ),
                        ),
                        menuTile(
                          Icons.calculate_outlined,
                          'Mes simulations',
                          () => openPage(
                            RecordListPage(
                              title: 'Mes simulations',
                              collection: 'simulations',
                              emptyMessage: 'Aucune simulation enregistrée.',
                              ownedOnly: true,
                              accountKey: widget.user.email,
                            ),
                          ),
                        ),
                        menuTile(
                          Icons.local_shipping_outlined,
                          'Suivi des commandes (séquestre)',
                          () => openAndRefresh(
                            OrdersPage(accountKey: widget.user.email),
                          ),
                        ),
                        menuTile(
                          Icons.qr_code_2_rounded,
                          'Mes pass, badges et file d’attente',
                          () => openAndRefresh(
                            MyPassesPage(accountKey: widget.user.email),
                          ),
                        ),
                        menuTile(
                          Icons.notifications_none_rounded,
                          'Notifications et rappels',
                          () => openAndRefresh(
                            NotificationsPage(accountKey: widget.user.email),
                          ),
                        ),
                        menuTile(
                          Icons.storefront_outlined,
                          'Ma réputation de vendeur',
                          () => openPage(
                            SellerProfilePage(accountKey: widget.user.email),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ProfileSectionTitle('Sécurité et administration'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_outlined),
                          title: const Text('Firebase'),
                          subtitle: Text(FirebaseSync.status),
                        ),
                        menuTile(
                          Icons.lock_reset_outlined,
                          'Réinitialiser le mot de passe',
                          () =>
                              openPage(PasswordResetPage(initialEmail: email)),
                        ),
                        if (Permissions.isAdmin)
                          menuTile(
                            Icons.admin_panel_settings_outlined,
                            'Utilisateurs et rôles',
                            () => openPage(const AdminRolesPage()),
                          ),
                        menuTile(
                          Icons.logout_rounded,
                          'Se déconnecter',
                          logout,
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Administration : liste des comptes et changement de rôle (admin uniquement).

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/core/auth/account_service.dart';
import 'package:crowdtech/core/auth/crowd_user.dart';
import 'package:crowdtech/core/auth/permissions.dart';
import 'package:crowdtech/core/auth/session.dart';
import 'package:crowdtech/shared/widgets/access_denied_view.dart';
import 'package:crowdtech/shared/widgets/database_error_view.dart';
import 'package:crowdtech/shared/widgets/loading_skeleton.dart';
import 'package:crowdtech/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class AdminRolesPage extends StatefulWidget {
  const AdminRolesPage({super.key});

  @override
  State<AdminRolesPage> createState() => _AdminRolesPageState();
}

class _AdminRolesPageState extends State<AdminRolesPage> {
  bool loading = true;
  String? error;
  List<CrowdUser> accounts = [];

  @override
  void initState() {
    super.initState();
    if (Permissions.isAdmin) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AccountService.listAccounts();
      if (!mounted) return;
      setState(() {
        accounts = result;
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les comptes : $exception';
        loading = false;
      });
    }
  }

  Future<void> changeRole(CrowdUser user, String role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AccountService.changeRole(user.email, role);
      messenger.showSnackBar(
        SnackBar(content: Text('${user.name} est maintenant « $role ».')),
      );
      if (mounted) await load();
    } on Exception catch (exception) {
      messenger.showSnackBar(SnackBar(content: Text('$exception')));
    }
  }

  BadgeTone toneOf(String role) => switch (role) {
    UserRoles.admin => BadgeTone.danger,
    UserRoles.projectOwner => BadgeTone.primary,
    UserRoles.investor => BadgeTone.success,
    _ => BadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Utilisateurs et rôles')),
        body: const AccessDeniedView(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs et rôles')),
      body: loading
          ? const LoadingSkeleton()
          : error != null
          ? DatabaseErrorView(message: error!, onRetry: load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${accounts.length} compte(s) enregistré(s)',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final user in accounts)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email),
                            const SizedBox(height: 6),
                            StatusBadge(user.role, tone: toneOf(user.role)),
                          ],
                        ),
                      ),
                      trailing:
                          user.email == CrowdTechSession.accountKey ||
                              user.email == AccountService.defaultAdminEmail
                          ? const Tooltip(
                              message: 'Compte administrateur protégé',
                              child: Icon(Icons.lock_rounded),
                            )
                          : PopupMenuButton<String>(
                              tooltip: 'Changer le rôle',
                              icon: const Icon(Icons.manage_accounts_rounded),
                              onSelected: (role) => changeRole(user, role),
                              itemBuilder: (_) => [
                                for (final role in UserRoles.all)
                                  CheckedPopupMenuItem(
                                    value: role,
                                    checked: role == user.role,
                                    child: Text(role),
                                  ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}

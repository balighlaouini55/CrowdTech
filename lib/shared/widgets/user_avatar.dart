// Avatar illustré d'un compte sans photo : DiceBear (gratuit, sans clé).
// L'email n'est jamais envoyé : DiceBear reçoit seulement une empreinte
// SHA-256, qui donne toujours le même dessin pour le même compte.
// Hors ligne, les initiales s'affichent.

import 'dart:convert';

import 'package:crowdtech/app/app_theme.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String email;
  final double radius;
  const UserAvatar({
    required this.name,
    required this.email,
    this.radius = 34,
    super.key,
  });

  /// Image DiceBear (style « thumbs ») pour [email].
  static String urlFor(String email, {int size = 128}) {
    final seed = sha256
        .convert(utf8.encode(email.trim().toLowerCase()))
        .toString()
        .substring(0, 16);
    return Uri.https('api.dicebear.com', '/9.x/thumbs/png', {
      'seed': seed,
      'size': '$size',
      'radius': '50',
    }).toString();
  }

  /// « Sarah Ben Ali » → « SB ».
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final initials = Text(
      initialsOf(name),
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surface,
      child: ClipOval(
        child: Image.network(
          urlFor(email),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initials,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : initials,
        ),
      ),
    );
  }
}

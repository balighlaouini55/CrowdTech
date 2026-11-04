// Champ de formulaire « Photo » : aperçu, bouton « Choisir une photo »
// (galerie ou appareil photo), bouton « Retirer » et lien d'image facultatif.

import 'dart:convert';

import 'package:crowdtech/shared/utils/feedback.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/item_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPickerField extends StatelessWidget {
  /// Photo choisie sur l'appareil, en base64 (null = aucune).
  final String? imageData;
  final ValueChanged<String?> onImageDataChanged;

  /// Lien d'image facultatif (utilisé s'il n'y a pas de photo de l'appareil).
  final TextEditingController urlController;

  final IconData fallbackIcon;
  final List<Color> fallbackColors;
  final double height;

  /// Affichage rond (photo de profil).
  final bool circle;

  const PhotoPickerField({
    required this.imageData,
    required this.onImageDataChanged,
    required this.urlController,
    required this.fallbackIcon,
    required this.fallbackColors,
    this.height = 180,
    this.circle = false,
    super.key,
  });

  /// Ouvre la galerie et renvoie la photo réduite (800 px) en base64.
  Future<void> pick(BuildContext context) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 75,
      );
      if (file == null) return;
      onImageDataChanged(base64Encode(await file.readAsBytes()));
    } on Exception catch (error) {
      if (!context.mounted) return;
      context.showMessage('Impossible de charger la photo : $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ListenableBuilder(
      listenable: urlController,
      builder: (context, _) => ItemImage(
        imageUrl: urlController.text.trim(),
        imageData: imageData,
        icon: fallbackIcon,
        colors: fallbackColors,
        iconSize: circle ? 48 : 64,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (circle)
          Center(
            child: ClipOval(
              child: SizedBox(width: 130, height: 130, child: preview),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(height: height, child: preview),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(context),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Choisir une photo'),
              ),
            ),
            if (imageData != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Retirer la photo',
                onPressed: () => onImageDataChanged(null),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '…ou lien d’une image (facultatif)',
            hintText: 'https://…',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          validator: optionalUrl,
        ),
      ],
    );
  }
}

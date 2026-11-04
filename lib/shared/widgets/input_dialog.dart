// Petit dialogue de saisie (un ou plusieurs champs texte).

import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

/// Un champ du dialogue : libellé, valeur de départ, exemple, saisie
/// numérique ou longue.
class DialogField {
  final String label;
  final String initialValue;
  final String? hint;
  final bool number;
  final bool multiline;
  const DialogField(
    this.label, {
    this.initialValue = '',
    this.hint,
    this.number = false,
    this.multiline = false,
  });
}

/// Affiche le dialogue et retourne les valeurs saisies, ou null si annulé.
Future<List<String>?> showInputDialog(
  BuildContext context, {
  required String title,
  required List<DialogField> fields,
  String confirmLabel = 'Enregistrer',
}) => showDialog<List<String>>(
  context: context,
  builder: (_) =>
      _InputDialog(title: title, fields: fields, confirmLabel: confirmLabel),
);

/// Le dialogue possède ses contrôleurs : ils sont libérés quand il
/// disparaît vraiment (après l'animation de fermeture), pas avant.
class _InputDialog extends StatefulWidget {
  final String title;
  final List<DialogField> fields;
  final String confirmLabel;
  const _InputDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initialValue),
  ];

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, field) in widget.fields.indexed) ...[
              if (index > 0) const SizedBox(height: 12),
              TextField(
                controller: controllers[index],
                autofocus: index == 0,
                keyboardType: field.number
                    ? TextInputType.number
                    : field.multiline
                    ? TextInputType.multiline
                    : TextInputType.text,
                minLines: field.multiline ? 3 : 1,
                maxLines: field.multiline ? 6 : 1,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                ),
              ),
              if (field.multiline)
                SpellCheckButton(controller: controllers[index]),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [
            for (final controller in controllers) controller.text,
          ]),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

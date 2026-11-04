// Composants de formulaire : section, bouton Enregistrer, champ date, suggestions.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/widgets/gradient_button.dart';
import 'package:flutter/material.dart';

/// Pays proposés dans les formulaires (inscription, profil, livraison).
const countryOptions = [
  'Tunisie',
  'France',
  'Algérie',
  'Maroc',
  'Belgique',
  'Canada',
  'Suisse',
  'Autre',
];

/// Petit encadré coloré avec un emoji, pour guider l'utilisateur.
class TipBanner extends StatelessWidget {
  final String emoji;
  final String text;
  final ModulePalette palette;
  const TipBanner({
    required this.text,
    this.emoji = '💡',
    this.palette = ModulePalette.funding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.start.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste déroulante des pays ; la valeur peut rester vide si [optional].
class CountryField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;
  const CountryField({
    required this.value,
    required this.onChanged,
    this.optional = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final current = value == null || value!.isEmpty ? null : value;
    return DropdownButtonFormField<String>(
      // La clé recrée le champ quand la valeur est changée par le code.
      key: ValueKey(current),
      initialValue: current,
      decoration: const InputDecoration(
        labelText: 'Pays',
        prefixIcon: Icon(Icons.public_rounded),
      ),
      hint: Text(optional ? 'Non précisé' : 'Choisir un pays'),
      items: [
        for (final country in {...countryOptions, ?current})
          DropdownMenuItem(value: country, child: Text(country)),
      ],
      onChanged: onChanged,
      validator: optional
          ? null
          : (value) => value == null ? 'Pays requis.' : null,
    );
  }
}

/// Groupe de champs avec un titre, présenté dans une carte.
class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  /// Petite étiquette à droite du titre (ex. « Facultatif »).
  final String? badge;
  const FormSection({
    required this.title,
    required this.icon,
    required this.children,
    this.badge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow,
      ),
      // Material transparent : les cases à cocher et listes gardent leur
      // effet au toucher sur le fond blanc de la section.
      child: Material(type: MaterialType.transparency, child: _content()),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: ModulePalette.funding.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (badge case final badge?)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(height: 14),
          child,
        ],
      ],
    );
  }
}

/// Bouton d’enregistrement toujours visible en bas des formulaires.
class FormSaveBar extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  const FormSaveBar({
    required this.onPressed,
    this.label = 'Enregistrer',
    this.icon = Icons.save_outlined,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: softShadow,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: GradientButton(onPressed: onPressed, icon: icon, label: label),
        ),
      ),
    );
  }
}

/// Champ date : saisie libre ou sélection dans un calendrier.
/// La valeur choisie dans le calendrier est écrite au format `jj/mm/aaaa`.
class DateFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final DateTime? firstDate;
  const DateFormField({
    required this.controller,
    required this.label,
    this.validator,
    this.firstDate,
    super.key,
  });

  Future<void> pick(BuildContext context) async {
    final now = DateTime.now();
    final current = parseFlexibleDate(controller.text);
    final first = firstDate ?? DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : (now.isBefore(first) ? first : now),
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      controller.text =
          '${twoDigits(picked.day)}/${twoDigits(picked.month)}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'jj/mm/aaaa',
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: IconButton(
          tooltip: 'Choisir dans le calendrier',
          onPressed: () => pick(context),
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ),
      validator: validator,
    );
  }
}

/// Propositions cliquables qui remplissent un champ texte.
class SuggestionChips extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;
  const SuggestionChips({
    required this.controller,
    required this.options,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: controller.text.trim() == option,
              onSelected: (_) => controller.text = option,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

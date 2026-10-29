import 'package:flutter/material.dart';

class EventFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const EventFormPage({this.initialValues, super.key});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final formKey = GlobalKey<FormState>();
  late final titleController = TextEditingController(
    text: widget.initialValues?['title']?.toString() ?? '',
  );
  late final dateController = TextEditingController(
    text: widget.initialValues?['date']?.toString() ?? '',
  );
  late final cityController = TextEditingController(
    text: widget.initialValues?['city']?.toString() ?? '',
  );
  late final seatsController = TextEditingController(
    text: widget.initialValues?['seats']?.toString() ?? '',
  );

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    cityController.dispose();
    seatsController.dispose();
    super.dispose();
  }

  String? requiredText(String? value, {int minimum = 1}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    if (text.length < minimum) {
      return 'Saisissez au moins $minimum caractères.';
    }
    return null;
  }

  String? validateSeats(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    final seats = int.tryParse(text);
    if (seats == null) return 'Saisissez un nombre valide.';
    if (seats < 1) return 'Saisissez un nombre supérieur ou égal à 1.';
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'date': dateController.text.trim(),
      'city': cityController.text.trim(),
      'seats': int.parse(seatsController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l’événement' : 'Créer un événement'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Nom de l’événement',
              ),
              validator: (value) => requiredText(value, minimum: 3),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Date'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'Ville'),
              validator: requiredText,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: seatsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de places'),
              validator: validateSeats,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

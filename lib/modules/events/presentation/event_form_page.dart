// Formulaire d'ajout / modification d'un événement.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/modules/events/presentation/widgets/holiday_hint.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/photo_picker_field.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class EventFormPage extends StatefulWidget {
  final Map<String, Object?>? initialValues;

  const EventFormPage({this.initialValues, super.key});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  static const categories = [
    'Conférence',
    'Atelier',
    'Meetup',
    'Hackathon',
    'Salon',
  ];

  final formKey = GlobalKey<FormState>();
  late final titleController = controllerFor('title');
  late final dateController = controllerFor('date');
  late final cityController = controllerFor('city');
  late final seatsController = controllerFor('seats');
  late final timeController = controllerFor('time');
  late final venueController = controllerFor('venue');
  late final priceController = TextEditingController(
    text: widget.initialValues?['price']?.toString() ?? '0',
  );
  late final descriptionController = controllerFor('description');
  late String category = categories.contains(widget.initialValues?['category'])
      ? widget.initialValues!['category']! as String
      : 'Conférence';

  late final imageUrlController = controllerFor('imageUrl');

  /// Photo choisie sur l'appareil, en base64 (null = aucune).
  late String? imageData = widget.initialValues?['imageData'] as String?;

  TextEditingController controllerFor(String key) =>
      TextEditingController(text: widget.initialValues?[key]?.toString() ?? '');

  @override
  void dispose() {
    for (final controller in [
      imageUrlController,
      titleController,
      dateController,
      cityController,
      seatsController,
      timeController,
      venueController,
      priceController,
      descriptionController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validateDate(String? value) {
    final error = requiredText(value);
    if (error != null) return error;
    final date = parseFlexibleDate(value);
    if (date == null || widget.initialValues != null) return null;
    final now = DateTime.now();
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'La date de l’événement est déjà passée.';
    }
    return null;
  }

  String? validateSeats(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ce champ est requis.';
    final seats = int.tryParse(text);
    if (seats == null) return 'Saisissez un nombre valide.';
    if (seats < 1) return 'Saisissez un nombre supérieur ou égal à 1.';
    if (seats > 100000) return 'Maximum 100000 places.';
    return null;
  }

  String? validateTime(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final match = RegExp(r'^([01]?\d|2[0-3])[:h]([0-5]\d)$').hasMatch(text);
    return match ? null : 'Heure invalide (ex. 09:30).';
  }

  String? validatePrice(String? value) {
    final price = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (price == null || price < 0 || !price.isFinite) {
      return 'Saisissez un prix de 0 (gratuit) ou plus.';
    }
    return null;
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      timeController.text =
          '${twoDigits(picked.hour)}:${twoDigits(picked.minute)}';
    }
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    Navigator.pop(context, <String, Object?>{
      'title': titleController.text.trim(),
      'date': dateController.text.trim(),
      'city': cityController.text.trim(),
      'seats': int.parse(seatsController.text.trim()),
      'time': optional(timeController)?.replaceAll('h', ':'),
      'venue': optional(venueController),
      'price': double.parse(priceController.text.trim().replaceAll(',', '.')),
      'category': category,
      'description': optional(descriptionController),
      'imageUrl': optional(imageUrlController),
      'imageData': imageData,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialValues != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l’événement' : 'Créer un événement'),
      ),
      bottomNavigationBar: FormSaveBar(onPressed: save),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FormSection(
                title: 'Événement',
                icon: Icons.event_note_outlined,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’événement',
                      prefixIcon: Icon(Icons.campaign_outlined),
                    ),
                    validator: (value) => requiredText(value, minimum: 3),
                  ),
                  DateFormField(
                    controller: dateController,
                    label: 'Date',
                    validator: validateDate,
                  ),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: requiredText,
                  ),
                  HolidayHint(
                    dateController: dateController,
                    cityController: cityController,
                  ),
                  TextFormField(
                    controller: seatsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de places',
                      prefixIcon: Icon(Icons.event_seat_outlined),
                    ),
                    validator: validateSeats,
                  ),
                ],
              ),
              FormSection(
                title: 'Organisation',
                icon: Icons.tune_rounded,
                children: [
                  TextFormField(
                    controller: timeController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Heure (facultatif)',
                      hintText: '09:30',
                      prefixIcon: const Icon(Icons.schedule_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Choisir l’heure',
                        onPressed: pickTime,
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                    validator: validateTime,
                  ),
                  TextFormField(
                    controller: venueController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu / adresse (facultatif)',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix du billet (€)',
                      helperText: '0 = événement gratuit',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    validator: validatePrice,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Type d’événement',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final value in categories)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setState(() => category = value ?? 'Conférence'),
                  ),
                  TextFormField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 600,
                    decoration: const InputDecoration(
                      labelText: 'Programme / description (facultatif)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SpellCheckButton(controller: descriptionController),
                ],
              ),
              FormSection(
                title: 'Photo de l’événement',
                icon: Icons.image_outlined,
                children: [
                  PhotoPickerField(
                    imageData: imageData,
                    onImageDataChanged: (value) =>
                        setState(() => imageData = value),
                    urlController: imageUrlController,
                    fallbackIcon: Icons.image_outlined,
                    fallbackColors: [
                      ModulePalette.events.start,
                      ModulePalette.events.end,
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

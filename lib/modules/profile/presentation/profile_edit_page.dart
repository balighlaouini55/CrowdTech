// Formulaire de modification du profil.

import 'package:crowdtech/app/app_theme.dart';
import 'package:crowdtech/shared/utils/formatters.dart';
import 'package:crowdtech/shared/utils/validators.dart';
import 'package:crowdtech/shared/widgets/form_widgets.dart';
import 'package:crowdtech/shared/widgets/photo_picker_field.dart';
import 'package:crowdtech/shared/widgets/spell_check_button.dart';
import 'package:flutter/material.dart';

class ProfileEditPage extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String city;
  final String company;
  final String bio;
  final String address;
  final String postalCode;
  final String country;
  final String birthDate;
  final String imageUrl;
  final String imageData;

  const ProfileEditPage({
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.company = '',
    this.bio = '',
    this.address = '',
    this.postalCode = '',
    this.country = '',
    this.birthDate = '',
    this.imageUrl = '',
    this.imageData = '',
    super.key,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(text: widget.name);
  late final emailController = TextEditingController(text: widget.email);
  late final phoneController = TextEditingController(text: widget.phone);
  late final cityController = TextEditingController(text: widget.city);
  late final companyController = TextEditingController(text: widget.company);
  late final bioController = TextEditingController(text: widget.bio);
  late final addressController = TextEditingController(text: widget.address);
  late final postalCodeController = TextEditingController(
    text: widget.postalCode,
  );
  late final birthDateController = TextEditingController(
    text: widget.birthDate.isEmpty ? '' : formatDate(widget.birthDate),
  );
  late String? country = widget.country.isEmpty ? null : widget.country;
  late final imageUrlController = TextEditingController(text: widget.imageUrl);

  /// Photo de profil choisie sur l'appareil, en base64.
  late String? imageData = widget.imageData.isEmpty ? null : widget.imageData;

  @override
  void dispose() {
    for (final controller in [
      nameController,
      emailController,
      phoneController,
      cityController,
      companyController,
      bioController,
      addressController,
      postalCodeController,
      birthDateController,
      imageUrlController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, String>{
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'city': cityController.text.trim(),
      'company': companyController.text.trim(),
      'bio': bioController.text.trim(),
      'address': addressController.text.trim(),
      'postalCode': postalCodeController.text.trim(),
      'country': country ?? '',
      'birthDate': switch (parseFlexibleDate(birthDateController.text)) {
        final date? => isoDate(date),
        null => '',
      },
      'imageUrl': imageUrlController.text.trim(),
      'imageData': imageData ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      bottomNavigationBar: FormSaveBar(onPressed: save),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              FormSection(
                title: 'Identité',
                icon: Icons.badge_outlined,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'Saisissez au moins 2 caractères.'
                        : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email de contact',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: validateEmail,
                  ),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: validatePhone,
                  ),
                  DateFormField(
                    controller: birthDateController,
                    label: 'Date de naissance',
                    firstDate: DateTime(1900),
                    validator: validateBirthDate,
                  ),
                ],
              ),
              FormSection(
                title: 'Adresse de livraison',
                icon: Icons.local_shipping_outlined,
                badge: 'Obligatoire',
                children: [
                  const Text(
                    'Proposée automatiquement lors de vos commandes.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  TextFormField(
                    controller: addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'N° et rue',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    validator: (value) => requiredText(value, minimum: 5),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Ville',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: requiredText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: postalCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Code postal',
                          ),
                          validator: (value) => validatePostalCode(value),
                        ),
                      ),
                    ],
                  ),
                  CountryField(
                    optional: false,
                    value: country,
                    onChanged: (value) => setState(() => country = value),
                  ),
                ],
              ),
              FormSection(
                title: 'Présentation',
                icon: Icons.contact_page_outlined,
                badge: 'Facultatif',
                children: [
                  TextFormField(
                    controller: companyController,
                    decoration: const InputDecoration(
                      labelText: 'Entreprise / école (facultatif)',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: bioController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Bio (facultatif)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SpellCheckButton(controller: bioController),
                ],
              ),
              FormSection(
                title: 'Photo de profil',
                icon: Icons.account_circle_outlined,
                children: [
                  PhotoPickerField(
                    circle: true,
                    imageData: imageData,
                    onImageDataChanged: (value) =>
                        setState(() => imageData = value),
                    urlController: imageUrlController,
                    fallbackIcon: Icons.person_rounded,
                    fallbackColors: [
                      ModulePalette.profile.start,
                      ModulePalette.profile.end,
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

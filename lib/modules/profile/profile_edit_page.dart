import 'package:flutter/material.dart';

import '../../validation/validators.dart';

class ProfileEditPage extends StatefulWidget {
  final String name;
  final String email;

  const ProfileEditPage({required this.name, required this.email, super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(text: widget.name);
  late final emailController = TextEditingController(text: widget.email);

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, String>{
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Saisissez au moins 2 caractères.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: validateEmail,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}

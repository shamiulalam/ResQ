import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../database/models/user_model.dart';
import '../../../database/services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();
  late final Map<String, TextEditingController> _fields;
  late bool _emailPublic;
  late bool _phonePublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _fields = {
      'firstName': TextEditingController(text: u.firstName),
      'lastName': TextEditingController(text: u.lastName),
      'phone': TextEditingController(text: u.phone),
      'subtitle': TextEditingController(text: u.subtitle),
      'bio': TextEditingController(text: u.bio),
      'location': TextEditingController(text: u.location),
      'city': TextEditingController(text: u.city),
      'profileImage': TextEditingController(text: u.profileImage),
    };
    _emailPublic = u.isEmailPublic;
    _phonePublic = u.isPhonePublic;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != widget.user.uid) return;
    setState(() => _saving = true);
    try {
      await _service.updateUserProfile(uid, {
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'isEmailPublic': _emailPublic,
        'isPhonePublic': _phonePublic,
      });
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save profile. Please try again.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile'), actions: [
          TextButton(
              onPressed: _saving ? null : _save, child: const Text('Save'))
        ]),
        body: Form(
            key: _formKey,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Row(children: [
                    Expanded(
                        child:
                            _field('firstName', 'First name', required: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field('lastName', 'Last name', required: true))
                  ]),
                  _field('subtitle', 'Profile subtitle'),
                  _field('bio', 'Bio', lines: 3),
                  _field('location', 'Location'),
                  _field('city', 'City'),
                  _field('phone', 'Phone', keyboard: TextInputType.phone),
                  _field('profileImage', 'Profile image URL',
                      keyboard: TextInputType.url),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show email on public profile'),
                      value: _emailPublic,
                      onChanged: (v) => setState(() => _emailPublic = v)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show phone on public profile'),
                      value: _phonePublic,
                      onChanged: (v) => setState(() => _phonePublic = v)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save changes')),
                ])),
      );

  Widget _field(String key, String label,
          {int lines = 1, bool required = false, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
            controller: _fields[key],
            maxLines: lines,
            keyboardType: keyboard,
            validator: required
                ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                : null,
            decoration: InputDecoration(labelText: label)),
      );
}

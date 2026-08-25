import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple form for super_admins to create/promote a user to admin (adminLevel: moderator).
/// This works by finding the user's profile document in `users` by email and
/// setting role = 'admin' and adminLevel = 'moderator'. The target user must
/// already have a profile document in the `users` collection (i.e., they must
/// have completed registration at least once). This avoids requiring server-side
/// Admin SDK access from the client.
class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final email = _emailController.text.trim();
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No user profile found for that email. The user must register first.')));
        }
        return;
      }
      final doc = query.docs.first;
      final uid = doc.id;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': 'admin',
        'adminLevel': 'moderator',
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User promoted to admin (moderator).')));
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create admin: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'User email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!v.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                      _submitting ? 'Creating...' : 'Create Admin (moderator)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

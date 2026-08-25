import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin user management placeholder. Lists users from `users` collection
/// and allows promoting/demoting role values. This is minimal and should be
/// extended with pagination, search, and server-side security rules.
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _usersRef = FirebaseFirestore.instance.collection('users');
  String _currentAdminLevel = 'user';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentAdminLevel();
  }

  Future<void> _loadCurrentAdminLevel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _currentAdminLevel = 'user';
        _loading = false;
      });
      return;
    }
    final doc = await _usersRef.doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _currentAdminLevel = (data['adminLevel'] as String?) ??
          (data['role'] == 'admin' ? 'moderator' : 'user');
      _loading = false;
    });
  }

  Future<void> _toggleAdmin(String uid, String currentRole) async {
    // Only super_admin may create or delete admins
    if (_currentAdminLevel != 'super_admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Only super admins can promote/demote admins')));
      }
      return;
    }

    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newRole == 'admin' ? 'Promote' : 'Demote'} user'),
        content: Text(
            'Are you sure you want to set role = "$newRole" for this user?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (confirm != true) return;

    // When promoting to admin, set adminLevel to 'moderator' by default
    final update = {'role': newRole};
    if (newRole == 'admin') update['adminLevel'] = 'moderator';

    await _usersRef.doc(uid).set(update, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Role set to $newRole')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _usersRef
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    final uid = docs[index].id;
                    final email = d['email'] as String? ?? '(no email)';
                    final role = d['role'] as String? ?? 'user';
                    final adminLevel = d['adminLevel'] as String? ??
                        (role == 'admin' ? 'moderator' : 'user');

                    Widget trailing;
                    // Only super_admin may promote/demote admins. Moderators see a disabled label.
                    if (_currentAdminLevel == 'super_admin') {
                      trailing = TextButton(
                        onPressed: () => _toggleAdmin(uid, role),
                        child: Text(role == 'admin' ? 'Demote' : 'Promote'),
                      );
                    } else {
                      trailing = Text(adminLevel == 'super_admin'
                          ? 'Super'
                          : (role == 'admin' ? 'Admin' : 'User'));
                    }

                    return ListTile(
                      title: Text(email),
                      subtitle: Text('uid: $uid • level: $adminLevel'),
                      trailing: trailing,
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

/// Mobile-friendly Admin Dashboard using a Grid layout.
/// Route: '/admin/dashboard'
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _adminLevel = 'user';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _adminLevel = 'user';
        _loading = false;
      });
      return;
    }
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _adminLevel = (data['adminLevel'] as String?) ??
          (data['role'] == 'admin' ? 'moderator' : 'user');
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: ext.navBarBackground,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _DashboardTile(
                    label: 'Manage Users',
                    icon: Icons.people,
                    color: ext.accentOrange,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/admin/users'),
                  ),

                  // Super admin can create new admins; moderators do not see this tile.
                  if (_adminLevel == 'super_admin')
                    _DashboardTile(
                      label: 'Create Admin',
                      icon: Icons.admin_panel_settings,
                      color: ext.accentOrange.withValues(alpha: 0.9),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/admin/create'),
                    ),

                  _DashboardTile(
                    label: 'Add Pet Photos',
                    icon: Icons.photo_library,
                    color: ext.accentOrange.withValues(alpha: 0.9),
                    onTap: () {
                      // TODO: navigate to add-pet-photos flow
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Add Photos — not implemented yet')));
                    },
                  ),
                  _DashboardTile(
                    label: 'System Settings',
                    icon: Icons.settings,
                    color: ext.cardBackground,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('System Settings — not implemented yet')));
                    },
                  ),
                  _DashboardTile(
                    label: 'Sign out',
                    icon: Icons.logout,
                    color: Colors.redAccent,
                    onTap: () async {
                      final should = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign out?'),
                          content:
                              const Text('Do you really want to sign out?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Sign out')),
                          ],
                        ),
                      );
                      if (should == true) {
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/login', (r) => false);
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

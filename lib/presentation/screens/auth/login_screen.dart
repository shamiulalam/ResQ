import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../database/services/auth_service.dart';
import '../../widgets/app_background.dart';

/// User Login screen — theme-adaptive (works in both Light and Special mode).
///
/// Route: '/login' (see lib/core/routes/app_routes.dart)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final _authService = AuthService();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _authService.loginWithEmail(
        email: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      // Firebase authentication is complete. Do not keep the login spinner up
      // while either Supabase or Firestore is contacted.
      final navigator = Navigator.of(context);
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);

      // Admin routing is profile metadata, not part of authentication. Resolve
      // it in the background and correct the destination if necessary.
      unawaited(_redirectAdminWhenKnown(navigator));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed (${e.code})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _redirectAdminWhenKnown(NavigatorState navigator) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      if (doc.data()?['role'] == 'admin' && navigator.mounted) {
        navigator.pushNamedAndRemoveUntil(
          '/admin/dashboard',
          (route) => false,
        );
      }
    } catch (error) {
      // A profile lookup failure must not turn a successful Firebase login
      // into a failed login. Firestore security still protects admin data.
      debugPrint('Could not resolve post-login role: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 8),

                  // Back button
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: ext.textPrimary),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),

                  const SizedBox(height: 20),

                  // Avatar icon — glowing circle
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ext.cardBackground,
                        border: Border.all(
                          color: ext.accentOrange.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ext.accentOrange.withValues(alpha: 0.18),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person,
                        size: 44,
                        color: ext.accentOrange,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Res',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: ext.logoTextColor,
                          ),
                        ),
                        TextSpan(
                          text: 'Q',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: ext.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ext.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Social sign-in (Google)
                  _AdaptiveOutlinedButton(
                    ext: ext,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _authService.signInWithGoogle();
                      } on FirebaseAuthException catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(
                                  e.message ?? 'Google sign-in unavailable')),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata,
                            size: 26, color: ext.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: ext.dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: ext.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: ext.dividerColor)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Email field
                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Email',
                    hint: 'Enter your email address',
                    controller: _usernameController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        Validators.required(v, fieldName: 'Email'),
                  ),

                  const SizedBox(height: 16),

                  // Password field
                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: Validators.password,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: ext.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: forgot-password flow
                      },
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: ext.accentOrange,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Login CTA — orange gradient
                  _GradientButton(
                    ext: ext,
                    label: _isSubmitting ? 'Logging in...' : 'Login',
                    onPressed: _isSubmitting ? () {} : _handleLogin,
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed('/register'),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: ext.accentOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared adaptive sub-widgets (private to this file)
// ---------------------------------------------------------------------------

class _AdaptiveTextField extends StatelessWidget {
  final ResQThemeExtension ext;
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AdaptiveTextField({
    required this.ext,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ext.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 15, color: ext.inputTextColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: ext.hintText),
            filled: true,
            fillColor: ext.fieldFill,
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ext.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ext.accentOrange, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdaptiveOutlinedButton extends StatelessWidget {
  final ResQThemeExtension ext;
  final VoidCallback onPressed;
  final Widget child;

  const _AdaptiveOutlinedButton({
    required this.ext,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: ext.outlinedButtonBackground,
          side: BorderSide(color: ext.outlinedButtonBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final ResQThemeExtension ext;
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.ext,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF8A3D), Color(0xFFFFC06A)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ext.accentOrange.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

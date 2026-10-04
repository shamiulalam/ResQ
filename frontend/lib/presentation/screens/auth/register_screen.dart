import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../database/models/user_model.dart';
import '../../../database/services/auth_service.dart';
import '../../../database/services/firestore_service.dart';
import '../../widgets/app_background.dart';

/// Registration form — theme-adaptive (works in both Light and Special mode).
///
/// Route: '/register' (see lib/core/routes/app_routes.dart)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender; // 'Male' | 'Female'
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  String? _intent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _intent = args?['intent'] as String?;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Create the account in Firebase Auth.
      final credential = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // 2. Save the rest of the profile in Firestore.
      final userModel = UserModel(
        uid: uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender!,
        createdAt: DateTime.now(),
      );
      await _firestoreService.saveUserProfile(userModel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please log in.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed (${e.code})')),
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

                  const SizedBox(height: 0),

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

                  const SizedBox(height: 16),

                  Text(
                    'Create a new account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ext.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),

                  if (_intent != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _intent == 'lost'
                          ? "You're registering to report a lost pet."
                          : "You're registering to report a stray sighting.",
                      style: TextStyle(
                        color: ext.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // First name / Last name (side by side)
                  Row(
                    children: [
                      Expanded(
                        child: _AdaptiveTextField(
                          ext: ext,
                          label: 'First name',
                          hint: 'John',
                          controller: _firstNameController,
                          validator: (v) =>
                              Validators.required(v, fieldName: 'First name'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _AdaptiveTextField(
                          ext: ext,
                          label: 'Last name',
                          hint: 'Doe',
                          controller: _lastNameController,
                          validator: (v) =>
                              Validators.required(v, fieldName: 'Last name'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),

                  const SizedBox(height: 16),

                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Phone number',
                    hint: '+1 234 567 8900',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),

                  const SizedBox(height: 16),

                  // Gender — adaptive tick-select buttons
                  FormField<String>(
                    initialValue: _selectedGender,
                    validator: (v) =>
                        v == null ? 'Please select a gender' : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gender',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ext.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _AdaptiveTickButton(
                                ext: ext,
                                label: 'Male',
                                selected: _selectedGender == 'Male',
                                onTap: () {
                                  setState(() => _selectedGender = 'Male');
                                  state.didChange('Male');
                                },
                              ),
                              const SizedBox(width: 12),
                              _AdaptiveTickButton(
                                ext: ext,
                                label: 'Female',
                                selected: _selectedGender == 'Female',
                                onTap: () {
                                  setState(() => _selectedGender = 'Female');
                                  state.didChange('Female');
                                },
                              ),
                            ],
                          ),
                          if (state.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              state.errorText!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Password',
                    hint: 'At least 6 characters',
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

                  const SizedBox(height: 16),

                  _AdaptiveTextField(
                    ext: ext,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: ext.textSecondary,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Register CTA — orange gradient
                  _GradientButton(
                    ext: ext,
                    label: _isSubmitting ? 'Creating account...' : 'Register',
                    onPressed: _isSubmitting ? () {} : _handleRegister,
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed('/login'),
                        child: Text(
                          'Login',
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

class _AdaptiveTickButton extends StatelessWidget {
  final ResQThemeExtension ext;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdaptiveTickButton({
    required this.ext,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? ext.accentOrange.withValues(alpha: 0.12)
                : ext.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? ext.accentOrange : ext.fieldBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? ext.accentOrange : ext.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? ext.accentOrange : ext.textPrimary,
                ),
              ),
            ],
          ),
        ),
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

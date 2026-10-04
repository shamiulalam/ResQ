import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../widgets/app_background.dart';

/// The very first screen of ResQ — theme-adaptive.
/// Light mode: sky-blue top half, warm-peach bottom half.
/// Special mode: Dark flare aesthetic.
///
/// Route: '/' (see lib/core/routes/app_routes.dart)
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // Use adaptive status bar instead of hardcoded dark icons.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final themeNotifier = context.watch<ThemeNotifier>();
    final isSpecial = themeNotifier.isSpecial;

    return AppBackground(
      showWatermark: isSpecial,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              // ── Background: top/bottom splits (only fully visible in light mode)
              if (!isSpecial)
                Column(
                  children: [
                    // Top blue half
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFB8D8F0), // light sky blue
                              Color(0xFFD6EBFA), // very light blue
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom peach half
                    Expanded(
                      child: Container(
                        color: const Color(0xFFFAEDD8), // warm peach / cream
                      ),
                    ),
                  ],
                ),

              // ── Foreground content ────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // ── TOP HALF: title + logo + toggle ──────────────────────────────
                    Expanded(
                      child: Stack(
                        children: [
                          // Title + logo row (top-center)
                          Positioned(
                            top: 28,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome to\nResQ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: isSpecial
                                        ? ext.logoTextColor
                                        : const Color(0xFF1A2E3B),
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Logo icon top-right of text
                                Image.asset(
                                  'assets/images/resq_logo.png',
                                  width: 52,
                                  height: 52,
                                  color: isSpecial ? ext.accentOrange : null,
                                ),
                              ],
                            ),
                          ),

                          // Hero pet image — anchored to bottom of top half
                          Positioned(
                            bottom: -size.height * 0.10,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: size.height * 0.40,
                              child: Image.asset(
                                'assets/images/welcome_pets.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── BOTTOM HALF: tagline + CTA ──────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            // Reserve space for pet image overlap
                            SizedBox(height: size.height * 0.13),

                            // Theme toggle

                            // Tagline
                            Text(
                              'Find Your Lost Pet,\nReunite Families.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isSpecial
                                    ? ext.textPrimary
                                    : const Color(0xFF1A2E3B),
                                height: 1.3,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Subtitle
                            Text(
                              'A global community network to bring\npets back home.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isSpecial
                                    ? ext.textSecondary
                                    : const Color(0xFF6B7A8D),
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Spacer(),

                            // GET STARTED button
                            _GetStartedButton(
                              ext: ext,
                              isSpecial: isSpecial,
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/register'),
                            ),

                            const SizedBox(height: 16),

                            // Sign in link
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/login'),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSpecial
                                        ? ext.textSecondary
                                        : const Color(0xFF6B7A8D),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isSpecial
                                            ? ext.accentOrange
                                            : const Color(0xFF1A2E3B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: size.height * .58,
                left: 0,
                right: 0,
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      isSpecial
                          ? Icons.wb_sunny_rounded
                          : Icons.nightlight_round,
                      color: isSpecial
                          ? ext.accentOrange
                          : const Color(0xFF1A2E3B),
                      size: 24,
                    ),
                    onPressed: () => themeNotifier.toggle(),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot page indicator ──────────────────────────────────────────────────────
// ── GET STARTED button ──────────────────────────────────────────────────────
class _GetStartedButton extends StatelessWidget {
  final ResQThemeExtension ext;
  final bool isSpecial;
  final VoidCallback onPressed;

  const _GetStartedButton({
    required this.ext,
    required this.isSpecial,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSpecial ? ext.accentOrange : const Color(0xFFF4874B), // orange
          foregroundColor: isSpecial ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 4,
          shadowColor: isSpecial
              ? Colors.transparent
              : const Color(0xFFF4874B).withValues(alpha: 0.4),
        ),
        child: const Text(
          'GET STARTED',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

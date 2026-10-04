import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';
import 'widgets/home_feed_tab.dart';
import 'widgets/flare_map_tab.dart';
import '../../widgets/app_background.dart';
import '../pet_search/pet_search_page.dart';
import '../profile/profile_screen.dart';

/// Main post-login landing screen.
///
/// • Top bar: ResQ logo, notifications + chat icons, theme-toggle.
/// • Floating pill bottom nav that hides on scroll-down / shows on scroll-up
///   (Facebook-style), using AnimatedSlide on the nav container.
/// • Fully theme-adaptive: reads colors from [ResQThemeExtension] so both
///   Light and Special themes look correct without any branching.
///
/// Route: '/home'
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Shared scroll controller — passed to HomeFeedTab so we can detect
  // scroll direction without duplicating listeners.
  final _scrollController = ScrollController();

  // Bottom nav visibility: true = visible (slide in), false = hidden (slide out).
  final ValueNotifier<bool> _navVisible = ValueNotifier<bool>(true);
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    final diff = offset - _lastScrollOffset;

    // Avoid jitter when the user is barely moving the list.
    if (diff.abs() < 14) return;

    final shouldShow = diff < 0; // scrolling up → show
    if (shouldShow != _navVisible.value) {
      _navVisible.value = shouldShow;
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _navVisible.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 2) {
      // Centre "Create" button
      HapticFeedback.lightImpact();
      Navigator.of(context).pushNamed(AppRoutes.createFlare);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  // Build tab body — we pass the shared scroll controller only to the feed tab
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return HomeFeedTab(scrollController: _scrollController);
      case 1:
        return const FlareMapTab();
      case 3:
        return const _PlaceholderTab(
            label: 'Location', icon: Icons.near_me_rounded);
      case 4:
        return ProfileScreen(scrollController: _scrollController);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true, // lets body go behind the floating nav
        appBar: _selectedIndex == 4 ? null : _buildAppBar(context),
        body: _buildBody(),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _navVisible,
          builder: (context, visible, child) {
            return AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: child,
            );
          },
          child: _FloatingNavBar(
            selectedIndex: _selectedIndex,
            onTap: _onNavTap,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final themeNotifier = context.read<ThemeNotifier>();

    return AppBar(
      backgroundColor: ext.scaffoldBackground.withValues(alpha: 0.92),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: _selectedIndex == 1
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back to home',
              onPressed: () => _onNavTap(0),
            )
          : null,
      titleSpacing: _selectedIndex == 1 ? 0 : 20,
      title: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          children: [
            TextSpan(text: 'Res', style: TextStyle(color: ext.logoTextColor)),
            TextSpan(text: 'Q', style: TextStyle(color: ext.accentOrange)),
          ],
        ),
      ),
      actions: [
        // Theme toggle button
        IconButton(
          icon: Icon(
            themeNotifier.isDark
                ? Icons.wb_sunny_rounded
                : Icons.nightlight_round,
            color: ext.accentOrange,
            size: 22,
          ),
          tooltip: themeNotifier.isDark
              ? 'Switch to Light theme'
              : 'Switch to Dark theme',
          onPressed: () => themeNotifier.toggle(),
        ),
        // Pet search quick action (opens PetSearchPage)
        IconButton(
          icon: Icon(Icons.image_search, color: ext.accentOrange, size: 22),
          tooltip: 'Search similar pets',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PetSearchPage()),
          ),
        ),
        IconButton(
          icon: Icon(Icons.notifications_rounded,
              color: ext.accentOrange, size: 24),
          tooltip: 'Notifications',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications — coming soon')),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chat_bubble_rounded,
              color: ext.accentOrange, size: 22),
          tooltip: 'Chats',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.chatList),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Floating pill bottom navigation bar
// ---------------------------------------------------------------------------

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;

  const _FloatingNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: ext.navBarBackground,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: ext.navBarBorder.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: selectedIndex == 0
                  ? Icons.cottage_rounded
                  : Icons.cottage_outlined,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: selectedIndex == 1 ? Icons.map_rounded : Icons.map_outlined,
              label: 'Map',
              selected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _CreateNavItem(onTap: () => onTap(2)),
            _NavItem(
              icon: selectedIndex == 3
                  ? Icons.location_on_rounded
                  : Icons.location_on_outlined,
              label: 'Location',
              selected: selectedIndex == 3,
              onTap: () => onTap(3),
            ),
            _NavItem(
              icon: selectedIndex == 4
                  ? Icons.account_circle_rounded
                  : Icons.account_circle_outlined,
              label: 'Profile',
              selected: selectedIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    final color = selected ? ext.navSelected : ext.navUnselected;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? ext.navSelected.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre "Create / Flare" action button — orange gradient pill.
class _CreateNavItem extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.flarePublishGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: ext.accentOrange.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Flare',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ext.navSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder tab
// ---------------------------------------------------------------------------

class _PlaceholderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: ext.textSecondary),
          const SizedBox(height: 12),
          Text(
            '$label — coming soon',
            style: TextStyle(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../presentation/screens/onboarding/welcome_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/flare/create_flare_screen.dart';
import '../../presentation/screens/chat/chat_list_screen.dart';
import '../../presentation/screens/admin/admin_dashboard.dart';
import '../../presentation/screens/admin/admin_user_management.dart';
import '../../presentation/screens/admin/create_admin.dart';
import '../../presentation/screens/profile/profile_screen.dart';

/// Central route table. Add each new screen here as it's built.
class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String register = '/register';
  static const String login = '/login';
  static const String home = '/home';
  static const String createFlare = '/create-flare';
  static const String chatList = '/chats';
  static const String profile = '/profile';

  // Admin-only routes
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUserManagement = '/admin/users';

  static Map<String, WidgetBuilder> get routes => {
        welcome: (context) => const WelcomeScreen(),
        register: (context) => const RegisterScreen(),
        login: (context) => const LoginScreen(),
        home: (context) => const HomeScreen(),
        createFlare: (context) => const CreateFlareScreen(),
        chatList: (context) => const ChatListScreen(),
        profile: (context) => const ProfileScreen(),
        adminDashboard: (context) => const AdminDashboardScreen(),
        adminUserManagement: (context) => const AdminUserManagementScreen(),
        // Only super admins should be able to reach this route (UI hides it otherwise)
        '/admin/create': (context) => const CreateAdminScreen(),
      };
}

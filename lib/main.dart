import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/announcement_service.dart';
import 'core/services/notification_service.dart';
import 'core/models/user_model.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/admin/screens/admin_dashboard.dart';
import 'core/services/health_service.dart';
import 'features/health/screens/health_profile_screen.dart';
import 'features/health/screens/schedule_screen.dart';
import 'features/admin/screens/admin_appointments_screen.dart';
import 'features/home/screens/student_home_screen.dart';
import 'features/admin/screens/admin_student_detail_screen.dart';
import 'features/health/screens/daily_check_in_screen.dart';
import 'features/shared/screens/announcement_detail_screen.dart';
import 'features/auth/screens/change_password_screen.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }
  await Firebase.initializeApp();
  
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  
  const MyApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => AIService()),
        ChangeNotifierProvider(create: (_) => AnnouncementService()),
        ChangeNotifierProvider(create: (_) => HealthService()),
        Provider.value(value: notificationService),
      ],
      child: const AppRouter(),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    final router = GoRouter(
      refreshListenable: authService,
      initialLocation: '/splash',
      redirect: (context, state) {
        if (!authService.isInitialized) {
          return '/splash';
        }

        final isLoggedIn = authService.isAuthenticated;
        final isLoggingIn = state.uri.toString() == '/login';
        final isSigningUp = state.uri.toString() == '/signup';
        final isSplash = state.uri.toString() == '/splash';

        if (!isLoggedIn) {
          return (isLoggingIn || isSigningUp) ? null : '/login';
        }

        // Force password change if required
        final requiresPasswordChange =
            authService.currentUser?.requiresPasswordChange ?? false;
        final isChangingPassword = state.uri.toString() == '/change-password';

        if (requiresPasswordChange) {
          return isChangingPassword ? null : '/change-password';
        }

        // Already logged in and doesn't need password change
        if (isLoggingIn || isChangingPassword || isSplash) {
          if (authService.currentUser?.role == UserRole.admin) {
            return '/admin';
          } else {
            return '/student-home';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: '/student-home',
          builder: (context, state) => const StudentHomeScreen(),
        ),
        GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        GoRoute(
          path: '/health-profile',
          builder: (context, state) => const HealthProfileScreen(),
        ),
        GoRoute(
          path: '/schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/daily-check-in',
          builder: (context, state) => const DailyCheckInScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
          routes: [
            GoRoute(
              path: 'appointments',
              builder: (context, state) => const AdminAppointmentsScreen(),
            ),
            GoRoute(
              path: 'student/:studentId',
              builder: (context, state) {
                final studentId = state.pathParameters['studentId']!;
                return AdminStudentDetailScreen(studentId: studentId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/announcement/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AnnouncementDetailScreen(announcementId: id);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Health Support',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

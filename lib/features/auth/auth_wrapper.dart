import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../business/dashboard/business_dashboard_screen.dart';
import '../business/create_business_screen.dart';
import '../cards/my_cards_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../core/theme/app_theme.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _redirectToLogin();
      return;
    }

    try {
      final user = session.user;
      final userRole = user.userMetadata?['role'];

      if (userRole == 'admin') {
        _redirectToAdmin();
      } else if (userRole == 'business') {
        final businessId = user.userMetadata?['business_id'];
        if (businessId == null) {
          _redirectToCreateBusiness();
        } else {
          _redirectToBusiness();
        }
      } else {
        _redirectToClient();
      }
    } catch (e) {
      _redirectToLogin();
    }
  }

  void _redirectToAdmin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _redirectToBusiness() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
    );
  }

  void _redirectToCreateBusiness() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
    );
  }

  void _redirectToClient() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MyCardsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'admin_businesses_screen.dart';
import 'admin_users_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_qr_stats_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Metrics
  int _totalBusinesses = 0;
  int _totalUsers = 0;
  int _totalScans = 0;
  int _totalRewards = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      // Load businesses count
      final businessesResponse = await supabase
          .from('businesses')
          .select('id')
          .count();

      // Load users count
      final usersResponse = await supabase
          .from('profiles')
          .select('id')
          .count();

      // Load scans count
      final scansResponse = await supabase.from('scans').select('id').count();

      // Load rewards count
      final rewardsResponse = await supabase
          .from('rewards')
          .select('id')
          .count();

      if (mounted) {
        setState(() {
          _totalBusinesses = businessesResponse.count ?? 0;
          _totalUsers = usersResponse.count ?? 0;
          _totalScans = scansResponse.count ?? 0;
          _totalRewards = rewardsResponse.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              color: Colors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen General',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Negocios',
                                value: _totalBusinesses.toString(),
                                icon: Icons.storefront,
                                color: AppTheme.accentPurple,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard(
                                title: 'Usuarios',
                                value: _totalUsers.toString(),
                                icon: Icons.people_outline,
                                color: AppTheme.accentYellow,
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 16),
                    Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Escaneos',
                                value: _totalScans.toString(),
                                icon: Icons.qr_code_scanner,
                                color: AppTheme.accentPink,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard(
                                title: 'Premios',
                                value: _totalRewards.toString(),
                                icon: Icons.card_giftcard,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ],
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 32),
                    const Text(
                      'Módulos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ModuleListTile(
                          title: 'Gestión de Negocios',
                          subtitle: 'Ver lista, rendimiento y detalles',
                          icon: Icons.store,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminBusinessesScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Usuarios',
                          subtitle: 'Ver todos los perfiles y roles',
                          icon: Icons.group,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 400.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Estadísticas QR',
                          subtitle: 'Ver ranking de negocios por escaneos',
                          icon: Icons.bar_chart,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminQrStatsScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 450.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Actividad',
                          subtitle: 'Ver historial de escaneos y validaciones',
                          icon: Icons.history,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminActivityScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 500.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Premios',
                          subtitle: 'Ver historial de premios canjeados',
                          icon: Icons.card_giftcard,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminRewardsScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 600.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}

class _ModuleListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

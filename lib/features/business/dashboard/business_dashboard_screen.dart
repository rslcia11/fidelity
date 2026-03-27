import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../qr_management/qr_management_screen.dart';
import '../rewards/rewards_management_screen.dart';
import '../profile/business_profile_screen.dart';
import '../../auth/login_screen.dart';
import '../create_business_screen.dart';
import '../history/business_history_screen.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _business;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _pendingScans = [];
  List<Map<String, dynamic>> _pendingRewards = [];
  Map<String, dynamic>? _stats;
  String _ownerName = '';

  bool _isLoading = true;
  String _searchQuery = '';
  RealtimeChannel? _scansChannel;
  RealtimeChannel? _rewardsChannel;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch owner profile name for greeting
      if (_ownerName.isEmpty) {
        final ownerProfile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        if (ownerProfile != null && mounted) {
          setState(() => _ownerName = ownerProfile['full_name'] ?? '');
        }
      }

      // ✅ CORREGIDO: Sin subscription_plans
      final businessResponse = await supabase
          .from('businesses')
          .select('*')
          .eq('owner_id', userId)
          .maybeSingle(); // 👈 USAR maybeSingle PARA EVITAR ERROR SI NO EXISTE

      if (businessResponse == null) {
        if (mounted) {
          setState(() {
            _business = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Clientes
      final customersResponse = await supabase
          .from('loyalty_cards')
          .select('''
            *,
            profiles(
              id,
              full_name,
              avatar_url
            )
          ''')
          .eq('business_id', businessResponse['id'])
          .order('updated_at', ascending: false);

      // Escaneos Pendientes
      final pendingScansResponse = await supabase
          .from('scans')
          .select('''
            *,
            profiles(
              full_name,
              avatar_url
            )
          ''')
          .eq('business_id', businessResponse['id'])
          .eq('status', 'pending')
          .order('scanned_at', ascending: false);

      // Premios Pendientes
      final pendingRewardsResponse = await supabase
          .from('rewards')
          .select()
          .eq('business_id', businessResponse['id'])
          .eq('status', 'pending');

      // Estadísticas
      final statsResponse = await supabase
          .from('business_stats')
          .select('*')
          .eq('business_id', businessResponse['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _business = businessResponse;
          _customers = List<Map<String, dynamic>>.from(customersResponse);
          _pendingScans = List<Map<String, dynamic>>.from(pendingScansResponse);
          _pendingRewards = List<Map<String, dynamic>>.from(
            pendingRewardsResponse,
          );
          _stats = statsResponse;
          _isLoading = false;
        });

        _setupRealtimeSubscription(businessResponse['id']);
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  void _setupRealtimeSubscription(String businessId) {
    if (_scansChannel != null) return;

    _scansChannel = supabase
        .channel('public:scans')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            if (mounted) {
              _loadBusinessData(silent: true);
            }
          },
        )
        .subscribe();

    _rewardsChannel = supabase
        .channel('public:rewards')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rewards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            if (mounted) {
              _loadBusinessData(silent: true);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _scansChannel?.unsubscribe();
    _rewardsChannel?.unsubscribe();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final profile = customer['profiles'];
      final name = profile?['full_name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  /// Extracts first name + last name from full_name string.
  String get _ownerDisplayName {
    if (_ownerName.isEmpty) return '';
    final parts = _ownerName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  Future<void> _addPointsManually(String userId, int points) async {
    try {
      final businessId = _business!['id'];

      await supabase.rpc(
        'add_manual_points',
        params: {
          'p_user_id': userId,
          'p_business_id': businessId,
          'p_points': points,
        },
      );

      final card = _customers.firstWhere((c) => c['user_id'] == userId);

      await supabase.from('scans').insert({
        'user_id': userId,
        'business_id': businessId,
        'loyalty_card_id': card['id'],
        'qr_code_id': null,
        'scanned_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Puntos agregados'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  Future<void> _approveScan(String scanId, String loyaltyCardId) async {
    try {
      final cardResponse = await supabase
          .from('loyalty_cards')
          .select(
            'current_points, total_points_lifetime, rewards_claimed, user_id, businesses(id, points_required)',
          )
          .eq('id', loyaltyCardId)
          .single();

      final currentPoints = (cardResponse['current_points'] as int) + 1;
      final totalPointsLifetime =
          (cardResponse['total_points_lifetime'] as int) + 1;

      final business = cardResponse['businesses'];
      final pointsRequired = business != null
          ? (business['points_required'] as int)
          : 10;
      final userId = cardResponse['user_id'] as String;
      final businessId = business != null ? business['id'] as String : '';

      int pointsToUpdate = currentPoints;
      int rewardsClaimedUpdate = (cardResponse['rewards_claimed'] ?? 0) as int;
      bool rewardGenerated = false;

      // Si los puntos alcanzan el requerido, generar premio y reiniciar puntos a 0
      if (currentPoints >= pointsRequired && businessId.isNotEmpty) {
        await supabase.from('rewards').insert({
          'user_id': userId,
          'business_id': businessId,
          'loyalty_card_id': loyaltyCardId,
          'points_used': pointsRequired,
          'description': business?['reward_description'] ?? 'Premio',
          'earned_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        });

        pointsToUpdate = 0;
        rewardsClaimedUpdate += 1;
        rewardGenerated = true;
      }

      await supabase
          .from('loyalty_cards')
          .update({
            'current_points': pointsToUpdate,
            'total_points_lifetime': totalPointsLifetime,
            'rewards_claimed': rewardsClaimedUpdate,
            'last_scan_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loyaltyCardId);

      await supabase
          .from('scans')
          .update({'status': 'approved'})
          .eq('id', scanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rewardGenerated
                  ? '✅ Escaneo aprobado. ¡Premio generado!'
                  : '✅ Escaneo aprobado',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  Future<void> _rejectScan(String scanId) async {
    try {
      await supabase
          .from('scans')
          .update({'status': 'rejected'})
          .eq('id', scanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escaneo rechazado'),
            backgroundColor: Colors.black54,
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  Future<void> _redeemReward(String userId, String cardId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canjear premio'),
        content: Text(
          '¿Canjear premio por ${_business!['points_required']} puntos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc(
        'redeem_reward',
        params: {
          'p_user_id': userId,
          'p_business_id': _business!['id'],
          'p_loyalty_card_id': cardId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Premio canjeado'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation(AppTheme.accentPurple),
          ),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Negocio'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 80,
                    color: AppTheme.accentPurple,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'SIN NEGOCIO',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Registra tu local para empezar a fidelizar a tus clientes con puntos y premios.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateBusinessScreen(),
                        ),
                      );
                      _loadBusinessData();
                    },
                    child: const Text('REGISTRAR MI LOCAL'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 90,
          leadingWidth: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusinessProfileScreen(
                      business: _business!,
                      ownerName: _ownerName,
                    ),
                  ),
                );
                if (result == true) {
                  _loadBusinessData();
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'business_logo',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        backgroundImage: _business!['logo_url'] != null
                            ? NetworkImage(_business!['logo_url'])
                            : null,
                        child: _business!['logo_url'] == null
                            ? const Icon(
                                Icons.store,
                                color: Colors.black,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child:
                        Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.accentPurple,
                                    AppTheme.accentPink,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentPurple.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            )
                            .animate(
                              onPlay: (controller) =>
                                  controller.repeat(reverse: true),
                            )
                            .scale(
                              duration: const Duration(seconds: 1),
                              begin: const Offset(1, 1),
                              end: const Offset(1.15, 1.15),
                              curve: Curves.easeInOut,
                            )
                            .shimmer(
                              duration: const Duration(seconds: 3),
                              color: Colors.white.withOpacity(0.5),
                            ),
                  ),
                ],
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_ownerDisplayName.isNotEmpty)
                Text(
                  'Hola, $_ownerDisplayName 👋',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              Text(
                _business!['name'].toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_customers.length} CLIENTES ACTIVOS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: Colors.black,
            unselectedLabelColor: Colors.black38,
            isScrollable: true,
            tabs: [
              const Tab(text: 'CLIENTES'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PENDIENTES'),
                    if (_pendingScans.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentPink,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_pendingScans.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PREMIOS'),
                    if (_pendingRewards.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentPurple,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_pendingRewards.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'MÉTRICAS'),
              const Tab(text: 'QR CODES'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCustomersTab(),
            _buildPendingTab(),
            RewardsManagementScreen(businessId: _business!['id']),
            _buildStatisticsTab(),
            QRManagementScreen(businessId: _business!['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'BUSCAR CLIENTE...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.black,
                size: 24,
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Colors.black.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'NO HAY CLIENTES AÚN'
                            : 'SIN RESULTADOS',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black26,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final card = _filteredCustomers[index];
                    final profile = card['profiles'];
                    final accentColor = [
                      AppTheme.accentPurple,
                      AppTheme.accentPink,
                      AppTheme.accentYellow,
                      AppTheme.accentGreen,
                    ][index % 4];

                    return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.black.withOpacity(0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: accentColor.withOpacity(0.1),
                                child: Text(
                                  (profile?['full_name']?[0] ?? '?')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (profile?['full_name'] ?? 'USUARIO')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${card['total_points_lifetime'] ?? 0} ESCANEOS',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Colors.black12,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${card['rewards_claimed'] ?? 0} PREMIOS',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.black45,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                onSelected: (value) {
                                  if (value == 'add_points')
                                    _showAddPointsDialog(card);
                                  else if (value == 'redeem')
                                    _redeemReward(card['user_id'], card['id']);
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'add_points',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 20,
                                          color: accentColor,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'PUNTOS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if ((card['current_points'] ?? 0) >=
                                      _business!['points_required'])
                                    const PopupMenuItem(
                                      value: 'redeem',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.card_giftcard_rounded,
                                            size: 20,
                                            color: AppTheme.accentGreen,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'CANJEAR',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        )
                        .animate(delay: AppTheme.animDelayStaggered(index))
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPendingTab() {
    if (_pendingScans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡TODO AL DÍA!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'No hay escaneos por aprobar.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black26,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingScans.length,
      itemBuilder: (context, index) {
        final scan = _pendingScans[index];
        final profile = scan['profiles'];
        return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.black.withOpacity(0.04),
                    child: Text(
                      (profile?['full_name']?[0] ?? '?').toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (profile?['full_name'] ?? 'USUARIO').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          EcuadorDateUtils.formatEcuadorTime(
                            scan['scanned_at'],
                          ).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.accentPink,
                        ),
                        onPressed: () => _rejectScan(scan['id']),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.accentGreen,
                        ),
                        onPressed: () =>
                            _approveScan(scan['id'], scan['loyalty_card_id']),
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animate(delay: AppTheme.animDelayStaggered(index))
            .fadeIn(duration: AppTheme.animDurationStandard)
            .slideY(
              begin: AppTheme.animSlideYBegin,
              curve: AppTheme.animCurveStandard,
            );
      },
    );
  }

  Widget _buildStatisticsTab() {
    final totalScans = _customers.fold<int>(
      0,
      (sum, card) => sum + ((card['total_points_lifetime'] ?? 0) as int),
    );
    final totalRewards = _customers.fold<int>(
      0,
      (sum, card) => sum + ((card['rewards_claimed'] ?? 0) as int),
    );

    final createdAtString = _business!['created_at'] ?? '';
    final createdAt = EcuadorDateUtils.toEcuadorTime(createdAtString);
    final daysLive = EcuadorDateUtils.nowEcuador().difference(createdAt).inDays;
    final formattedDate =
        "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INFORMACIÓN DE CAMPAÑA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'INICIO',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DÍAS ACTIVO',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysLive DÍAS',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _StatCard(
                title: 'CLIENTES',
                value: '${_customers.length}',
                icon: Icons.people_rounded,
                color: AppTheme.accentPurple,
                onTap: _showCustomersModal,
                subtitle: 'PERSONA ÚNICAS VISITARON',
              )
              .animate()
              .fadeIn(duration: AppTheme.animDurationStandard)
              .slideY(
                begin: AppTheme.animSlideYBegin,
                curve: AppTheme.animCurveStandard,
              ),
          const SizedBox(height: 16),
          _StatCard(
                title: 'ESCANEOS',
                value: '$totalScans',
                icon: Icons.qr_code_scanner_rounded,
                color: AppTheme.accentYellow,
                onTap: _showTopScansModal,
                subtitle: 'VISITAS TOTALES REGISTRADAS',
              )
              .animate(delay: 100.ms)
              .fadeIn(duration: AppTheme.animDurationStandard)
              .slideY(
                begin: AppTheme.animSlideYBegin,
                curve: AppTheme.animCurveStandard,
              ),
          const SizedBox(height: 16),
          _StatCard(
                title: 'PREMIOS',
                value: '$totalRewards',
                icon: Icons.card_giftcard_rounded,
                color: AppTheme.accentPink,
                onTap: _showRewardsModal,
                subtitle: 'RECOMPENSAS CANJEADAS',
              )
              .animate(delay: 200.ms)
              .fadeIn(duration: AppTheme.animDurationStandard)
              .slideY(
                begin: AppTheme.animSlideYBegin,
                curve: AppTheme.animCurveStandard,
              ),
          const SizedBox(height: 16),
          _StatCard(
                title: 'REQUISITO',
                value: '${_business!['points_required']}',
                icon: Icons.star_rounded,
                color: AppTheme.accentGreen,
                onTap: _showEditRewardDialog,
                subtitle: 'PUNTOS PARA UN PREMIO',
              )
              .animate(delay: 300.ms)
              .fadeIn(duration: AppTheme.animDurationStandard)
              .slideY(
                begin: AppTheme.animSlideYBegin,
                curve: AppTheme.animCurveStandard,
              ),
        ],
      ),
    );
  }

  void _showCustomersModal() {
    _showListModal(
      title: 'Lista de Clientes',
      icon: Icons.people,
      color: AppTheme.accentPurple,
      items: _customers,
      subtitleBuilder: (card) =>
          '${card['total_points_lifetime'] ?? 0} escaneos en total',
      trailingBuilder: (card) => Text(
        '${card['current_points'] ?? 0} pts',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.accentPurple,
          fontSize: 16,
        ),
      ),
    );
  }

  void _showTopScansModal() {
    final sortedByScans = List<Map<String, dynamic>>.from(_customers)
      ..sort(
        (a, b) => ((b['total_points_lifetime'] ?? 0) as int).compareTo(
          (a['total_points_lifetime'] ?? 0) as int,
        ),
      );

    // Filter out users with 0 scans to keep it clean
    final activeUsers = sortedByScans
        .where((c) => (c['total_points_lifetime'] ?? 0) > 0)
        .toList();

    _showListModal(
      title: 'Ranking de Escaneos',
      icon: Icons.qr_code_scanner,
      color: AppTheme.accentYellow,
      items: activeUsers,
      subtitleBuilder: (card) => 'Total de escaneos históricos',
      trailingBuilder: (card) => Text(
        '${card['total_points_lifetime'] ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  void _showRewardsModal() {
    final sortedByRewards = List<Map<String, dynamic>>.from(_customers)
      ..sort(
        (a, b) => ((b['rewards_claimed'] ?? 0) as int).compareTo(
          (a['rewards_claimed'] ?? 0) as int,
        ),
      );

    // Filter out users with 0 rewards
    final rewardUsers = sortedByRewards
        .where((c) => (c['rewards_claimed'] ?? 0) > 0)
        .toList();

    _showListModal(
      title: 'Ranking de Premios',
      icon: Icons.card_giftcard,
      color: AppTheme.accentGreen,
      items: rewardUsers,
      subtitleBuilder: (card) => 'Premios totales reclamados',
      trailingBuilder: (card) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${card['rewards_claimed'] ?? 0} 🎁',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.accentGreen,
          ),
        ),
      ),
    );
  }

  void _showListModal({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required Widget Function(Map<String, dynamic>) trailingBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Text(
                      '${items.length} REGISTROS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black26,
                        fontSize: 10,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 48,
                                  color: Colors.black.withOpacity(0.05),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'NO HAY REGISTROS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black26,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final profile = item['profiles'];
                              final name = (profile?['full_name'] ?? 'USUARIO')
                                  .toUpperCase();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withOpacity(0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    subtitleBuilder(item).toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      color: Colors.black38,
                                    ),
                                  ),
                                  trailing: trailingBuilder(item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddPointsDialog(Map<String, dynamic> card) {
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('SUMAR PUNTOS', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card['profiles']['full_name'].toString().toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PUNTOS A SUMAR'),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                final points = int.tryParse(pointsController.text);
                if (points != null && points > 0) {
                  Navigator.pop(context);
                  _addPointsManually(card['user_id'], points);
                }
              },
              child: const Text('AGREGAR'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showEditRewardDialog() {
    final rewardController = TextEditingController(
      text: _business!['reward_description'] ?? '',
    );
    final pointsController = TextEditingController(
      text: '${_business!['points_required']}',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          title: const Text('EDITAR PRODUCTO', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rewardController,
                decoration: const InputDecoration(
                  labelText: '¿QUÉ VAS A PREMIAR?',
                  hintText: 'Ej: Un vaso de helado',
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PUNTOS NECESARIOS',
                  hintText: 'Ej: 3',
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final newDesc = rewardController.text.trim().toUpperCase();
                  final newPoints =
                      int.tryParse(pointsController.text.trim()) ?? 10;
                  if (newDesc.isEmpty || newPoints < 1) return;
                  try {
                    await supabase
                        .from('businesses')
                        .update({
                          'reward_description': newDesc,
                          'points_required': newPoints,
                        })
                        .eq('id', _business!['id']);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadBusinessData();
                    }
                  } catch (e) {
                    debugPrint('Error: $e');
                  }
                },
                child: const Text('GUARDAR CAMBIOS'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final ImagePicker picker = ImagePicker();

    // Show simple bottom sheet to ask user for photo source
    final source = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'FOTO DE PERFIL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.accentPurple,
                ),
              ),
              title: const Text(
                'ELEGIR DE GALERÍA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.accentYellow,
                ),
              ),
              title: const Text(
                'TOMAR FOTO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (_business!['logo_url'] != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPink.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: AppTheme.accentPink,
                  ),
                ),
                title: const Text(
                  'ELIMINAR FOTO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppTheme.accentPink,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    if (source == null) return; // User canceled

    if (source == 'delete') {
      try {
        final userId = supabase.auth.currentUser!.id;
        final logoUrl = _business!['logo_url'] as String;

        // Extraer el path original del bucket a partir de la URL pública
        // Normalmente la URL es: .../storage/v1/object/public/business-logos/USER_ID/FILENAME.ext
        final uri = Uri.parse(logoUrl);
        final pathSegments = uri.pathSegments;
        final folderIndex = pathSegments.indexOf('business-logos');
        if (folderIndex != -1 && folderIndex + 1 < pathSegments.length) {
          final objectPath = pathSegments.sublist(folderIndex + 1).join('/');
          await supabase.storage.from('business-logos').remove([objectPath]);
        }

        await supabase
            .from('businesses')
            .update({'logo_url': null})
            .eq('owner_id', userId);

        if (mounted) {
          _loadBusinessData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto eliminada exitosamente'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar foto: $e'),
              backgroundColor: AppTheme.accentPink,
            ),
          );
        }
      }
      return;
    }

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source as ImageSource,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      if (!mounted) return;

      // Loading indicator during upload
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation(AppTheme.accentPurple),
          ),
        ),
      );

      final fileBytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final userId = supabase.auth.currentUser!.id;
      final imagePath = '$userId/$fileName';

      String mimeType = 'image/jpeg';
      if (fileExt == 'png')
        mimeType = 'image/png';
      else if (fileExt == 'webp')
        mimeType = 'image/webp';
      else if (fileExt == 'gif')
        mimeType = 'image/gif';

      // Ensure we hit the storage API using uploadBinary for Web compatibility
      await supabase.storage
          .from('business-logos')
          .uploadBinary(
            imagePath,
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: mimeType,
            ),
          );
      final newLogoUrl = supabase.storage
          .from('business-logos')
          .getPublicUrl(imagePath);

      // Update DB reference
      await supabase
          .from('businesses')
          .update({'logo_url': newLogoUrl})
          .eq('owner_id', userId);

      if (mounted) {
        Navigator.pop(context); // close dialog
        _loadBusinessData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo actualizado exitosamente'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar logo: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(48),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ).animate().scale(
                    curve: AppTheme.animCurveElastic,
                    duration: AppTheme.animDurationSlow,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black26,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

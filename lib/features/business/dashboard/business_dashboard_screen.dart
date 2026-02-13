// lib/features/business/dashboard/business_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../qr_management/qr_management_screen.dart';
import '../rewards/rewards_management_screen.dart';
import '../../auth/login_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _business;
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _stats;
  
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // ✅ CORREGIDO: Sin subscription_plans
      final businessResponse = await supabase
          .from('businesses')
          .select('*')
          .eq('owner_id', userId)
          .maybeSingle();  // 👈 USAR maybeSingle PARA EVITAR ERROR SI NO EXISTE

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
            profiles!inner(
              id,
              full_name,
              email,
              avatar_url
            )
          ''')
          .eq('business_id', businessResponse['id'])
          .order('updated_at', ascending: false);

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
          _stats = statsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFB85C50),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final profile = customer['profiles'];
      final name = profile['full_name']?.toString().toLowerCase() ?? '';
      final email = profile['email']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) ||
             email.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _addPointsManually(String userId, int points) async {
    try {
      final businessId = _business!['id'];
      
      await supabase.rpc('add_manual_points', params: {
        'p_user_id': userId,
        'p_business_id': businessId,
        'p_points': points,
      });

      final card = _customers.firstWhere((c) => c['user_id'] == userId);
      
      await supabase.from('scans').insert({
        'user_id': userId,
        'business_id': businessId,
        'loyalty_card_id': card['id'],
        'qr_code_id': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Puntos agregados'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFB85C50),
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
        content: Text('¿Canjear premio por ${_business!['points_required']} puntos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6F47),
            ),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc('redeem_reward', params: {
        'p_user_id': userId,
        'p_business_id': _business!['id'],
        'p_loyalty_card_id': cardId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Premio canjeado'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFB85C50),
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
            valueColor: AlwaysStoppedAnimation(Color(0xFF8B6F47)),
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
          iconTheme: const IconThemeData(color: Color(0xFF2C2416)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6F47).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: Color(0xFF8B6F47),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No tienes un negocio registrado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2416),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registra tu negocio para empezar',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF6B5D4F).withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Próximamente...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B6F47),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Registrar mi negocio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _business!['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2416),
                ),
              ),
              Text(
                '${_customers.length} clientes',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B5D4F),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF2C2416)),
          bottom: const TabBar(
            labelColor: Color(0xFF8B6F47),
            unselectedLabelColor: Color(0xFF6B5D4F),
            indicatorColor: Color(0xFF8B6F47),
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Clientes'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Estadísticas'),
              Tab(icon: Icon(Icons.qr_code), text: 'QR Codes'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
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
          ],
        ),
        body: TabBarView(
          children: [
            _buildCustomersTab(),
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
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8B6F47)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F1E8).withOpacity(0.5),
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
                        Icons.people_outline,
                        size: 64,
                        color: const Color(0xFF8B6F47).withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No tienes clientes aún'
                            : 'No se encontraron clientes',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B5D4F),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final card = _filteredCustomers[index];
                    final profile = card['profiles'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF8B6F47).withOpacity(0.1),
                              child: Text(
                                profile['full_name']?[0] ?? '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B6F47),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile['full_name'] ?? 'Usuario',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C2416),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile['email'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B5D4F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B6F47).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${card['current_points']} pts',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8B6F47),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'add_points') {
                                  _showAddPointsDialog(card);
                                } else if (value == 'redeem') {
                                  _redeemReward(
                                    card['user_id'],
                                    card['id'],
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'add_points',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle, color: Color(0xFF8B6F47)),
                                      SizedBox(width: 8),
                                      Text('Agregar puntos'),
                                    ],
                                  ),
                                ),
                                if (card['current_points'] >= _business!['points_required'])
                                  const PopupMenuItem(
                                    value: 'redeem',
                                    child: Row(
                                      children: [
                                        Icon(Icons.card_giftcard, color: Color(0xFF4CAF50)),
                                        SizedBox(width: 8),
                                        Text('Canjear premio'),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                title: 'Clientes',
                value: '${_customers.length}',
                icon: Icons.people,
                color: const Color(0xFF2196F3),
              ),
              _StatCard(
                title: 'Escaneos',
                value: '$totalScans',
                icon: Icons.qr_code_scanner,
                color: const Color(0xFF8B6F47),
              ),
              _StatCard(
                title: 'Premios',
                value: '$totalRewards',
                icon: Icons.card_giftcard,
                color: const Color(0xFF4CAF50),
              ),
              _StatCard(
                title: 'Puntos req.',
                value: '${_business!['points_required']}',
                icon: Icons.star,
                color: const Color(0xFF9C27B0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPointsDialog(Map<String, dynamic> card) {
    final pointsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar puntos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cliente: ${card['profiles']['full_name']}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Puntos',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final points = int.tryParse(pointsController.text);
              if (points != null && points > 0) {
                Navigator.pop(context);
                _addPointsManually(card['user_id'], points);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6F47),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2416),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B5D4F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
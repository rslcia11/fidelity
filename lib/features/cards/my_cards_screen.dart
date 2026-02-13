import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../scanner/scanner_screen.dart';
import '../auth/login_screen.dart'; // Asegúrate de que esta ruta sea correcta

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('loyalty_cards')
          .select('''
            *,
            businesses!inner(
              id,
              name,
              category,
              reward_description,
              points_required,
              logo_url
            )
          ''')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _cards = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando tarjetas: $e'),
            backgroundColor: const Color(0xFFB85C50),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'cafe':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'bakery':
        return Icons.bakery_dining;
      case 'gym':
        return Icons.fitness_center;
      case 'salon':
        return Icons.content_cut;
      case 'spa':
        return Icons.spa;
      case 'retail':
        return Icons.shopping_bag;
      case 'grocery':
        return Icons.shopping_cart;
      case 'pharmacy':
        return Icons.medication;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'car_wash':
        return Icons.local_car_wash;
      default:
        return Icons.store;
    }
  }

  Future<void> _logout() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro que deseas cerrar sesión?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF6B5D4F)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B6F47),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    // Si el usuario canceló, no hacer nada
    if (confirm != true) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF8B6F47)),
        ),
      ),
    );

    try {
      await supabase.auth.signOut();
      
      if (mounted) {
        // Cerrar el diálogo de carga
        Navigator.of(context).pop();
        
        // Limpiar TODO el stack de navegación y navegar al login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Cerrar el diálogo de carga
        Navigator.of(context).pop();
        
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: const Color(0xFFB85C50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Tarjetas',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2416),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C2416)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF8B6F47)),
              ),
            )
          : _cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard_outlined,
                        size: 80,
                        color: const Color(0xFF8B6F47).withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes tarjetas aún',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B5D4F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escanea un QR para comenzar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B5D4F),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ScannerScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear ahora'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B6F47),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCards,
                  color: const Color(0xFF8B6F47),
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final business = card['businesses'];
                      final currentPoints = card['current_points'] as int;
                      final pointsRequired = business['points_required'] as int;
                      final progress = currentPoints / pointsRequired;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header con ícono y nombre
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B6F47)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(business['category']),
                                      color: const Color(0xFF8B6F47),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          business['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2C2416),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          business['reward_description'] ?? 'Acumula puntos y gana premios',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B5D4F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Barra de progreso
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$currentPoints de $pointsRequired puntos',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2C2416),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF8B6F47),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      minHeight: 12,
                                      backgroundColor: const Color(0xFFD4A574)
                                          .withOpacity(0.2),
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              Color(0xFF8B6F47)),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Estadísticas
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFF5F1E8).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatItem(
                                      icon: Icons.stars,
                                      label: 'Total',
                                      value: (card['total_points_lifetime'] ?? 0)
                                          .toString(),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: const Color(0xFF6B5D4F)
                                          .withOpacity(0.2),
                                    ),
                                    _StatItem(
                                      icon: Icons.card_giftcard,
                                      label: 'Premios',
                                      value: (card['rewards_claimed'] ?? 0)
                                          .toString(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      
      // Botón flotante para escanear
      floatingActionButton: _cards.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScannerScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF8B6F47),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text(
                'Escanear QR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
    );
  }
}

// Widget para mostrar estadísticas
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF8B6F47),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C2416),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B5D4F),
          ),
        ),
      ],
    );
  }
}
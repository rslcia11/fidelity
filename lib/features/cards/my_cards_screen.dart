import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../scanner/scanner_screen.dart';
import '../auth/login_screen.dart';
import 'card_history_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../core/theme/app_theme.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  String _userName = '';
  String? _avatarUrl;
  RealtimeChannel? _cardsChannel;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch user profile name for greeting
      if (_userName.isEmpty) {
        final profile = await supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _userName = profile['full_name'] ?? '';
            _avatarUrl = profile['avatar_url'];
          });
        }
      }

      final response = await supabase
          .from('loyalty_cards')
          .select('''
            *,
            businesses!inner(
              id,
              name,
              category_id,
              business_categories(name),
              reward_description,
              reward_long_description,
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

        _setupRealtimeSubscription(userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeSubscription(String userId) {
    if (_cardsChannel != null) return;

    _cardsChannel = supabase
        .channel('public:loyalty_cards_client')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loyalty_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) {
              final newData = payload.newRecord;
              final oldData = payload.oldRecord;

              if (newData != null && oldData != null) {
                final newClaimed = (newData['rewards_claimed'] as int?) ?? 0;
                final oldClaimed = (oldData['rewards_claimed'] as int?) ?? 0;

                if (newClaimed > oldClaimed) {
                  _showCelebrationDialog();
                }
              }
              _loadCards(silent: true);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _cardsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          title: const Text('¿CERRAR SESIÓN?'),
          content: const Text('¿Estás seguro que deseas salir de tu cuenta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CERRAR SESIÓN'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 64,
                    color: AppTheme.accentGreen,
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .then()
                .scale(
                  begin: const Offset(1.2, 1.2),
                  end: const Offset(0.8, 0.8),
                ),
            const SizedBox(height: 32),
            const Text(
              '¡FELICIDADES!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '¡HAS COMPLETADO TU TARJETA!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.accentPurple,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ya puedes acercarte al local para reclamar tu premio. ¡Disfrútalo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text('¡GENIAL!'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Extracts first name + last name from full_name string.
  String get _displayName {
    if (_userName.isEmpty) return '';
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_displayName.isNotEmpty)
              Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (_userName.isNotEmpty)
              Text(
                'Hola, ${_userName.split(' ')[0]} 👋',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                ),
              ),
            const Text(
              'MIS TARJETAS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
                if (result == true) _loadCards();
              },
              child: Hero(
                tag: 'user_avatar',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentPurple.withOpacity(0.1),
                    image: _avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _avatarUrl == null
                      ? Center(
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accentPurple,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.black26),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
          ? _buildEmptyState(theme)
          : RefreshIndicator(
              onRefresh: _loadCards,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  return _LoyaltyCardItem(
                    card: _cards[index],
                    index: index,
                    onTap: () {
                      final card = _cards[index];
                      final business = card['businesses'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardHistoryScreen(
                            loyaltyCardId: card['id'],
                            businessId: business['id'],
                            businessName: business['name'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
      floatingActionButton: _cards.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('ESCANEAR QR'),
            ).animate().scale(delay: 1.seconds, curve: Curves.elasticOut),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              size: 80,
              color: AppTheme.accentPurple,
            ),
          ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
          const SizedBox(height: 32),
          const Text(
            '¡EMPIEZA TU COLECCIÓN!',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ESCANEA TU PRIMER CÓDIGO QR EN\nCUALQUIER LOCAL AFILIADO.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black26,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('ESCANEAR AHORA'),
              )
              .animate(delay: 400.ms)
              .fadeIn()
              .moveY(begin: 20, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _LoyaltyCardItem extends StatelessWidget {
  final Map<String, dynamic> card;
  final int index;
  final VoidCallback onTap;

  const _LoyaltyCardItem({
    required this.card,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final business = card['businesses'];
    final currentPoints = card['current_points'] as int;
    final pointsRequired = business['points_required'] as int;
    final progress = (currentPoints / pointsRequired).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    // Colores dinámicos basados en el índice para variedad (Estilo Emote)
    final accents = [
      AppTheme.accentPurple,
      AppTheme.accentPink,
      AppTheme.accentYellow,
      AppTheme.accentGreen,
    ];
    final accentColor = accents[index % accents.length];

    return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        image: business['logo_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(business['logo_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: business['logo_url'] == null
                          ? Icon(
                              AppTheme.getCategoryIcon(
                                business['business_categories']?['name'] ??
                                    business['category'],
                              ),
                              color: accentColor,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business['name'].toString().toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (business['reward_description'] != null)
                            Text(
                              business['reward_description']!
                                  .toString()
                                  .toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (business['reward_long_description'] != null)
                            Text(
                              business['reward_long_description'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Progreso Estilo Minimalista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentPoints / $pointsRequired PUNTOS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 14,
                    backgroundColor: accentColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),

                const SizedBox(height: 32),

                // Stats en horizontal
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.auto_awesome,
                      value: (card['total_points_lifetime'] ?? 0).toString(),
                      label: 'TOTAL',
                      color: accentColor,
                    ),
                    const Spacer(),
                    _MiniStat(
                      icon: Icons.card_giftcard,
                      value: (card['rewards_claimed'] ?? 0).toString(),
                      label: 'CANJES',
                      color: AppTheme.accentPink,
                    ),
                    const Spacer(),
                    _MiniStat(
                      icon: Icons.calendar_today_outlined,
                      value: 'ACTIVA',
                      label: 'ESTADO',
                      color: AppTheme.accentGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: (index * 100).ms)
        .slideY(begin: 0.2, curve: Curves.elasticOut, duration: 800.ms)
        .fadeIn();
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

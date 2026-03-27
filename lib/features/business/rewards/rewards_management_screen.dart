// lib/features/business/rewards/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';

class RewardsManagementScreen extends StatefulWidget {
  final String businessId;
  const RewardsManagementScreen({super.key, required this.businessId});

  @override
  State<RewardsManagementScreen> createState() =>
      _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends State<RewardsManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _redeemedRewards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch rewards directly (no join to avoid PGRST200)
      final rewardsResponse = await supabase
          .from('rewards')
          .select('*')
          .eq('business_id', widget.businessId)
          .order('earned_at', ascending: false);

      final List<Map<String, dynamic>> rewards = List<Map<String, dynamic>>.from(rewardsResponse);

      if (rewards.isEmpty) {
        if (mounted) setState(() { _redeemedRewards = []; _isLoading = false; });
        return;
      }

      // 2. Fetch profiles for these rewards manually
      final userIds = rewards.map((r) => r['user_id'] as String).toSet().toList();
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds);

      final Map<String, String> profileMap = {
        for (var p in profilesResponse) p['id'] as String : (p['full_name'] ?? 'USUARIO').toString()
      };

      // 3. Merge data
      final mergedRewards = rewards.map((reward) {
        final userId = reward['user_id'] as String;
        return {
          ...reward,
          'display_name': profileMap[userId] ?? 'USUARIO'
        };
      }).toList();

      if (mounted) {
        setState(() {
          _redeemedRewards = mergedRewards;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading rewards: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveReward(String rewardId) async {
    try {
      await supabase
          .from('rewards')
          .update({'status': 'approved'})
          .eq('id', rewardId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Entrega de premio aprobada'), backgroundColor: AppTheme.accentGreen),
        );
        _loadRewards();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _rejectReward(String rewardId) async {
    try {
      await supabase
          .from('rewards')
          .update({'status': 'rejected'})
          .eq('id', rewardId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premio rechazado'), backgroundColor: AppTheme.accentPink),
        );
        _loadRewards();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _redeemedRewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: AppTheme.accentPurple.withOpacity(0.05), shape: BoxShape.circle),
                        child: const Icon(Icons.card_giftcard_rounded, size: 64, color: AppTheme.accentPurple),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SIN PREMIOS AÚN',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                      ),
                      const Text(
                        'Aquí verás los premios por aprobar y entregados.',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black26),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  itemCount: _redeemedRewards.length,
                  itemBuilder: (context, index) {
                    final reward = _redeemedRewards[index];
                    final String fullName = reward['display_name'].toUpperCase();
                    final String date = EcuadorDateUtils.formatEcuadorTime(reward['earned_at']);
                    final String status = reward['status'] ?? 'pending';

                    Color statusColor = AppTheme.accentYellow;
                    String statusLabel = 'PENDIENTE';
                    if (status == 'approved') {
                      statusColor = AppTheme.accentGreen;
                      statusLabel = 'ENTREGADO';
                    } else if (status == 'rejected') {
                      statusColor = AppTheme.accentPink;
                      statusLabel = 'RECHAZADO';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: status == 'pending' ? statusColor.withOpacity(0.2) : Colors.black.withOpacity(0.03)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  fullName.isNotEmpty ? fullName[0] : '?',
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'GANADO EL $date',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black38),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                            ],
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => _rejectReward(reward['id']),
                                    child: const Text('RECHAZAR', style: TextStyle(color: Colors.black26, fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approveReward(reward['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('ENTREGAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate(delay: (index * 50).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut);
                  },
                ),
    );
  }
}

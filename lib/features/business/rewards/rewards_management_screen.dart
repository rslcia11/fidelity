// lib/features/business/rewards/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsManagementScreen extends StatefulWidget {
  final String businessId;
  const RewardsManagementScreen({super.key, required this.businessId});

  @override
  State<RewardsManagementScreen> createState() => _RewardsManagementScreenState();
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
    final response = await supabase
        .from('rewards')
        .select('''
          *,
          profiles!inner(
            full_name,
            email
          )
        ''')
        .eq('business_id', widget.businessId)
        .order('earned_at', ascending: false);

    setState(() {
      _redeemedRewards = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _redeemedRewards.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard_outlined,
                        size: 64,
                        color: Color(0xFF8B6F47),
                      ),
                      SizedBox(height: 16),
                      Text('No hay premios canjeados aún'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _redeemedRewards.length,
                  itemBuilder: (context, index) {
                    final reward = _redeemedRewards[index];
                    final profile = reward['profiles'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF8B6F47).withOpacity(0.1),
                          child: Text(
                            profile['full_name']?[0] ?? '?',
                            style: const TextStyle(
                              color: Color(0xFF8B6F47),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(profile['full_name'] ?? 'Usuario'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${reward['points_used']} puntos'),
                            Text(
                              'Canjeado: ${DateTime.parse(reward['earned_at']).toLocal()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Canjeado',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
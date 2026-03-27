import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _businessesList = [];
  String _selectedFilter = 'all';
  String _selectedBusinessId = 'all';

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadActivity();
  }

  Future<void> _loadBusinesses() async {
    try {
      final response = await supabase
          .from('businesses')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _businessesList = List<Map<String, dynamic>>.from(response);
          // Insert a "Todos" option at the beginning if needed, though we can handle it in the UI mapping.
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('scans').select('''
            id,
            scanned_at,
            status,
            profiles:user_id (full_name, email),
            businesses:business_id (name)
          ''');

      // Filter logic
      final now = EcuadorDateUtils.nowEcuador();
      if (_selectedFilter == 'today') {
        final startOfDay = DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String();
        query = query.gte('scanned_at', startOfDay);
      } else if (_selectedFilter == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        ).toUtc().toIso8601String();
        query = query.gte('scanned_at', startOfWeekDay);
      } else if (_selectedFilter == 'month') {
        final startOfMonth = DateTime(
          now.year,
          now.month,
          1,
        ).toUtc().toIso8601String();
        query = query.gte('scanned_at', startOfMonth);
      }

      if (_selectedBusinessId != 'all') {
        query = query.eq('business_id', _selectedBusinessId);
      }

      final response = await query
          .order('scanned_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Actividad Global'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_activities.length} registros',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.black,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Todos (Últimos 100)'),
                          ),
                          DropdownMenuItem(value: 'today', child: Text('Hoy')),
                          DropdownMenuItem(
                            value: 'week',
                            child: Text('Esta Semana'),
                          ),
                          DropdownMenuItem(
                            value: 'month',
                            child: Text('Este Mes'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFilter = value;
                            });
                            _loadActivity();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                // Business Filter
                if (_businessesList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Local:',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBusinessId,
                          icon: const Icon(
                            Icons.store,
                            color: Colors.black,
                            size: 18,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Todos los locales'),
                            ),
                            ..._businessesList.map((b) {
                              return DropdownMenuItem(
                                value: b['id'] as String,
                                child: Text(
                                  b['name'] != null
                                      ? (b['name'].toString().length > 20
                                            ? '${b['name'].toString().substring(0, 20)}...'
                                            : b['name'])
                                      : 'Desconocido',
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedBusinessId = value;
                              });
                              _loadActivity();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
                    ),
                  )
                : _activities.isEmpty
                ? const Center(child: Text('No hay actividad en este período'))
                : RefreshIndicator(
                    onRefresh: _loadActivity,
                    color: Colors.black,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        final profile = activity['profiles'] ?? {};
                        final business = activity['businesses'] ?? {};

                        final userName =
                            profile['full_name'] ??
                            profile['email'] ??
                            'Usuario Desconocido';
                        final businessName =
                            business['name'] ?? 'Negocio Desconocido';

                        final dateStr = activity['scanned_at'] != null
                            ? EcuadorDateUtils.formatEcuadorTime(
                                activity['scanned_at'],
                              )
                            : 'Fecha desconocida';

                        final status = activity['status'] ?? 'pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accentPink.withOpacity(0.1),
                              child: const Icon(
                                Icons.history,
                                color: AppTheme.accentPink,
                              ),
                            ),
                            title: Text(
                              '$userName escaneó QR',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'En: $businessName',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'approved'
                                    ? AppTheme.accentGreen.withValues(alpha: 0.1)
                                    : (status == 'rejected'
                                          ? const Color(
                                              0xFFF44336,
                                            ).withValues(alpha: 0.1)
                                          : const Color(
                                              0xFFFFA000,
                                            ).withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status == 'approved'
                                    ? 'Aprobado'
                                    : (status == 'rejected'
                                          ? 'Rechazado'
                                          : 'Pendiente'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'approved'
                                      ? AppTheme.accentGreen
                                      : (status == 'rejected'
                                            ? const Color(0xFFF44336)
                                            : const Color(0xFFFFA000)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/export_service.dart';
import 'widgets/export_preview_dialog.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _selectedFilter = 'all';
  String _selectedRoleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('profiles').select('''
            id,
            full_name,
            email,
            phone,
            role,
            created_at
          ''');

      // Filter logic
      final now = EcuadorDateUtils.nowEcuador();
      if (_selectedFilter == 'today') {
        final startOfDay = DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String();
        query = query.gte('created_at', startOfDay);
      } else if (_selectedFilter == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        ).toUtc().toIso8601String();
        query = query.gte('created_at', startOfWeekDay);
      } else if (_selectedFilter == 'month') {
        final startOfMonth = DateTime(
          now.year,
          now.month,
          1,
        ).toUtc().toIso8601String();
        query = query.gte('created_at', startOfMonth);
      }

      if (_selectedRoleFilter != 'all') {
        query = query.eq('role', _selectedRoleFilter);
      } else {
        // En "Todos", excluimos al admin para no mezclar clientes con dueños del sistema
        query = query.neq('role', 'admin');
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleLabel(String? role) {
    if (role == 'admin') return 'Administrador';
    if (role == 'business') return 'Negocio';
    return 'Cliente';
  }

  Color _getRoleColor(String? role) {
    if (role == 'admin') return AppTheme.accentPink;
    if (role == 'business') return AppTheme.accentPurple;
    return AppTheme.accentYellow;
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportPreviewDialog(
        data: _users,
        entity: ExportEntity.users,
        exportService: SupabaseExportService(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Usuarios Registrados'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExportDialog,
        icon: const Icon(Icons.download),
        label: const Text('Exportar'),
        backgroundColor: AppTheme.accentPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_users.length} usuarios',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        icon: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        alignment: Alignment.centerRight,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'Todos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'business',
                            child: Text(
                              'Negocios',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'client',
                            child: Text(
                              'Clientes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRoleFilter = value;
                            });
                            _loadUsers();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            child: Text(
                              'Todas',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'today',
                            child: Text(
                              'Hoy',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'week',
                            child: Text(
                              'Esta Sem',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'month',
                            child: Text(
                              'Este Mes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFilter = value;
                            });
                            _loadUsers();
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
                : _users.isEmpty
                ? const Center(
                    child: Text('No se encontraron usuarios en este período'),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    color: Colors.black,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final role = user['role'] as String?;
                        final roleColor = _getRoleColor(role);

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
                                  backgroundColor: roleColor.withOpacity(0.1),
                                  child: Icon(
                                    role == 'business'
                                        ? Icons.store
                                        : (role == 'admin'
                                              ? Icons.security
                                              : Icons.person),
                                    color: roleColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user['full_name'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getRoleLabel(role),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      user['email'] ?? 'Sin correo',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (user['phone'] != null)
                                      Text(
                                        'Tel: ${user['phone']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Registro: ${EcuadorDateUtils.formatEcuadorTime(user['created_at'] ?? '')}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
        ],
      ),
    );
  }
}

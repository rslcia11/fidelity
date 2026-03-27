import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/export_service.dart';
import 'widgets/export_preview_dialog.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _businesses = [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('businesses')
          .select('''
            id,
            name,
            category_id,
            business_categories(name),
            logo_url,
            is_active,
            created_at,
            owner_id,
            profiles:owner_id (full_name, email),
            loyalty_cards (
              profiles:user_id (full_name, email)
            )
          ''')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _businesses = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar negocios: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBusinessStatus(String id, bool currentStatus) async {
    try {
      await supabase
          .from('businesses')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _loadBusinesses();
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportPreviewDialog(
        data: _businesses,
        entity: ExportEntity.businesses,
        exportService: SupabaseExportService(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Negocios Registrados'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExportDialog,
        icon: const Icon(Icons.download),
        label: const Text('Exportar'),
        backgroundColor: AppTheme.accentPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            )
          : _businesses.isEmpty
          ? const Center(child: Text('No hay negocios registrados'))
          : RefreshIndicator(
              onRefresh: _loadBusinesses,
              color: Colors.black,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _businesses.length,
                itemBuilder: (context, index) {
                  final business = _businesses[index];
                  final owner = business['profiles'] ?? {};
                  final ownerName = owner['full_name'] ?? 'Desconocido';
                  final ownerEmail = owner['email'] ?? 'Sin correo';
                  final isActive = business['is_active'] ?? false;

                  final clientsList = List<Map<String, dynamic>>.from(
                    business['loyalty_cards'] ?? [],
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    color: Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.black.withOpacity(0.05),
                            backgroundImage: business['logo_url'] != null
                                ? NetworkImage(business['logo_url'])
                                : null,
                            child: business['logo_url'] == null
                                ? const Icon(Icons.store, color: Colors.black)
                                : null,
                          ),
                          title: Text(
                            business['name'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Categoría: ${business['business_categories']?['name'] ?? business['category'] ?? 'Otra'}',
                              ),
                              Text(
                                'Dueño: $ownerName ($ownerEmail)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            onChanged: (val) =>
                                _toggleBusinessStatus(business['id'], isActive),
                            activeColor: AppTheme.accentGreen,
                          ),
                        ),
                        if (clientsList.isNotEmpty)
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              title: Text(
                                '${clientsList.length} Clientes Activos',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: clientsList.map((clientData) {
                                        final p = clientData['profiles'] ?? {};
                                        final clientName =
                                            p['full_name'] ??
                                            p['email'] ??
                                            'Desconocido';
                                        return Chip(
                                          avatar: CircleAvatar(
                                            backgroundColor: Colors.black
                                                .withOpacity(0.04),
                                            child: Text(
                                              clientName[0].toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          label: Text(
                                            clientName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          backgroundColor: Colors.black
                                              .withOpacity(0.04),
                                          side: BorderSide.none,
                                          padding: EdgeInsets.zero,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              bottom: 16,
                              top: 4,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Aún no tiene clientes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

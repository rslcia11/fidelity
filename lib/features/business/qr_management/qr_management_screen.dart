// lib/features/business/qr_management/qr_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QRManagementScreen extends StatefulWidget {
  final String businessId;
  const QRManagementScreen({super.key, required this.businessId});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
  }

  Future<void> _loadQRCodes() async {
    final response = await supabase
        .from('qr_codes')
        .select()
        .eq('business_id', widget.businessId)
        .order('created_at', ascending: false);

    setState(() {
      _qrCodes = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  Future<void> _generateQRCode() async {
    // TODO: Generar nuevo QR
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _qrCodes.length,
              itemBuilder: (context, index) {
                final qr = _qrCodes[index];
                return Card(
                  child: ListTile(
                    title: Text(qr['label'] ?? 'QR sin nombre'),
                    subtitle: Text('Creado: ${qr['created_at']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {},
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateQRCode,
        backgroundColor: const Color(0xFF8B6F47),
        child: const Icon(Icons.add),
      ),
    );
  }
}
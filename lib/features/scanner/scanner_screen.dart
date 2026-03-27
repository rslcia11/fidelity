import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final supabase = Supabase.instance.client;
  bool isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  Future<void> _validateScan(String qrCode) async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final qrResponse = await supabase
          .from('qr_codes')
          .select('id, business_id, is_active, businesses(name, reward_description, points_required, cooldown_hours)')
          .eq('qr_code', qrCode)
          .single();

      if (qrResponse == null) throw Exception('Código QR no encontrado');

      final qrData = qrResponse;
      if (qrData['is_active'] != true) throw Exception('Este código QR está inactivo');

      final business = qrData['businesses'];
      final businessId = qrData['business_id'];
      final cooldownHours = business['cooldown_hours'] as int? ?? 4;

      // Ya no hacemos el pre-chequeo manual por cliente (redundante con el Trigger)
      // La base de datos ahora lanzará un error COOLDOWN_ACTIVE si se intenta violar la regla


      Map<String, dynamic> loyaltyCard;
      final cardResponse = await supabase
          .from('loyalty_cards')
          .select()
          .eq('user_id', user.id)
          .eq('business_id', businessId)
          .maybeSingle();

      if (cardResponse == null) {
        loyaltyCard = await supabase
            .from('loyalty_cards')
            .insert({
              'user_id': user.id,
              'business_id': businessId,
              'current_points': 0,
              'total_points_lifetime': 0,
              'rewards_claimed': 0,
            })
            .select()
            .single();
      } else {
        loyaltyCard = cardResponse;
      }

      await supabase.from('scans').insert({
        'user_id': user.id,
        'business_id': businessId,
        'loyalty_card_id': loyaltyCard['id'],
        'qr_code_id': qrData['id'],
        'scanned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      if (mounted) {
        _showSuccessDialog(business['name']);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.message.contains('COOLDOWN_ACTIVE')) {
          final parts = e.message.split(':');
          final hours = parts.length > 1 ? parts[1] : '4';
          _showCooldownDialog(
            businessName: '¡ESPERA!',
            message: 'Este local tiene una restricción de $hours horas entre escaneos.',
          );
        } else {
          _showErrorDialog('Error de base de datos: ${e.message}');
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Error inesperado: $e';
        if (e.toString().contains('single row')) {
          msg = 'QR no válido';
        }
        _showErrorDialog(msg);
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(String businessName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('⏱️ PENDIENTE', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty, size: 48, color: AppTheme.accentYellow),
            ),
            const SizedBox(height: 24),
            Text(
              businessName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Escaneo registrado. Espera a que el local lo apruebe para recibir tu punto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black45),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                cameraController.start();
              },
              child: const Text('ENTENDIDO'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCooldownDialog({required String businessName, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('⏳ ESPERA', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, size: 48, color: AppTheme.accentPurple),
            ),
            const SizedBox(height: 24),
            Text(
              message.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '¡Pero puedes escanear en otros locales ahora mismo!',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                cameraController.start();
              },
              child: const Text('VALE'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        title: const Text('ERROR', textAlign: TextAlign.center),
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                cameraController.start();
              },
              child: const Text('REINTENTAR'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ESCANEAR QR'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !isProcessing) {
                  cameraController.stop();
                  _validateScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Custom Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(48),
              ),
            ),
          ),

          if (!isProcessing)
            Positioned(
              bottom: 60,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Column(
                  children: [
                    const Text(
                      'APUNTA AL CÓDIGO QR',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Asegúrate de que el código esté dentro del recuadro.',
                      style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().slideY(begin: 1, curve: Curves.easeOutBack, duration: 600.ms),
            ),

          if (isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    const Text(
                      'VALIDANDO...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ).animate(onPlay: (controller) => controller.repeat()).fadeIn().fadeOut(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


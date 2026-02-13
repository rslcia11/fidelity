import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase.functions.invoke(
        'validate-scan',
        body: {
          'qr_code': qrCode,
          'user_id': userId,
        },
      );

      final data = response.data;

      if (mounted) {
        if (data['success'] == true) {
          _showSuccessDialog(
            businessName: data['business_name'],
            currentPoints: data['current_points'],
            pointsRequired: data['points_required'],
            rewardCompleted: data['reward_completed'],
            rewardDescription: data['reward_description'],
            message: data['message'],
          );
        } else {
          if (data['error'] == 'cooldown') {
            _showCooldownDialog(
              businessName: data['business_name'],
              message: data['message'],
            );
          } else {
            _showErrorDialog(data['error'] ?? 'Error desconocido');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error de conexión: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  void _showSuccessDialog({
    required String businessName,
    required int currentPoints,
    required int pointsRequired,
    required bool rewardCompleted,
    required String rewardDescription,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          rewardCompleted ? '🎉 ¡Premio Ganado!' : '✓ Punto Agregado',
          style: const TextStyle(color: Color(0xFF8B6F47)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              businessName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            if (rewardCompleted) ...[
              const Text(
                '¡Felicidades! Ganaste:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                rewardDescription,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B8E23),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Muestra esta pantalla al cajero para canjear',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF6B5D4F)),
              ),
            ] else ...[
              LinearProgressIndicator(
                value: currentPoints / pointsRequired,
                backgroundColor: const Color(0xFFD4A574).withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF8B6F47)),
              ),
              const SizedBox(height: 12),
              Text(
                '$currentPoints de $pointsRequired puntos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cameraController.start();
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showCooldownDialog({
    required String businessName,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏳ Espera un momento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time,
              size: 48,
              color: Color(0xFFD4A574),
            ),
            const SizedBox(height: 16),
            Text(
              'Ya escaneaste en $businessName recientemente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B6F47),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Pero puedes escanear en otros locales ahora mismo!',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B5D4F)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cameraController.start();
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cameraController.start();
            },
            child: const Text('OK'),
          ),
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
      appBar: AppBar(
        title: const Text('Escanear QR'),
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
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !isProcessing) {
                  cameraController.stop();
                  _validateScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          
          // Overlay con instrucciones
          if (!isProcessing)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFF8).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Apunta la cámara al código QR del local',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2416),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // Loading overlay
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8B6F47)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
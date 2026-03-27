import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  String? _avatarUrl;
  XFile? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase.from('profiles').select().eq('id', userId).single();
      
      if (mounted) {
        setState(() {
          _fullNameController.text = profile['full_name'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
          _avatarUrl = profile['avatar_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _newAvatarFile = image);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      String? finalAvatarUrl = _avatarUrl;
      if (_newAvatarFile != null) {
        final fileBytes = await _newAvatarFile!.readAsBytes();
        final fileExt = _newAvatarFile!.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final imagePath = '$userId/$fileName';

        await supabase.storage.from('avatars').uploadBinary(
          imagePath,
          fileBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(imagePath);
      }

      await supabase.from('profiles').update({
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatar_url': finalAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Perfil actualizado'), backgroundColor: AppTheme.accentGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentPink),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: const Text('¿ELIMINAR MI CUENTA?', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta acción es irreversible y cumplimos con borrar todos tus datos personales.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const Text('Escribe "ELIMINAR" para confirmar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () {
                if (confirmController.text.trim().toUpperCase() == 'ELIMINAR') Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPink),
              child: const Text('ELIMINAR DEFINITIVAMENTE'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await supabase.functions.invoke(
        'hyper-action',
        headers: {'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}'},
      );
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentPink),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MI PERFIL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveChanges,
            icon: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.04),
                                image: _newAvatarFile != null
                                    ? DecorationImage(image: FileImage(File(_newAvatarFile!.path)), fit: BoxFit.cover)
                                    : (_avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null),
                              ),
                              child: (_avatarUrl == null && _newAvatarFile == null)
                                  ? const Icon(Icons.person_outline, size: 50, color: Colors.black26)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildField(_fullNameController, 'NOMBRE COMPLETO', Icons.person_outline),
                    const SizedBox(height: 24),
                    _buildField(_phoneController, 'TELÉFONO', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                    const SizedBox(height: 64),
                    TextButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.black26),
                      label: const Text(
                        'ELIMINAR MI CUENTA',
                        style: TextStyle(color: Colors.black26, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.black26),
            filled: true,
            fillColor: Colors.black.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}

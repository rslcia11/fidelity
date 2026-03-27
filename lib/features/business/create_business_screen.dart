import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dashboard/business_dashboard_screen.dart';
import 'widgets/business_creation/step_logo_picker.dart';
import 'widgets/business_creation/step_personal_data.dart';
import 'widgets/business_creation/step_business_data.dart';
import 'widgets/business_creation/step_campaign_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/business_category.dart';
import '../auth/login_screen.dart';

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final supabase = Supabase.instance.client;
  int _currentStep = 0;
  bool _isLoading = false;

  // Form keys for steps
  final _personalFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();
  final _campaignFormKey = GlobalKey<FormState>();

  // Controllers & Data
  XFile? _logoFile;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  BusinessCategory? _selectedCategory;
  List<BusinessCategory> _categories = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';

  final _rewardDescriptionController = TextEditingController();
  final _pointsRequiredController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _loadExistingProfileData();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('business_categories')
          .select('id, name')
          .order('name');
      
      if (mounted) {
        setState(() {
          _categories = (response as List)
              .map((c) => BusinessCategory.fromJson(c))
              .toList();
          
          if (_categories.isNotEmpty) {
            // Default select first or look for a specific one
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadExistingProfileData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _fullNameController.text = profile['full_name'] ?? '';
            _phoneController.text = profile['phone'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _rewardDescriptionController.dispose();
    _pointsRequiredController.dispose();
    super.dispose();
  }

  void _nextStep() {
    bool canContinue = false;

    if (_currentStep == 0) {
      // Logo step - Optional
      canContinue = true;
    } else if (_currentStep == 1) {
      if (_personalFormKey.currentState!.validate()) canContinue = true;
    } else if (_currentStep == 2) {
      if (_businessFormKey.currentState!.validate()) {
        if (_selectedLatitude == null || _selectedLongitude == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes seleccionar la ubicación en el mapa'),
              backgroundColor: AppTheme.accentPink,
            ),
          );
        } else {
          canContinue = true;
        }
      }
    } else if (_currentStep == 3) {
      if (_campaignFormKey.currentState!.validate()) {
        _createBusiness(); // Final step
        return;
      }
    }

    if (canContinue && _currentStep < 3) {
      setState(() => _currentStep += 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _createBusiness() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // 1. Update Profile (Personal Data)
      await supabase
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
          })
          .eq('id', userId);

      // 2. Upload Logo if exists
      String? logoUrl;
      if (_logoFile != null) {
        try {
          final fileBytes = await _logoFile!.readAsBytes();
          final fileExt = _logoFile!.name.split('.').last.toLowerCase();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final imagePath = '$userId/$fileName';

          String mimeType = 'image/jpeg';
          if (fileExt == 'png')
            mimeType = 'image/png';
          else if (fileExt == 'webp')
            mimeType = 'image/webp';
          else if (fileExt == 'gif')
            mimeType = 'image/gif';

          await supabase.storage
              .from('business-logos')
              .uploadBinary(
                imagePath,
                fileBytes,
                fileOptions: FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                  contentType: mimeType,
                ),
              );

          logoUrl = supabase.storage
              .from('business-logos')
              .getPublicUrl(imagePath);
        } catch (e) {
          debugPrint('Error uploading logo: $e');
        }
      }

      // 3. Create Business
      final pointsText = _pointsRequiredController.text.trim();
      final pointsRequired = int.tryParse(pointsText) ?? 10;
      final businessResponse = await supabase
          .from('businesses')
          .insert({
            'owner_id': userId,
            'name': _businessNameController.text.trim(),
            'description': _businessDescriptionController.text.trim().isEmpty
                ? null
                : _businessDescriptionController.text.trim(),
            'logo_url': logoUrl,
            'address': _selectedAddress.isEmpty ? null : _selectedAddress,
            'latitude': _selectedLatitude,
            'longitude': _selectedLongitude,
            'category_id': _selectedCategory?.id,
            'category': _selectedCategory?.name, // Keep as fallback for now
            'reward_description': _rewardDescriptionController.text.trim(),
            'points_required': pointsRequired,
            'cooldown_hours': 4,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final businessId = businessResponse['id'];

      // 4. Generate Initial QR Code
      final newQrCode = const Uuid().v4();
      await supabase.from('qr_codes').insert({
        'business_id': businessId,
        'qr_code': newQrCode,
        'label': 'QR Principal',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 5. Update Auth Metadata
      await supabase.auth.updateUser(
        UserAttributes(data: {'role': 'business', 'business_id': businessId}),
      );

      if (mounted) {
        _showSuccessToast();
        Future.delayed(1500.ms, () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear negocio: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(milliseconds: 2500),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¡NEGOCIO CONFIGURADO CON ÉXITO!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configurar Negocio'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, // Prevent going back if mandatory
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            )
          : Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: _previousStep,
              physics: const ScrollPhysics(),
              controlsBuilder: (context, details) {
                final isLastStep = _currentStep == 3;
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLastStep ? 'Finalizar y Crear' : 'Siguiente',
                          ),
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                          ),
                          child: const Text('Atrás'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Logo / Foto'),
                  subtitle: const Text('Imagen principal (Opcional)'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepLogoPicker(
                    initialImage: _logoFile,
                    onImageSelected: (file) => setState(() => _logoFile = file),
                  ),
                ),
                Step(
                  title: const Text('Datos Personales'),
                  subtitle: const Text('Información de contacto'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepPersonalData(
                    formKey: _personalFormKey,
                    fullNameController: _fullNameController,
                    phoneController: _phoneController,
                  ),
                ),
                Step(
                  title: const Text('Datos del Negocio'),
                  subtitle: const Text('Nombre, categoría y ubicación'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepBusinessData(
                    formKey: _businessFormKey,
                    nameController: _businessNameController,
                    descriptionController: _businessDescriptionController,
                    selectedCategory: _selectedCategory,
                    categories: _categories,
                    onCategoryChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                    latitude: _selectedLatitude,
                    longitude: _selectedLongitude,
                    address: _selectedAddress,
                    onLocationSelected: (lat, lng, address) {
                      setState(() {
                        _selectedLatitude = lat;
                        _selectedLongitude = lng;
                        _selectedAddress = address;
                      });
                    },
                  ),
                ),
                Step(
                  title: const Text('Datos de Campaña'),
                  subtitle: const Text('Premio principal y puntos'),
                  isActive: _currentStep >= 3,
                  state: _currentStep == 3
                      ? StepState.editing
                      : StepState.indexed,
                  content: StepCampaignData(
                    formKey: _campaignFormKey,
                    rewardController: _rewardDescriptionController,
                    pointsController: _pointsRequiredController,
                  ),
                ),
              ],
            ),
    );
  }
}

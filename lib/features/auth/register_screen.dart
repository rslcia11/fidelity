// lib/features/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedRole = 'client'; // 'client' o 'business_owner'
  
  // Controladores para todos los campos
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Campos específicos para business
  final _businessNameController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _rewardDescriptionController = TextEditingController();
  final _pointsRequiredController = TextEditingController(text: '10');
  final _addressController = TextEditingController();
  
  String _selectedCategory = 'cafe';
  final List<String> _categories = [
    'cafe', 'restaurant', 'bakery', 'gym', 'salon', 
    'spa', 'retail', 'grocery', 'pharmacy', 'laundry', 
    'car_wash', 'other'
  ];

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _rewardDescriptionController.dispose();
    _pointsRequiredController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. CREAR USUARIO EN AUTH
      final metadata = {
        'role': _selectedRole,
      };

      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: metadata, // raw_user_meta_data
      );

      if (authResponse.user == null) throw Exception('Error al crear usuario');

      final userId = authResponse.user!.id;

      // 2. CREAR PERFIL EN public.profiles
      await supabase.from('profiles').insert({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. SI ES BUSINESS OWNER - CREAR NEGOCIO
      String? businessId;
      if (_selectedRole == 'business_owner') {
        final pointsRequired = int.tryParse(_pointsRequiredController.text) ?? 10;
        
        final businessResponse = await supabase.from('businesses').insert({
          'owner_id': userId,
          'name': _businessNameController.text.trim(),
          'description': _businessDescriptionController.text.trim().isEmpty
              ? null
              : _businessDescriptionController.text.trim(),
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'category': _selectedCategory,
          'reward_description': _rewardDescriptionController.text.trim(),
          'points_required': pointsRequired,
          'cooldown_hours': 4, // valor por defecto
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select('id').single();

        businessId = businessResponse['id'] as String;

        // 4. ACTUALIZAR METADATA DEL USUARIO CON BUSINESS ID
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'role': 'business_owner',
              'business_id': businessId,
            },
          ),
        );
      }

      if (mounted) {
        // MOSTRAR ÉXITO
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRole == 'business_owner'
                  ? '✅ Negocio registrado exitosamente'
                  : '✅ Cuenta creada exitosamente',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // IR A LOGIN
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: const Color(0xFFB85C50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFB85C50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2C2416),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LOGO
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6F47).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 48,
                      color: Color(0xFF8B6F47),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // TÍTULO
                const Text(
                  'Únete a Fidelity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2416),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu cuenta y empieza a disfrutar',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B5D4F).withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // SELECTOR DE ROL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F1E8).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B6F47).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de cuenta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C2416),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'Cliente',
                              icon: Icons.person,
                              description: 'Acumula puntos y canjea premios',
                              isSelected: _selectedRole == 'client',
                              onTap: () {
                                setState(() => _selectedRole = 'client');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'Negocio',
                              icon: Icons.store,
                              description: 'Registra tu local y fideliza clientes',
                              isSelected: _selectedRole == 'business_owner',
                              onTap: () {
                                setState(() => _selectedRole = 'business_owner');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // === CAMPOS COMUNES ===
                const Text(
                  'Datos personales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2416),
                  ),
                ),
                const SizedBox(height: 16),

                // Nombre completo
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF8B6F47)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B6F47), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu nombre completo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8B6F47)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B6F47), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Teléfono (opcional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF8B6F47)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8B6F47)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B6F47), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmar password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8B6F47)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma tu contraseña';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // === CAMPOS ESPECÍFICOS PARA BUSINESS ===
                if (_selectedRole == 'business_owner') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6F47).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B6F47).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, color: const Color(0xFF8B6F47), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Información del negocio',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C2416),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Nombre del negocio
                        TextFormField(
                          controller: _businessNameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del negocio',
                            prefixIcon: const Icon(Icons.storefront_outlined, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa el nombre del negocio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Categoría
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category[0].toUpperCase() + category.substring(1)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCategory = value!);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Descripción del negocio (opcional)
                        TextFormField(
                          controller: _businessDescriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Descripción (opcional)',
                            prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dirección (opcional)
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Dirección (opcional)',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Descripción del premio
                        TextFormField(
                          controller: _rewardDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción del premio',
                            prefixIcon: const Icon(Icons.card_giftcard, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Describe el premio que ofrecerás';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Puntos requeridos
                        TextFormField(
                          controller: _pointsRequiredController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Puntos requeridos para premio',
                            prefixIcon: const Icon(Icons.star_outline, color: Color(0xFF8B6F47)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa los puntos requeridos';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // BOTÓN DE REGISTRO
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B6F47),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _selectedRole == 'business_owner'
                              ? 'Registrar negocio'
                              : 'Crear cuenta',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // LINK A LOGIN
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B6F47),
                  ),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// WIDGET PARA SELECCIONAR ROL
class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B6F47).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B6F47)
                : const Color(0xFF8B6F47).withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF8B6F47)
                  : const Color(0xFF6B5D4F),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF8B6F47)
                    : const Color(0xFF2C2416),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? const Color(0xFF8B6F47).withOpacity(0.8)
                    : const Color(0xFF6B5D4F),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
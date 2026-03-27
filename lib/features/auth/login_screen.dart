import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'register_screen.dart';
import 'auth_wrapper.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icono
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: AppTheme.accentPurple.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.card_membership_rounded, size: 80, color: AppTheme.accentPurple),
                  ).animate().scale(duration: AppTheme.animDurationSlow, curve: AppTheme.animCurveElastic).fadeIn(),
                  
                  const SizedBox(height: 48),

                  // Título principal
                  const Text(
                    'BIENVENIDO A\nFIDELITY',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: 2, height: 1.1),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: AppTheme.animDurationSlow).slideY(begin: AppTheme.animSlideYBegin, curve: AppTheme.animCurveStandard),
                  
                  const SizedBox(height: 16),
                  
                  

                  const SizedBox(height: 48),

                  // Formulario
                  Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Tu email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) => 
                          (value == null || value.isEmpty) ? 'Ingresa tu email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Tu contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        validator: (value) => 
                          (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
                      ),
                    ],
                  )
                  .animate()
                  .slideY(begin: 0.15, duration: AppTheme.animDurationSlow, curve: AppTheme.animCurveStandard, delay: 200.ms)
                  .fadeIn(delay: 200.ms),

                  const SizedBox(height: 48),

                  // Botón Login (Estilo Emote)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            )
                          : const Text('Iniciar Sesión'),
                    ),
                  )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack, delay: 500.ms)
                  .fadeIn(delay: 500.ms),

                  const SizedBox(height: 24),

                  // Registro
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  )
                  .animate()
                  .fadeIn(delay: 600.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

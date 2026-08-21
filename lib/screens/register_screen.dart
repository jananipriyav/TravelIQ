import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_messages.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = response.user?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Hero header ----
            Container(
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create your account',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start planning smarter trips in minutes.',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ---- Form ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline, color: primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, color: primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Register'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Already have an account? Login'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.explore, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Log in to plan your next trip across the city.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ---- Form card ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/forgot-password'),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/register'),
                      child: const Text("Don't have an account? Register"),
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
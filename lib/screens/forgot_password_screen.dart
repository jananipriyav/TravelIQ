import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_messages.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _sendCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A 6-digit code has been sent to your email.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.trim().isEmpty || _newPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter the code and a new password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Verifying the OTP logs the user into a temporary recovery session.
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
        type: OtpType.recovery,
      );

      // Now that we're in a valid session, actually set the new password.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Sign out so the user logs back in fresh with their new password —
      // avoids any confusion about whether they're "still logged in."
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Please log in with your new password.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
        _isLoading = false;
      });
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
                        Text(
                          _codeSent ? 'Enter Your Code' : 'Reset Password',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _codeSent
                              ? 'Check your email for a verification code.'
                              : 'We\'ll send a code to reset your password.',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, color: primary),
                    ),
                  ),

                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: Icon(Icons.pin_outlined, color: primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
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
                  ],

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
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _isLoading ? null : (_codeSent ? _resetPassword : _sendCode),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(_codeSent ? 'Reset Password' : 'Send Code'),
                  ),

                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _sendCode,
                        child: const Text('Resend Code'),
                      ),
                    ),
                  ],
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
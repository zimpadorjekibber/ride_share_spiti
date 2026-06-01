import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../main.dart';

/// First-time registration + OTP verification.
///
/// PHONE uses **real Firebase Phone Auth** (SMS OTP) when Firebase is reachable
/// and the Phone provider is configured. If that fails (offline, provider not
/// enabled, no SHA key) it gracefully falls back to a *simulated* OTP shown on
/// screen — so the user is never locked out.
///
/// EMAIL stays a simulated 6-digit OTP (Firebase has no native email OTP).
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _emailOtpController = TextEditingController();

  bool _otpSent = false;
  bool _submitting = false;
  bool _sendingOtp = false;
  String _phoneCode = '';
  String _emailCode = '';
  String? _error;

  // Real Firebase phone auth state
  bool _realPhone = false; // true when an SMS OTP was actually sent
  String? _verificationId;
  String? _otpFailReason; // why real OTP fell back to demo (for diagnostics)

  static const Color _indigo = Color(0xFF6366F1);
  static const Color _teal = Color(0xFF14B8A6);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _phoneOtpController.dispose();
    _emailOtpController.dispose();
    super.dispose();
  }

  String _gen6() => (100000 + Random().nextInt(900000)).toString();

  /// Normalise the typed number to E.164 (assumes India +91 if no country code).
  String _e164Phone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    return '+$digits';
  }

  void _startSimulated([String? reason]) {
    setState(() {
      _realPhone = false;
      _otpFailReason = reason;
      _phoneCode = _gen6();
      _otpSent = true;
      _sendingOtp = false;
      _error = null;
    });
  }

  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    HapticFeedback.lightImpact();
    _emailCode = _gen6(); // email OTP is always simulated

    if (!FirebaseService.isInitialized) {
      _startSimulated('firebase-not-ready');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164Phone(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) {
          // Android auto-retrieval; user can still type the code manually.
        },
        verificationFailed: (FirebaseAuthException e) {
          // Provider not enabled / no SHA / quota / offline → simulated fallback.
          if (mounted) _startSimulated('${e.code} — ${e.message ?? ''}');
        },
        codeSent: (String verId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verId;
              _realPhone = true;
              _otpSent = true;
              _sendingOtp = false;
              _error = null;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verId) {
          _verificationId = verId;
        },
      );
    } catch (e) {
      if (mounted) _startSimulated('exception: $e');
    }
  }

  Future<void> _verify() async {
    // Email OTP (simulated) check
    if (_emailOtpController.text.trim() != _emailCode) {
      setState(() => _error = 'Email OTP is incorrect.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Phone OTP check — real (Firebase) or simulated fallback
    if (_realPhone) {
      try {
        final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _phoneOtpController.text.trim(),
        );
        await FirebaseAuth.instance.signInWithCredential(cred);
      } catch (_) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = 'Phone OTP is incorrect.';
          });
        }
        return;
      }
    } else {
      if (_phoneOtpController.text.trim() != _phoneCode) {
        setState(() {
          _submitting = false;
          _error = 'Phone OTP is incorrect.';
        });
        return;
      }
    }

    final profile = await LocalStorageService.getProfile();
    profile.name = _nameController.text.trim();
    profile.phone = _phoneController.text.trim();
    profile.email = _emailController.text.trim();
    profile.isRegistered = true;
    profile.phoneVerified = true;
    profile.emailVerified = true;
    await LocalStorageService.saveProfile(profile);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainNavigationScreen(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_indigo, _teal]),
                  boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify your identity',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the 6-digit codes we sent to your phone and email.'
                    : 'One-time verification keeps the Spiti community safe — your reviews & rating stay linked to this verified account forever.',
                style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),

              if (!_otpSent) ..._buildDetailsStep() else ..._buildOtpStep(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_submitting || _sendingOtp) ? null : (_otpSent ? _verify : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: (_submitting || _sendingOtp)
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _otpSent ? 'Verify & Continue' : 'Send OTP',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _phoneOtpController.clear();
                      _emailOtpController.clear();
                      _error = null;
                    }),
                    child: const Text('← Change phone / email', style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailsStep() {
    return [
      _field(_nameController, 'Full Name', Icons.person_outline, TextInputType.name),
      const SizedBox(height: 14),
      _field(_phoneController, 'Mobile Number', Icons.phone_outlined, TextInputType.phone),
      const SizedBox(height: 14),
      _field(_emailController, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
    ];
  }

  List<Widget> _buildOtpStep() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (_realPhone ? _indigo : _teal).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (_realPhone ? _indigo : _teal).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_realPhone ? Icons.sms : Icons.info_outline, color: _realPhone ? _indigo : _teal, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _realPhone
                    ? 'Real SMS sent to your phone ✅   •   Email OTP (demo): $_emailCode'
                    : 'Demo mode${_otpFailReason != null ? ' (real OTP: $_otpFailReason)' : ''} — Phone OTP: $_phoneCode   •   Email OTP: $_emailCode',
                style: TextStyle(color: _realPhone ? _indigo : _teal, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text('Sent to ${_phoneController.text.trim()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 6),
      _field(_phoneOtpController, 'Phone OTP (6 digits)', Icons.sms_outlined, TextInputType.number),
      const SizedBox(height: 16),
      Text('Sent to ${_emailController.text.trim()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 6),
      _field(_emailOtpController, 'Email OTP (6 digits)', Icons.mark_email_read_outlined, TextInputType.number),
    ];
  }

  Widget _field(TextEditingController controller, String label, IconData icon, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: _indigo, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _indigo, width: 1.5),
        ),
      ),
    );
  }
}

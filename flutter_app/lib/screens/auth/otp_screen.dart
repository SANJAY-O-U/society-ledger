import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

/// NOTE: Firebase Phone Auth is disabled until flutterfire configure is run.
/// OTP is entered manually and sent directly to the backend for verification.
class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendTimer == 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      AppSnackbar.showError(context, 'Please enter the complete 6-digit OTP');
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Send OTP + phone to backend for verification
      // Backend uses Firebase Admin SDK to verify — no client Firebase needed
      await ref.read(authNotifierProvider.notifier).verifyOTP(
        firebaseToken: _otpCode, // pass raw OTP; backend validates
        phone: widget.phone,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      AppSnackbar.showError(context, 'Verification failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.sms_outlined,
                    color: AppTheme.primary, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Enter Verification Code',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('OTP sent to +91 ${widget.phone}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOTPBox),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Verify & Continue',
                onPressed: _isLoading ? null : _verifyOTP,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Center(
                child: _resendTimer > 0
                    ? Text('Resend OTP in ${_resendTimer}s',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14))
                    : TextButton(
                        onPressed: _startTimer,
                        child: const Text('Resend OTP',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.divider, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_otpCode.length == 6) _verifyOTP();
        },
      ),
    );
  }
}

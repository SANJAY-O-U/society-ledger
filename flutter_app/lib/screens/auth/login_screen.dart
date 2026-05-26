import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isOTPMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _isOTPMode = _tabController.index == 0));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleOTPLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      context.push('/auth/otp', extra: _phoneController.text.trim());
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ─── Header ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    const Text('Welcome Back', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Sign in to Society Ledger', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                  ],
                ),
              ),

              // ─── Form Card ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        dividerColor: Colors.transparent,
                        tabs: const [Tab(text: 'OTP Login'), Tab(text: 'Password')],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: _isOTPMode ? _buildOTPForm() : _buildPasswordForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            prefixText: '+91  ',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Mobile number is required';
            if (v.length != 10) return 'Enter 10-digit mobile number';
            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Invalid mobile number';
            return null;
          },
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Send OTP',
          onPressed: _isLoading ? null : _handleOTPLogin,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ll send a one-time password to your mobile number',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Invalid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primary)),
          ),
        ),
        AppButton(
          label: 'Sign In',
          onPressed: _isLoading ? null : _handlePasswordLogin,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

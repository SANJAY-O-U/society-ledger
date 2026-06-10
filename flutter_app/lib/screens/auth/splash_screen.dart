import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  _controller.forward();

  // FIX: Use Future.delayed then call async _navigate
  Future.delayed(const Duration(milliseconds: 800), _navigate);
}

// FIX: Async navigate that validates BOTH token AND user data
Future<void> _navigate() async {
  if (!mounted) return;
  
  final isValid = await StorageService.hasValidSession;
  
  if (!mounted) return;
  context.go(isValid ? '/home' : '/auth/login');
}


 @override
void dispose() {
  _controller.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: FadeTransition(
      opacity: _fade,
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.account_balance, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              const Text('Society Ledger',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('Smart Housing Society Management',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const SizedBox(height: 64),
              SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white.withOpacity(0.7), strokeWidth: 2)),
            ],
          ),
        ),
      ),
    ),
  );
}
}

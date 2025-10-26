import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFF8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ENGLIT',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF388E3C),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Учи технический английский легко',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () async {
                await authService.signInWithGoogle();
              },
              icon: Image.asset('assets/google_logo.png', height: 24.0), // Добавьте логотип Google в папку assets
              label: const Text('Войти через Google'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black87, backgroundColor: Colors.white,
                minimumSize: const Size(250, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
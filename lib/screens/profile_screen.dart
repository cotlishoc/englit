import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Импортируем provider
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Получаем текущего пользователя. Теперь у него есть имя, email и фото!
    final user = FirebaseAuth.instance.currentUser;
    // Получаем AuthService из Provider'а для вызова метода signOut
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Личный кабинет'),
        // Добавляем тень под AppBar для лучшего визуального отделения
        elevation: 1,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Выравниваем все элементы по центру
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- АВАТАР ПОЛЬЗОВАТЕЛЯ ---
              // Проверяем, есть ли у пользователя фото в профиле
              if (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                CircleAvatar(
                  radius: 50,
                  // Загружаем изображение из сети
                  backgroundImage: NetworkImage(user.photoURL!),
                  backgroundColor: Colors.grey[200], // Фон на случай долгой загрузки
                )
              else
                // Если фото нет, показываем иконку по умолчанию
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  child: const Icon(Icons.person, size: 60, color: Color(0xFF388E3C)),
                ),
              const SizedBox(height: 20),

              // --- ИМЯ ПОЛЬЗОВАТЕЛЯ ---
              Text(
                // Используем оператор '??' для предоставления значения по умолчанию
                user?.displayName ?? "Пользователь",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Используем более мягкий черный
                ),
              ),
              const SizedBox(height: 8),

              // --- EMAIL ПОЛЬЗОВАТЕЛЯ ---
              Text(
                user?.email ?? "Email не указан",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // --- КНОПКА ВЫХОДА ---
              ElevatedButton.icon(
                onPressed: () async {
                  // Очень важно сначала закрыть текущий экран,
                  // а потом выходить из системы. Это предотвращает ошибки.
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF9A9A), // Мягкий красный цвет
                  foregroundColor: const Color(0xFFC62828), // Темно-красный текст/иконка
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
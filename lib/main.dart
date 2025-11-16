import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // Этот файл генерируется командой flutterfire configure
import 'screens/auth_wrapper.dart'; // Наш новый "диспетчер" экранов
import 'services/auth_service.dart';
import 'state/category_state.dart';
import 'state/theme_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Точка входа в приложение
Future<void> main() async {
  // Убеждаемся, что Flutter готов к работе перед запуском асинхронного кода
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем Firebase для текущей платформы (веб, Android, iOS)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Включаем сохранение данных на устройстве
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  // Запускаем корневой виджет приложения
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<CategoryState>(create: (_) => CategoryState()),
        ChangeNotifierProvider<ThemeState>(create: (_) => ThemeState()),
      ],
      child: Consumer<ThemeState>(
        builder: (context, themeState, child) {
          return MaterialApp(
            title: 'ENGLIT',
            debugShowCheckedModeBanner: false,
            themeMode: themeState.mode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.light),
              scaffoldBackgroundColor: const Color(0xFFF1F8F3),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFE8F5E9),
                surfaceTintColor: Color(0xFFE8F5E9),
                elevation: 0,
                iconTheme: IconThemeData(color: Color(0xFF1B5E20)),
                titleTextStyle: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 22),
              ),
              textTheme: const TextTheme(bodyMedium: TextStyle(color: Color(0xFF1B5E20)), headlineMedium: TextStyle(color: Color(0xFF1B5E20))),
              cardTheme: CardThemeData(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // фиксированное скругление
                elevation: 4,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), // фиксированное скругление
                  elevation: 4,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFEFF7EF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), // фиксированное скругление
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A148C), brightness: Brightness.dark),
              scaffoldBackgroundColor: const Color(0xFF121212),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2A0B2B),
                surfaceTintColor: Color(0xFF2A0B2B),
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
              ),
              textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white), headlineMedium: TextStyle(color: Colors.white)),
              cardTheme: CardThemeData(
                color: const Color(0xFF1B1B1B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // фиксированное скругление
                elevation: 4,
              ),
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
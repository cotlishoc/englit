import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // Этот файл генерируется командой flutterfire configure
import 'screens/auth_wrapper.dart'; // Наш новый "диспетчер" экранов
import 'services/auth_service.dart';
import 'state/category_state.dart';
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
    // MultiProvider позволяет "предоставить" несколько сервисов или состояний
    // всему дереву виджетов под ним.
    return MultiProvider(
      providers: [
        // Предоставляем экземпляр AuthService для управления аутентификацией.
        // Он будет доступен в любом месте приложения через Provider.of<AuthService>(context).
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // ChangeNotifierProvider используется для состояний, которые могут изменяться
        // и уведомлять об этом подписчиков (виджеты).
        ChangeNotifierProvider<CategoryState>(
          create: (_) => CategoryState(),
        ),
      ],
      child: MaterialApp(
        title: 'ENGLIT',
        // Убираем баннер "Debug" в углу экрана
        debugShowCheckedModeBanner: false,
        
        // --- ТЕМА ПРИЛОЖЕНИЯ ---
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // Более глубокий зелёный
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF1F8F3), // Очень светлый фон с зелёной ноткой
          useMaterial3: true,
          
          // Стиль для AppBar (верхняя панель)
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFE8F5E9),
            surfaceTintColor: Color(0xFFE8F5E9),
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF1B5E20)),
            titleTextStyle: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          
          // Основной стиль текста в приложении
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Color(0xFF1B5E20)),
            headlineMedium: TextStyle(color: Color(0xFF1B5E20)),
          ),

          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFEFF7EF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        
        // --- СТАРТОВЫЙ ЭКРАН ---
        // Точкой входа теперь является AuthWrapper.
        // Он проверит, вошел ли пользователь в систему, и покажет
        // либо LoginScreen, либо HomeScreen.
        home: const AuthWrapper(),
      ),
    );
  }
}
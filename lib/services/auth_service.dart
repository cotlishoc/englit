import 'package:flutter/foundation.dart' show kIsWeb; // Для определения платформы
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Поток для отслеживания состояния входа (вошел пользователь или нет)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Вход с помощью Google
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Начинаем процесс входа
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        // Для веба используем всплывающее окно
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Для мобильных устройств
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        // Пользователь отменил вход
        return null;
      }

      // 2. Получаем данные аутентификации для Firebase
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Входим в Firebase с полученными данными
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // 4. Сохраняем/обновляем данные пользователя в Firestore
      if (user != null) {
        final DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);
        
        await userDocRef.set({
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // merge:true чтобы не затереть другие данные
      }

      return user;
    } catch (e) {
      print("Ошибка входа с Google: $e");
      return null;
    }
  }

  // Выход из системы
  Future<void> signOut() async {
    await _googleSignIn.signOut(); // Выходим из аккаунта Google
    await _auth.signOut();      // Выходим из Firebase
  }
}
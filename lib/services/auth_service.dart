import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final DocumentReference userDocRef = _firestore.collection('users').doc(user.uid);
        final docSnapshot = await userDocRef.get();

        // --- ИЗМЕНЕНИЕ: Создаем профиль статистики и настроек, если пользователь новый ---
        if (!docSnapshot.exists) {
          // Пользователь заходит впервые, создаем для него полную структуру
          await userDocRef.set({
            'displayName': user.displayName,
            'email': user.email,
            'photoURL': user.photoURL,
            'lastLogin': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            // Поля из ТЗ
            'settings': {
              'soundEnabled': true,
            },
            'stats': {
              'totalLearnedWords': 0,
              'repetitionsCount': 0,
              'progressByTheme': {}, // e.g. {'software_id': 40, 'hardware_id': 25}
            }
          });
        } else {
          // Пользователь уже существует, просто обновляем дату входа
          await userDocRef.update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print("Ошибка входа с Google: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
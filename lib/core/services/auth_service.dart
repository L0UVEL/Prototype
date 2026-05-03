import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../env/env.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isInitialized = false;

  AuthService() {
    _initAuth();
  }

  bool get isInitialized => _isInitialized;

  Future<void> _initAuth() async {
    // Ensure roles table exists
    _ensureRolesExist();

    // Listen to Firebase Auth state changes
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Fetch extended user profile from Firestore
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data()!;
            final fullName = data['name'] ?? firebaseUser.displayName ?? 'Unknown';
            final nameParts = fullName.split(' ');
            final fName = data['firstName'] ?? (nameParts.isNotEmpty ? nameParts.first : 'User');
            final lName = data['lastName'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
            
            _currentUser = User(
              id: firebaseUser.uid,
              studentId: data['studentId'] ?? '',
              email: firebaseUser.email ?? '',
              firstName: fName,
              lastName: lName,
              roleId: data['roleId'] ?? (data['role'] == 'admin' ? 'admin' : 'student'),
              role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
              program: data['program'],
              requiresPasswordChange: data['requiresPasswordChange'] ?? false,
            );
          } else {
            // Fallback if no document exists
            final fullName = firebaseUser.displayName ?? 'Unknown';
            final nameParts = fullName.split(' ');
            _currentUser = User(
              id: firebaseUser.uid,
              studentId: '', // Fallback empty
              email: firebaseUser.email ?? '',
              firstName: nameParts.isNotEmpty ? nameParts.first : 'User',
              lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
              roleId: firebaseUser.email?.contains('admin') == true ? 'admin' : 'student',
              role: firebaseUser.email?.contains('admin') == true
                  ? UserRole.admin
                  : UserRole.user,
            );
          }
        } catch (e) {
          debugPrint('Error fetching user profile: $e');
          // Fallback
          final fullName = firebaseUser.displayName ?? 'Unknown';
          final nameParts = fullName.split(' ');
          _currentUser = User(
            id: firebaseUser.uid,
            studentId: '',
            email: firebaseUser.email ?? '',
            firstName: nameParts.isNotEmpty ? nameParts.first : 'User',
            lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            roleId: 'student',
            role: UserRole.user,
          );
        }
        _isAuthenticated = true;
        _isInitialized = true;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _isInitialized = true;
      }
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error logging in: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _storage.delete(key: 'user_email'); // Clean up legacy storage if any
  }

  // Admin-only Registration (Creates a user in Firebase)
  Future<String?> registerUser({
    required String email,
    required String password,
    required String studentId,
    required String firstName,
    required String lastName,
    required String roleId,
    required String program,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      // Create user in Firebase Auth using a secondary app to avoid auto-login
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update Display Name
      await userCredential.user?.updateDisplayName('$firstName $lastName');

      // Save user details to Firestore
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        await _firestore.collection('users').doc(userId).set({
          'studentId': studentId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'program': program,
          'roleId': roleId, // Match normalized DB
          'requiresPasswordChange': true, // Force change on first login
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Trigger Email Notification (Trigger Email Extension pattern)
        await sendCredentialsEmail(email, password, firstName);
      }

      debugPrint('User registered: ${userCredential.user?.uid}');

      // Important: delete the secondary app to clean up resources
      await secondaryApp.delete();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('Error registering user: ${e.message}');
      if (secondaryApp != null) await secondaryApp.delete();
      return e.message;
    } catch (e) {
      debugPrint('Error registering user: $e');
      if (secondaryApp != null) await secondaryApp.delete();
      return e.toString();
    }
  }

  Future<void> sendCredentialsEmail(
    String email,
    String password,
    String name,
  ) async {
    final username = Env.smtpUsername;
    final smtpPasswordValue = Env.smtpPassword;
    final server = Env.smtpServer;
    final port = Env.smtpPort;

    // Clean password (remove spaces if any) - SMTP passwords from Gmail sometimes have spaces
    final cleanPassword = smtpPasswordValue.replaceAll(' ', '');

    debugPrint('Attempting to send email via $server:$port');

    final smtpServer = SmtpServer(
      server,
      port: port,
      username: username,
      password: cleanPassword,
      ssl: false, // Use STARTTLS (port 587 usually uses this)
      allowInsecure: true,
    );

    // Create the message
    final message = Message()
      ..from = Address(username, 'Health Support Admin')
      ..recipients.add(email)
      ..subject = 'Welcome to Health Support - Your Login Credentials'
      ..html =
          '''
          <h1>Welcome, $name!</h1>
          <p>Your account has been created by the administrator.</p>
          <p><strong>Login Credentials:</strong></p>
          <ul>
            <li><strong>Email:</strong> $email</li>
            <li><strong>Temporary Password:</strong> $password</li>
          </ul>
          <p>Please log in and change your password immediately.</p>
        ''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: ${sendReport.toString()}');
    } on MailerException catch (e) {
      debugPrint('Message not sent. Error: $e');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
    } catch (e) {
      debugPrint('Unexpected email error: $e');
    }
  }

  Future<bool> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        await _firestore.collection('users').doc(user.uid).update({
          'requiresPasswordChange': false,
        });
        // Update local state
        if (_currentUser != null) {
          _currentUser = User(
            id: _currentUser!.id,
            studentId: _currentUser!.studentId,
            email: _currentUser!.email,
            firstName: _currentUser!.firstName,
            lastName: _currentUser!.lastName,
            roleId: _currentUser!.roleId,
            role: _currentUser!.role,
            program: _currentUser!.program,
            requiresPasswordChange: false,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  String generatePassword({int length = 8}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%&';
    return List.generate(
      length,
      (index) => chars[DateTime.now().microsecondsSinceEpoch % chars.length],
    ).join();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint('Error sending password reset: $e');
      return false;
    }
  }

  Future<void> _ensureRolesExist() async {
    try {
      final snapshot = await _firestore.collection('roles').limit(1).get();
      if (snapshot.docs.isEmpty) {
        await _firestore.collection('roles').doc('admin').set({
          'role_name': 'Administrator',
          'description': 'System admin'
        });
        await _firestore.collection('roles').doc('student').set({
          'role_name': 'Student',
          'description': 'Student user'
        });
        debugPrint('Initialized roles table.');
      }
    } catch (e) {
      debugPrint('Could not initialize roles table: $e');
    }
  }
}

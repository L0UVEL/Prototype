import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../env/env.dart';
import '../models/user_model.dart';
import 'email_log_service.dart';

// Conditional import: mailer only works on non-web (dart:io)
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
              role: (data['roleId'] == 'admin' || data['role'] == 'admin') ? UserRole.admin : UserRole.user,
              program: data['program'],
              requiresPasswordChange: data['requiresPasswordChange'] ?? false,
            );
          } else {
            // Fallback if no document exists — create one so Firestore
            // security rules (which check the user doc) can verify the role.
            final fullName = firebaseUser.displayName ?? 'Unknown';
            final nameParts = fullName.split(' ');
            final detectedRole = firebaseUser.email?.contains('admin') == true ? 'admin' : 'student';
            final fName = nameParts.isNotEmpty ? nameParts.first : 'User';
            final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

            _currentUser = User(
              id: firebaseUser.uid,
              studentId: '', // Fallback empty
              email: firebaseUser.email ?? '',
              firstName: fName,
              lastName: lName,
              roleId: detectedRole,
              role: detectedRole == 'admin' ? UserRole.admin : UserRole.user,
            );

            // Persist the user doc to Firestore so security rules work
            try {
              await _firestore.collection('users').doc(firebaseUser.uid).set({
                'firstName': fName,
                'lastName': lName,
                'email': firebaseUser.email ?? '',
                'roleId': detectedRole,
                'role': detectedRole,
                'studentId': '',
                'createdAt': FieldValue.serverTimestamp(),
              });
              debugPrint('Created missing Firestore user doc for ${firebaseUser.uid} with role=$detectedRole');
            } catch (e) {
              debugPrint('Could not create Firestore user doc: $e');
            }
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
    // FlutterSecureStorage may behave differently on web — guard with try-catch
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'user_email');
    } catch (e) {
      debugPrint('Could not clean up secure storage: $e');
    }
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
      // On web, if the secondary app already exists (from a previous registration
      // in the same session), reuse it instead of crashing.
      try {
        secondaryApp = Firebase.app('SecondaryApp');
        debugPrint('Reusing existing SecondaryApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
        debugPrint('Created new SecondaryApp');
      }

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
          'role': roleId, // Also store as 'role' for Firestore security rules compatibility
          'requiresPasswordChange': true, // Force change on first login
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Build the email HTML for logging
        final emailHtml = '''
          <h1>Welcome, $firstName!</h1>
          <p>Your account has been created by the administrator.</p>
          <p><strong>Login Credentials:</strong></p>
          <ul>
            <li><strong>Email:</strong> $email</li>
            <li><strong>Temporary Password:</strong> $password</li>
          </ul>
          <p>Please log in and change your password immediately.</p>
        ''';
        final emailSubject = 'Welcome to Health Support - Your Login Credentials';

        // Send email via SMTP (non-web) or Vercel API (web) and log to Firestore
        try {
          if (!kIsWeb) {
            await _sendCredentialsEmailViaSMTP(email, password, firstName);
          } else {
            await _sendEmailViaVercelAPI(
              to: email,
              subject: emailSubject,
              htmlBody: emailHtml,
            );
          }
          // Log as sent
          await EmailLogService.logEmail(
            to: email,
            subject: emailSubject,
            htmlBody: emailHtml,
            type: 'credentials',
            sentBy: _auth.currentUser?.uid ?? 'system',
            status: 'sent',
          );
        } catch (e) {
          // Log as failed
          await EmailLogService.logEmail(
            to: email,
            subject: emailSubject,
            htmlBody: emailHtml,
            type: 'credentials',
            sentBy: _auth.currentUser?.uid ?? 'system',
            status: 'failed',
            error: e.toString(),
          );
        }
      }

      debugPrint('User registered: ${userCredential.user?.uid}');

      // Important: delete the secondary app to clean up resources
      await secondaryApp.delete();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('Error registering user: ${e.message}');
      if (secondaryApp != null) {
        try { await secondaryApp.delete(); } catch (_) {}
      }
      return e.message;
    } catch (e) {
      debugPrint('Error registering user: $e');
      if (secondaryApp != null) {
        try { await secondaryApp.delete(); } catch (_) {}
      }
      return e.toString();
    }
  }

  /// Internal: sends credentials via SMTP (non-web only).
  Future<void> _sendCredentialsEmailViaSMTP(
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

    final sendReport = await send(message, smtpServer);
    debugPrint('Message sent: ${sendReport.toString()}');
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
    final random = Random.secure();
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Sends a password reset: fires Firebase Auth's reset email (best-effort)
  /// and always sends a reliable SMTP notification so the user knows to check
  /// their inbox/spam for the Firebase reset link.
  /// Also logs the email to Firestore.
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      // 1. Try to look up the user's name (may fail if not authenticated — that's OK)
      String userName = 'User';
      try {
        final querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          userName = userData['firstName'] ?? userData['name'] ?? 'User';
        }
      } catch (e) {
        // Firestore may deny access for unauthenticated users — that's fine,
        // we'll just use the default name.
        debugPrint('Could not look up user name (expected if not logged in): $e');
      }

      // 2. Send Firebase Auth reset email (best-effort, often goes to spam)
      try {
        await _auth.sendPasswordResetEmail(email: email);
        debugPrint('Firebase reset email sent for $email');
      } catch (e) {
        debugPrint('Firebase reset email failed: $e');
      }

      // Build the email content for logging
      final emailSubject = 'Health Support - Password Reset Request';
      final emailHtml = _buildResetEmailHtml(userName);

      // 3. Send SMTP notification (non-web) or Vercel API (web) and log to Firestore
      try {
        if (!kIsWeb) {
          await _sendResetInstructionsViaSMTP(email, userName);
        } else {
          await _sendEmailViaVercelAPI(
            to: email,
            subject: emailSubject,
            htmlBody: emailHtml,
          );
        }
        // Log as sent
        await EmailLogService.logEmail(
          to: email,
          subject: emailSubject,
          htmlBody: emailHtml,
          type: 'password_reset',
          sentBy: _auth.currentUser?.uid ?? 'system',
          status: 'sent',
        );
      } catch (e) {
        // Log as failed
        await EmailLogService.logEmail(
          to: email,
          subject: emailSubject,
          htmlBody: emailHtml,
          type: 'password_reset',
          sentBy: _auth.currentUser?.uid ?? 'system',
          status: 'failed',
          error: e.toString(),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error in password reset flow: $e');
      return false;
    }
  }

  String _buildResetEmailHtml(String userName) {
    return '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #800000, #600000); padding: 24px; border-radius: 12px 12px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 22px;">Password Reset Request</h1>
        </div>
        <div style="padding: 24px; background: #fafafa; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
          <p style="font-size: 16px;">Hello, <strong>$userName</strong>!</p>
          <p>We received a request to reset your password for your Health Support account.</p>
          <p>A password reset link has been sent to your email. Please check both your <strong>inbox</strong> and <strong>spam/junk folder</strong> for an email from <code>noreply@health-support-system-pupuq.firebaseapp.com</code>.</p>
          <div style="background: #fff3cd; border: 1px solid #ffc107; border-radius: 8px; padding: 16px; margin: 16px 0;">
            <p style="margin: 0; font-size: 14px;"><strong>Can't find the email?</strong></p>
            <p style="margin: 8px 0 0 0; font-size: 14px;">Please contact your administrator directly to have your password reset manually.</p>
          </div>
          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
          <p style="color: #888; font-size: 12px;">If you did not request a password reset, please ignore this email. Your password will remain unchanged.</p>
          <p style="color: #888; font-size: 12px;">— Health Support System, PUP Unisan Campus</p>
        </div>
      </div>
    ''';
  }

  Future<void> _sendResetInstructionsViaSMTP(String email, String userName) async {
    final username = Env.smtpUsername;
    final smtpPasswordValue = Env.smtpPassword;
    final server = Env.smtpServer;
    final port = Env.smtpPort;

    final cleanPassword = smtpPasswordValue.replaceAll(' ', '');

    debugPrint('Sending password reset instructions via SMTP to $email');

    final smtpServer = SmtpServer(
      server,
      port: port,
      username: username,
      password: cleanPassword,
      ssl: false,
      allowInsecure: true,
    );

    final message = Message()
      ..from = Address(username, 'Health Support System')
      ..recipients.add(email)
      ..subject = 'Health Support - Password Reset Request'
      ..html = _buildResetEmailHtml(userName);

    final sendReport = await send(message, smtpServer);
    debugPrint('Password reset SMTP email sent: ${sendReport.toString()}');
  }

  /// Sends an email via Vercel Serverless API (web only).
  Future<void> _sendEmailViaVercelAPI({
    required String to,
    required String subject,
    required String htmlBody,
  }) async {
    final origin = Uri.base.origin;
    final apiUrl = '$origin/api/send-email';

    debugPrint('Attempting to send email via Vercel API: $apiUrl');

    final cleanPassword = Env.smtpPassword.replaceAll(' ', '');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $cleanPassword',
      },
      body: jsonEncode({
        'to': to,
        'subject': subject,
        'htmlBody': htmlBody,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Vercel API error (${response.statusCode}): ${response.body}');
    }
    debugPrint('Email sent successfully via Vercel API');
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

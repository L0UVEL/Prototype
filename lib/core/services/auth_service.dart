import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String email, String password) async {
    // Mock delay
    await Future.delayed(const Duration(seconds: 1));

    if (email == 'admin@test.com' && password == 'password') {
      _currentUser = User(
        id: 'admin_1',
        email: email,
        name: 'Admin User',
        role: UserRole.admin,
      );
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } else if (email == 'user@test.com' && password == 'password') {
      _currentUser = User(
        id: 'user_1',
        email: email,
        name: 'Regular User',
        role: UserRole.user,
      );
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }

    return false;
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

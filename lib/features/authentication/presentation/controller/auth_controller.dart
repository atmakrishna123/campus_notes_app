import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/services/auth_services.dart';
import '../../data/models/user_model.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoggedIn = false;
  bool _justLoggedIn = false;
  bool _justRegistered = false;
  bool _justLoggedOut = false;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _isLoggedIn;
  bool get justLoggedIn => _justLoggedIn;
  bool get justRegistered => _justRegistered;
  bool get justLoggedOut => _justLoggedOut;
  String? get currentUserUid => _authService.currentUser?.uid;

  AuthController({AuthService? authService, String? baseUrl})
      : _authService = authService ?? AuthService(baseUrl: baseUrl ?? '') {
    _checkCurrentUser();

    _authService.authStateChanges.listen((user) {
      final wasLoggedIn = _isLoggedIn;
      _isLoggedIn = user != null;

      if (wasLoggedIn && user == null) {
        _justLoggedOut = true;
      } else {
        _justLoggedOut = false;
      }

      _justLoggedIn = false;
      _justRegistered = false;
      _errorMessage = null;

      notifyListeners();
    });
  }

  Future<void> _checkCurrentUser() async {
    final user = _authService.currentUser;
    _isLoggedIn = user != null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    // DON'T clear error message here - let the methods handle it
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _errorMessage = null; 
    _setLoading(true);
    _justLoggedIn = false;

    try {
      final result = await _authService.login(email: email, password: password);

      if (result == null) {
        _isLoggedIn = true;
        _justLoggedIn = true;
        _errorMessage = null; 
      } else {
        // Map common Firebase auth errors to user-friendly messages
        if (result.toLowerCase().contains('password') || 
            result.toLowerCase().contains('wrong-password') ||
            result.toLowerCase().contains('invalid-credential')) {
          _errorMessage = 'Invalid password';
        } else if (result.toLowerCase().contains('user-not-found') || 
                   result.toLowerCase().contains('no user')) {
          _errorMessage = 'No account found with this email';
        } else if (result.toLowerCase().contains('invalid-email')) {
          _errorMessage = 'Invalid email address';
        } else if (result.toLowerCase().contains('too-many-requests')) {
          _errorMessage = 'Too many login attempts. Please try again later';
        } else {
          _errorMessage = 'Login failed. Please check your credentials';
        }
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again';
    }

    _setLoading(false);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String university,
    required String password,
    required String confirmPassword,
  }) async {
    _errorMessage = null; // Clear previous errors
    _setLoading(true);
    _justRegistered = false;

    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match';
      _setLoading(false);
      return;
    }

    final result = await _authService.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      mobile: mobile,
      university: university,
      password: password,
    );

    if (result == null) {
      _isLoggedIn = true;
      _justRegistered = true;
      _errorMessage = null;
    } else {
      // Map registration errors
      if (result.toLowerCase().contains('email-already-in-use') ||
          result.toLowerCase().contains('already exists')) {
        _errorMessage = 'An account with this email already exists';
      } else if (result.toLowerCase().contains('weak-password')) {
        _errorMessage = 'Password is too weak. Use at least 6 characters';
      } else if (result.toLowerCase().contains('invalid-email')) {
        _errorMessage = 'Invalid email address';
      } else {
        _errorMessage = 'Registration failed. Please try again';
      }
    }

    _setLoading(false);
  }

  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    _justLoggedIn = false;
    _justRegistered = false;
    _justLoggedOut = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      debugPrint('Firebase: sending reset link to $email');

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );

      debugPrint('Firebase: reset link sent');
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase error: ${e.code} - ${e.message}');
      _errorMessage = _mapFirebaseError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyResetToken(String token) async => true;

  Future<bool> resetPassword(String code, String newPassword) async {
    _errorMessage = null;
    _setLoading(true);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<UserModel?> getCurrentUser() async =>
      await _authService.getCurrentUserData();

  Future<String?> updateProfile({
    required String firstName,
    required String lastName,
    required String mobile,
    required String university,
  }) async {
    _errorMessage = null;
    _setLoading(true);

    final result = await _authService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      mobile: mobile,
      university: university,
    );

    if (result != null) _errorMessage = result;
    _setLoading(false);
    return result;
  }

  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _errorMessage = null;
    _setLoading(true);

    final result = await _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (result != null) _errorMessage = result;

    _setLoading(false);
    return result;
  }

  Future<String?> updateBankDetails({
    String? upiId,
    String? bankAccountNumber,
    String? ifscCode,
  }) async {
    _errorMessage = null;
    _setLoading(true);

    final result = await _authService.updateBankDetails(
      upiId: upiId,
      bankAccountNumber: bankAccountNumber,
      ifscCode: ifscCode,
    );

    if (result != null) _errorMessage = result;

    _setLoading(false);
    return result;
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'wrong-password':
        return 'Invalid password';
      case 'invalid-credential':
        return 'Invalid password';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}
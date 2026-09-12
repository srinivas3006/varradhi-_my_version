import 'package:flutter/material.dart';
import 'account_login_screen.dart';

class LoginScreen extends StatelessWidget {
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    return AccountLoginScreen(onLoginSuccess: onLoginSuccess);
  }
}

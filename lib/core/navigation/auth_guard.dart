import 'package:flutter/material.dart';

import '../../screens/account_login_screen.dart';
import '../../state/app_state.dart';

void requireAuth(BuildContext context, VoidCallback onSuccess) {
  if (AppState.instance.isLoggedIn) {
    onSuccess();
    return;
  }

  bool invoked = false;
  void handleSuccess() {
    if (!invoked) {
      invoked = true;
      onSuccess();
    }
  }

  Navigator.of(context, rootNavigator: true)
      .push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => AccountLoginScreen(onLoginSuccess: handleSuccess),
    ),
  )
      .then((loggedIn) {
    if (context.mounted &&
        (loggedIn == true || AppState.instance.isLoggedIn)) {
      handleSuccess();
    }
  });
}

Future<bool> ensureAuth(BuildContext context) async {
  if (AppState.instance.isLoggedIn) return true;
  final loggedIn = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => const AccountLoginScreen(),
    ),
  );
  return loggedIn == true || AppState.instance.isLoggedIn;
}

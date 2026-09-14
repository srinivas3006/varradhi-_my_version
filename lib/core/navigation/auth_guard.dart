import 'package:flutter/material.dart';

import '../../state/app_state.dart';

void requireAuth(BuildContext context, VoidCallback onSuccess) {
  if (AppState.instance.isLoggedIn) {
    onSuccess();
    return;
  }

  Navigator.of(context).pushNamed<bool>('/login').then((loggedIn) {
    if (context.mounted &&
        (loggedIn == true || AppState.instance.isLoggedIn)) {
      onSuccess();
    }
  });
}

Future<bool> ensureAuth(BuildContext context) async {
  if (AppState.instance.isLoggedIn) return true;
  final loggedIn = await Navigator.of(context).pushNamed<bool>('/login');
  return loggedIn == true || AppState.instance.isLoggedIn;
}

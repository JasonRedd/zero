import 'dart:async';

import 'package:flutter/material.dart';

import 'core/services/notification_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConnectApp());
  unawaited(
    NotificationService.init().catchError((Object error, StackTrace stack) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stack);
    }),
  );
}

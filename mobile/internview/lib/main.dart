import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/auth_logout.dart';
import 'core/platform/media_projection_fgs.dart';
import 'features/auth/controllers/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaProjectionFgs.stop();
  final container = ProviderContainer();
  bindAuthLogout(
    () => container.read(authControllerProvider.notifier).logout(),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const InternviewApp(),
    ),
  );
}

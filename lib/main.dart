import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'data/services/supabase_service.dart';

void main() {
  runZonedGuarded(
    () => unawaited(_bootstrap()),
    (error, stack) => debugPrint('UNCAUGHT ZONE ERROR: $error\n$stack'),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface framework errors instead of a silent white screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
  };

  try {
    await Env.load();
    await SupabaseService.init();
  } catch (e, st) {
    debugPrint('BOOTSTRAP FAILED: $e\n$st');
    runApp(_BootstrapError(message: '$e'));
    return;
  }

  runApp(
    const ProviderScope(
      child: MeshApp(),
    ),
  );
}

/// Minimal, dependency-free screen shown if bootstrap fails — uses only core
/// Flutter (no Supabase, no Google Fonts) so it always renders.
class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'mesh failed to start',
                  style: TextStyle(
                    color: Color(0xFFFF4D8D),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF5F5FA)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

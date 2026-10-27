import 'core/constants/app_constants.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/local_storage.dart';
import 'core/widgets/web_preview_frame.dart';
import 'core/widgets/app_error_fallback.dart';
import 'core/utils/app_error_reporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter.install();
  try {
    AppConstants.validateReleaseConfiguration();

    final sharedPreferences = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const ChoreWarsApp(),
      ),
    );
  } catch (error, stack) {
    AppErrorReporter.report(error, stack);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: AppErrorFallback()),
      ),
    );
  }
}

class ChoreWarsApp extends ConsumerWidget {
  const ChoreWarsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Chore Wars',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppErrorReporter.messengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      routerConfig: router,
      builder: (context, child) =>
          WebPreviewFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}

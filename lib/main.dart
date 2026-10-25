import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/ad_manager.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'core/state.dart';
import 'features/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container =
      ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  // Initialise the ad SDK (no-op on web).  On web rewarded ads auto-unlock.
  await container.read(adProvider).init();
  unawaited(container.read(adProvider).preload());
  runApp(UncontrolledProviderScope(
      container: container, child: const SafaaDocsApp()));
}

class SafaaDocsApp extends ConsumerWidget {
  const SafaaDocsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        home: const DashboardScreen(),
      );
}

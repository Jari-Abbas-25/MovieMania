import 'package:flutter/material.dart';
import 'core/bridge/moviebox_bridge.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/moviemania_loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovieBoxApp());
}

class MovieBoxApp extends StatefulWidget {
  const MovieBoxApp({super.key});

  @override
  State<MovieBoxApp> createState() => _MovieBoxAppState();
}

class _MovieBoxAppState extends State<MovieBoxApp> {
  bool _isCoreInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initCore();
  }

  Future<void> _initCore() async {
    try {
      final res = await MovieBoxBridge.init();
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _isCoreInitialized = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _initError = res['error']?.toString() ?? 'Core initialization failed.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Core initialization error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieMania',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _initError != null
          ? Scaffold(
              backgroundColor: AppColors.background,
              body: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Engine Initialization Error',
                description: _initError!,
                actionLabel: 'Retry',
                onAction: () {
                  setState(() => _initError = null);
                  _initCore();
                },
              ),
            )
          : !_isCoreInitialized
              ? const MovieManiaLoadingScreen()
              : const MainShell(),
    );
  }
}

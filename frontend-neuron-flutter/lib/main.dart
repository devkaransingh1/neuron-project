import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NeuronApp());
}

class NeuronApp extends StatefulWidget {
  const NeuronApp({super.key});

  @override
  State<NeuronApp> createState() => _NeuronAppState();
}

class _NeuronAppState extends State<NeuronApp> {
  // Dark theme is the default
  bool isDarkMode = true;
  bool isLoggedIn = false;
  String currentUser = 'TEAM';

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  void handleLogin(String user) {
    setState(() {
      currentUser = user.isNotEmpty ? user : 'TEAM';
      isLoggedIn = true;
    });
  }

  void handleLogout() {
    setState(() {
      isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neuron - Your Second Brain',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: isLoggedIn
          ? NeuronDashboard(
              userName: currentUser,
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              onLogout: handleLogout,
            )
          : NeuronAuthPage(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              onLoginSuccess: handleLogin,
            ),
    );
  }
}

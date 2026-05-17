import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/game_state.dart';
import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameState(),
      child: const KumaApp(),
    ),
  );
}

class KumaApp extends StatelessWidget {
  const KumaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUMA - Horror Found-Footage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF8B0000),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B0000),
          secondary: Color(0xFFFF0000),
          surface: Colors.black,
        ),
        fontFamily: 'Courier',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }
}

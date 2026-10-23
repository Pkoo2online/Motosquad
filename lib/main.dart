import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/convoy_provider.dart';
import 'screens/session_setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConvoyProvider()),
      ],
      child: const MotoSquadApp(),
    ),
  );
}

class MotoSquadApp extends StatelessWidget {
  const MotoSquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoSquad Convoy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101216),
        primarySwatch: Colors.orange,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orangeAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF1E222B),
        ),
        useMaterial3: true,
      ),
      home: const SessionSetupScreen(),
    );
  }
}

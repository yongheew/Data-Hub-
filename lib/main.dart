import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'package:datahub/screens/login_page.dart';
import 'package:datahub/screens/signup_page.dart';
import 'package:datahub/screens/home_page.dart';
import 'package:datahub/screens/dashboard_page.dart';
import 'package:datahub/screens/insights_page.dart';
import 'package:datahub/screens/chat_history.dart';
import 'package:datahub/screens/data_log_page.dart';
import 'package:datahub/screens/notes_page.dart';
import 'package:datahub/screens/chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataHub',
      debugShowCheckedModeBanner: false,

      // Default starting screen
      initialRoute: '/login',

      routes: {
        // Authentication
        '/login': (_) => const LoginPage(),
        '/signup': (_) => SignUpPage(),

        // Main navigation
        '/home': (_) => const HomePage(),
        '/dashboard': (_) => DashboardPage(), // removed const (safe)
        '/insights': (_) => const InsightsPage(),
        '/chat-history': (_) => const ChatHistoryPage(),
        '/data-log': (_) => const DataLogPage(),
        '/notes': (_) => NotesPage(),
        '/chat': (_) => const ChatPage(chatId: "default"),
      },
    );
  }
}

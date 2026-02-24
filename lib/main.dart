import 'package:flutter/material.dart';
import 'package:datahub/screens/login_page.dart';
import 'package:datahub/screens/signup_page.dart';
import 'package:datahub/screens/home_page.dart';
import 'package:datahub/screens/dashboard_page.dart';
import 'package:datahub/screens/insights_page.dart';
import 'package:datahub/screens/chat_history.dart';
import 'package:datahub/screens/data_log_page.dart';
import 'package:datahub/screens/notes_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => const HomePage(),
        '/dashboard': (context) => const DashboardPage(),
        '/insights': (context) => const InsightsPage(),
        '/chat-history': (context) => const ChatHistoryPage(),
        '/data-log': (context) => const DataLogPage(),
        '/notes': (context) => const NotesPage(),
      },
    );
  }
}

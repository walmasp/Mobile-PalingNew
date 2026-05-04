import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'features/auth/screens/welcome_screen.dart';
import 'core/utils/point_provider.dart'; 
import 'core/utils/notification_helper.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await NotificationHelper.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PointProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Caffio App',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          primary: Colors.brown[700],
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

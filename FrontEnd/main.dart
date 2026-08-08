import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:text_to_image/root_page.dart';

// import 'app_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Required before touching Firebase — AuthGate needs this to be ready.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ZImageApp());
}

class ZImageApp extends StatelessWidget {
  const ZImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const RootPage(),
    );
  }
}
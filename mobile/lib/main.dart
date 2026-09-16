import 'package:flutter/material.dart';

import 'src/app_scope.dart';
import 'src/screens/home_screen.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SuperTarotApp(services: await AppServices.create()));
}

class SuperTarotApp extends StatelessWidget {
  const SuperTarotApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'SuperTarot',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}

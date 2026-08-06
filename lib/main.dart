import "package:flutter/material.dart";

import "app.dart";
import "theme.dart";

void main() {
  runApp(const CarrotaApp());
}

class CarrotaApp extends StatelessWidget {
  const CarrotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Carrota",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    );
  }
}

import 'package:flutter/material.dart';

/// Sprint 1 scaffold.
///
/// The exit gate for this sprint is green CI on an empty app (spec §12), so
/// this is deliberately a placeholder: the Train screen, the round timer and
/// the capture pipeline all arrive in later sprints and none of them are
/// started here.
void main() => runApp(const MettleRangerApp());

class MettleRangerApp extends StatelessWidget {
  const MettleRangerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mettle Ranger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E42),
          brightness: Brightness.dark,
        ),
      ),
      home: const Scaffold(body: Center(child: Text('Mettle Ranger'))),
    );
  }
}

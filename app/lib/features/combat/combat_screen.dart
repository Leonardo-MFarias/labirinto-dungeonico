import 'package:flutter/material.dart';

class CombatScreen extends StatelessWidget {
  const CombatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Combate')),
      body: const Center(
        child: Text('TODO: log de combate em tempo real via WebSocket'),
      ),
    );
  }
}

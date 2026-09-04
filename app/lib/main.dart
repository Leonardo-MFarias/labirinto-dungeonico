import 'package:flutter/material.dart';

import 'features/character/character_screen.dart';
import 'features/combat/combat_screen.dart';
import 'features/dungeon_map/dungeon_map_screen.dart';
import 'features/inventory/inventory_screen.dart';

void main() {
  runApp(const LabirintoDungeonicoApp());
}

class LabirintoDungeonicoApp extends StatelessWidget {
  const LabirintoDungeonicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labirinto Dungeonico',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Labirinto Dungeonico')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DungeonMapScreen()),
              ),
              child: const Text('Mapa'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CombatScreen()),
              ),
              child: const Text('Combate'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              ),
              child: const Text('Inventário'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CharacterScreen()),
              ),
              child: const Text('Personagem'),
            ),
          ],
        ),
      ),
    );
  }
}

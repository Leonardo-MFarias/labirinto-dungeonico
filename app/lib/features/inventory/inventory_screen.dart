import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventário')),
      body: const Center(
        child: Text('TODO: lista de itens e equipamentos'),
      ),
    );
  }
}

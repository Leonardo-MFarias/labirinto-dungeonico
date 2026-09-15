import 'package:flutter/material.dart';

import 'rarity.dart';

/// RNF-09: raridade distinguível por cor **e** rótulo textual, não só cor.
/// Compartilhado entre `InventoryScreen` e `CharacterScreen` (chip de item
/// arrastável) para não duplicar a tabela.
const rarityLabels = {
  Rarity.obsoleto: 'Obsoleto',
  Rarity.arcaico: 'Arcaico',
  Rarity.trivial: 'Trivial',
  Rarity.normal: 'Normal',
  Rarity.comum: 'Comum',
  Rarity.incomum: 'Incomum',
  Rarity.lendario: 'Lendário',
  Rarity.mitico: 'Mítico',
  Rarity.divino: 'Divino',
  Rarity.astral: 'Astral',
};

const rarityColors = {
  Rarity.obsoleto: Color(0xFF6D6D6D),
  Rarity.arcaico: Color(0xFF8D6E63),
  Rarity.trivial: Color(0xFF9E9E9E),
  Rarity.normal: Color(0xFFEEEEEE),
  Rarity.comum: Color(0xFF4CAF50),
  Rarity.incomum: Color(0xFF2196F3),
  Rarity.lendario: Color(0xFFFF9800),
  Rarity.mitico: Color(0xFFE91E63),
  Rarity.divino: Color(0xFFFFD700),
  Rarity.astral: Color(0xFF00E5FF),
};

import 'package:flutter/material.dart';

import '../../core/models/equipment_category.dart';
import '../../core/models/item.dart';

/// RF-37/RF-38/RF-56: os oito slots de equipamento (RN-23), cada um um
/// [DragTarget] que aceita um [Item] arrastado do inventário. Destaque verde
/// durante o arraste quando o item é compatível com o slot, vermelho quando
/// não é (RN-24) — a validação real acontece no servidor (RN-13); esta tela
/// só dá a dica visual.
class EquipmentSlots extends StatelessWidget {
  const EquipmentSlots({
    super.key,
    required this.equipped,
    required this.onEquip,
    required this.onUnequip,
  });

  final Map<String, Item> equipped;
  final void Function(String itemId, String slot) onEquip;
  final void Function(String slot) onUnequip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final slot in kSlots) _slotBox(context, slot)],
    );
  }

  Widget _slotBox(BuildContext context, String slot) {
    final item = equipped[slot];
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) => compatibleSlots(details.data.baseType).contains(slot),
      onAcceptWithDetails: (details) => onEquip(details.data.id, slot),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        final invalid = rejected.isNotEmpty;
        return Container(
          key: ValueKey('slot-$slot'),
          width: 120,
          height: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(
              color: invalid ? Colors.redAccent : highlighted ? Colors.greenAccent : Colors.grey,
              width: highlighted || invalid ? 3 : 1,
            ),
            color: highlighted ? Colors.green.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: item == null
              ? Center(
                  child: Text(
                    kSlotLabels[slot]!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : GestureDetector(
                  onTap: () => onUnequip(slot),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(kSlotLabels[slot]!, style: Theme.of(context).textTheme.labelSmall),
                      Text(_capitalize(item.baseType), overflow: TextOverflow.ellipsis),
                      const Icon(Icons.remove_circle_outline, size: 14),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

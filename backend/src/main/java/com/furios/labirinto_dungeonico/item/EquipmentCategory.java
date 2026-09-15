package com.furios.labirinto_dungeonico.item;

import com.furios.labirinto_dungeonico.character.Slot;

import java.util.List;

/** RN-24: as sete categorias de equipamento, derivadas do {@code baseType} do item. */
public enum EquipmentCategory {
    WEAPON,
    SHIELD,
    HEAD_ARMOR,
    CHEST_ARMOR,
    LEG_ARMOR,
    FOOT_ARMOR,
    ACCESSORY;

    /** RN-24/RN-25: slot(s) em que um item desta categoria pode ser equipado. */
    public List<Slot> compatibleSlots() {
        return switch (this) {
            case WEAPON, SHIELD -> List.of(Slot.HAND_LEFT, Slot.HAND_RIGHT);
            case HEAD_ARMOR -> List.of(Slot.HEAD);
            case CHEST_ARMOR -> List.of(Slot.CHEST);
            case LEG_ARMOR -> List.of(Slot.LEGS);
            case FOOT_ARMOR -> List.of(Slot.FEET);
            case ACCESSORY -> List.of(Slot.ACCESSORY_1, Slot.ACCESSORY_2);
        };
    }
}

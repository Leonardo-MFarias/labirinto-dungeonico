package com.furios.labirinto_dungeonico.character;

import com.furios.labirinto_dungeonico.item.Affix;
import com.furios.labirinto_dungeonico.item.Item;
import com.furios.labirinto_dungeonico.item.Rarity;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** RF-08, RF-37, RF-38, RN-23 a RN-25: equipar/desequipar e atributos efetivos. */
class CharacterTest {

    private static final Attributes BASE = new Attributes(5, 5, 5, 5, 5, 5);

    private Character newCharacter() {
        return new Character(UUID.randomUUID().toString(), "Testador", BASE, GameMode.NORMAL);
    }

    private Item item(String baseType, Affix... affixes) {
        return new Item(UUID.randomUUID().toString(), baseType, 1, Rarity.NORMAL, List.of(affixes), Map.of());
    }

    private Affix affix(Map<String, Double> modifiers) {
        return new Affix(UUID.randomUUID().toString(), "Afixo de teste", modifiers, 1, Rarity.NORMAL);
    }

    @Test
    void equiparMoveItemDoInventarioParaOSlot() {
        Character character = newCharacter();
        Item sword = item("espada");
        character.addItem(sword);

        character.equip(sword.id(), Slot.HAND_LEFT);

        assertEquals(sword, character.equipped().get(Slot.HAND_LEFT));
        assertFalse(character.inventory().contains(sword));
    }

    @Test
    void equiparEmSlotJaOcupadoDevolveItemAnteriorAoInventario() {
        Character character = newCharacter();
        Item sword = item("espada");
        Item axe = item("machado");
        character.addItem(sword);
        character.addItem(axe);

        character.equip(sword.id(), Slot.HAND_LEFT);
        character.equip(axe.id(), Slot.HAND_LEFT);

        assertEquals(axe, character.equipped().get(Slot.HAND_LEFT));
        assertTrue(character.inventory().contains(sword));
        assertFalse(character.inventory().contains(axe));
    }

    @Test
    void equiparCategoriaIncompativelLancaInvalidEquipException() {
        Character character = newCharacter();
        Item helmet = item("elmo");
        character.addItem(helmet);

        assertThrows(InvalidEquipException.class, () -> character.equip(helmet.id(), Slot.HAND_LEFT));
    }

    @Test
    void equiparItemInexistenteLancaInvalidEquipException() {
        Character character = newCharacter();
        assertThrows(InvalidEquipException.class, () -> character.equip("nao-existe", Slot.HEAD));
    }

    @Test
    void equiparArmaOuEscudoAceitaQualquerCombinacaoNasDuasMaos() {
        Character character = newCharacter();
        Item sword = item("espada");
        Item axe = item("machado");
        Item shieldOne = item("escudo");
        Item shieldTwo = item("escudo");
        character.addItem(sword);
        character.addItem(axe);
        character.addItem(shieldOne);
        character.addItem(shieldTwo);

        // arma + arma
        character.equip(sword.id(), Slot.HAND_LEFT);
        character.equip(axe.id(), Slot.HAND_RIGHT);
        assertEquals(sword, character.equipped().get(Slot.HAND_LEFT));
        assertEquals(axe, character.equipped().get(Slot.HAND_RIGHT));

        // arma + escudo
        character.equip(shieldOne.id(), Slot.HAND_RIGHT);
        assertEquals(sword, character.equipped().get(Slot.HAND_LEFT));
        assertEquals(shieldOne, character.equipped().get(Slot.HAND_RIGHT));

        // escudo + escudo
        character.equip(shieldTwo.id(), Slot.HAND_LEFT);
        assertEquals(shieldTwo, character.equipped().get(Slot.HAND_LEFT));
        assertEquals(shieldOne, character.equipped().get(Slot.HAND_RIGHT));
    }

    @Test
    void desequiparDevolveItemAoInventarioEEsvaziaSlot() {
        Character character = newCharacter();
        Item sword = item("espada");
        character.addItem(sword);
        character.equip(sword.id(), Slot.HAND_LEFT);

        character.unequip(Slot.HAND_LEFT);

        assertNull(character.equipped().get(Slot.HAND_LEFT));
        assertTrue(character.inventory().contains(sword));
    }

    @Test
    void desequiparSlotVazioNaoLancaExcecao() {
        Character character = newCharacter();
        character.unequip(Slot.HEAD);
        assertNull(character.equipped().get(Slot.HEAD));
    }

    @Test
    void effectiveAttributesSemItensEquipadosIgualAAttributesBase() {
        Character character = newCharacter();
        assertEquals(character.attributes(), character.effectiveAttributes());
    }

    @Test
    void effectiveAttributesSomaApenasModificadoresQueCorrespondemACamposDeAttributes() {
        Character character = newCharacter();
        Item sword = item("espada", affix(Map.of("damage", 5.0, "durability", -5.0)));
        Item shield = item("escudo", affix(Map.of("defense", 4.0, "speed", 2.0)));
        character.addItem(sword);
        character.addItem(shield);
        character.equip(sword.id(), Slot.HAND_LEFT);
        character.equip(shield.id(), Slot.HAND_RIGHT);

        Attributes effective = character.effectiveAttributes();

        assertEquals(BASE.strength(), effective.strength());
        assertEquals(BASE.defense() + 4, effective.defense());
        assertEquals(BASE.speed() + 2, effective.speed());
    }
}

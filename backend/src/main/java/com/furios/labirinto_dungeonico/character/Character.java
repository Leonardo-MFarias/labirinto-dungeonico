package com.furios.labirinto_dungeonico.character;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.furios.labirinto_dungeonico.item.Affix;
import com.furios.labirinto_dungeonico.item.EquipmentCategory;
import com.furios.labirinto_dungeonico.item.Item;
import com.furios.labirinto_dungeonico.item.ItemCatalog;

import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class Character {

    /** RN-11 (fórmula não especificada, assumida nesta versão): 20 + vitality*5 + (level-1)*10. */
    private static final int BASE_HEALTH = 20;
    private static final int HEALTH_PER_VITALITY = 5;
    private static final int HEALTH_PER_LEVEL = 10;

    /** RN-28 (fórmula assumida): XP necessária para ir do nível L ao L+1 é {@code 100 * L}. */
    private static final int LEVEL_UP_XP_PER_LEVEL = 100;

    /** RN-29 (valor assumido): pontos de atributo concedidos a cada level up (RF-07). */
    private static final int ATTRIBUTE_POINTS_PER_LEVEL = 3;

    private final String id;
    private final String name;
    private final GameMode mode;
    private int level;
    private int experience;
    private int unspentAttributePoints;
    private Attributes attributes;
    private int currentHealth;
    private final List<Item> inventory = new ArrayList<>();
    private final Map<Slot, Item> equipped = new EnumMap<>(Slot.class);

    public Character(String id, String name, Attributes attributes, GameMode mode) {
        this.id = id;
        this.name = name;
        this.attributes = attributes;
        this.mode = mode;
        this.level = 1;
        this.experience = 0;
        this.unspentAttributePoints = 0;
        this.currentHealth = maxHealth();
    }

    public String id() {
        return id;
    }

    public String name() {
        return name;
    }

    public int level() {
        return level;
    }

    public int experience() {
        return experience;
    }

    /** RF-07: pontos de atributo concedidos por level up ainda não distribuídos. */
    public int unspentAttributePoints() {
        return unspentAttributePoints;
    }

    public Attributes attributes() {
        return attributes;
    }

    public List<Item> inventory() {
        return inventory;
    }

    public Map<Slot, Item> equipped() {
        return equipped;
    }

    public GameMode mode() {
        return mode;
    }

    /** Método calculado, não campo — sem isto o Jackson não o serializa (só detecta getters
     * públicos no padrão getX/isX por convenção; maxHealth() não segue essa convenção). */
    @JsonProperty("maxHealth")
    public int maxHealth() {
        return BASE_HEALTH + attributes.vitality() * HEALTH_PER_VITALITY + (level - 1) * HEALTH_PER_LEVEL;
    }

    public int currentHealth() {
        return currentHealth;
    }

    public boolean isAlive() {
        return currentHealth > 0;
    }

    public void applyDamage(int amount) {
        currentHealth = Math.max(0, currentHealth - amount);
    }

    /** RN-02: ao retornar à entrada após derrota em modo NORMAL, a vida é restaurada. */
    public void resetHealth() {
        currentHealth = maxHealth();
    }

    public void addItem(Item item) {
        inventory.add(item);
    }

    /** RF-05/RF-06 (RN-28): acumula XP e sobe de nível enquanto o saldo atingir o limiar do
     * nível atual — um ganho grande pode subir mais de um nível de uma vez. Cada level up
     * concede pontos de atributo (RF-07, RN-29) e soma ao HP atual o mesmo ganho de HP máximo
     * do nível (RN-28) — não um heal completo, para não apagar dano sofrido antes (e sem isso,
     * uma run em HARDCORE ficaria praticamente impossível de perder por dano acumulado: bastaria
     * continuar subindo de nível). */
    public void gainExperience(int amount) {
        this.experience = Math.max(0, this.experience + amount);
        while (experience >= xpToNextLevel()) {
            experience -= xpToNextLevel();
            int previousMaxHealth = maxHealth();
            level++;
            unspentAttributePoints += ATTRIBUTE_POINTS_PER_LEVEL;
            currentHealth = Math.min(maxHealth(), currentHealth + (maxHealth() - previousMaxHealth));
        }
    }

    private int xpToNextLevel() {
        return LEVEL_UP_XP_PER_LEVEL * level;
    }

    /**
     * RF-07: distribui um dos pontos de atributo não gastos no atributo pedido, incrementando-o
     * em 1. Lança {@link InvalidAttributeAllocationException} se não houver pontos disponíveis.
     */
    public void allocateAttributePoint(AttributeType attribute) {
        if (unspentAttributePoints <= 0) {
            throw new InvalidAttributeAllocationException("Não há pontos de atributo disponíveis para distribuir.");
        }
        attributes = switch (attribute) {
            case STRENGTH -> new Attributes(attributes.strength() + 1, attributes.agility(), attributes.vitality(),
                    attributes.speed(), attributes.defense(), attributes.intelligence());
            case AGILITY -> new Attributes(attributes.strength(), attributes.agility() + 1, attributes.vitality(),
                    attributes.speed(), attributes.defense(), attributes.intelligence());
            case VITALITY -> new Attributes(attributes.strength(), attributes.agility(), attributes.vitality() + 1,
                    attributes.speed(), attributes.defense(), attributes.intelligence());
            case SPEED -> new Attributes(attributes.strength(), attributes.agility(), attributes.vitality(),
                    attributes.speed() + 1, attributes.defense(), attributes.intelligence());
            case DEFENSE -> new Attributes(attributes.strength(), attributes.agility(), attributes.vitality(),
                    attributes.speed(), attributes.defense() + 1, attributes.intelligence());
            case INTELLIGENCE -> new Attributes(attributes.strength(), attributes.agility(), attributes.vitality(),
                    attributes.speed(), attributes.defense(), attributes.intelligence() + 1);
        };
        unspentAttributePoints--;
    }

    /**
     * RF-37/RN-24/RN-25: equipa um item já presente no inventário no slot pedido. Se o slot já
     * tinha um item, ele volta ao inventário (RN-23: no máximo um item por slot).
     */
    public void equip(String itemId, Slot slot) {
        Item item = inventory.stream()
                .filter(candidate -> candidate.id().equals(itemId))
                .findFirst()
                .orElseThrow(() -> new InvalidEquipException("Item não encontrado no inventário: " + itemId));

        EquipmentCategory category = ItemCatalog.categoryOf(item.baseType());
        if (!category.compatibleSlots().contains(slot)) {
            throw new InvalidEquipException(
                    "Item da categoria " + category + " não pode ser equipado no slot " + slot);
        }

        inventory.remove(item);
        Item previous = equipped.put(slot, item);
        if (previous != null) {
            inventory.add(previous);
        }
    }

    /** RF-38: desequipa o slot, devolvendo o item ao inventário. Não-op se o slot já está vazio. */
    public void unequip(Slot slot) {
        Item item = equipped.remove(slot);
        if (item != null) {
            inventory.add(item);
        }
    }

    /**
     * RF-08: atributos base somados aos modificadores dos afixos de todos os itens equipados
     * cuja chave bate exatamente com um dos seis campos de {@link Attributes} — modificadores
     * de outra natureza (ex.: {@code damage}, {@code durability}, {@code fireDamage}) não são
     * contribuições de atributo e são ignorados aqui. Acumula em {@code double} e arredonda uma
     * única vez por atributo no final, para não compor erro de arredondamento entre afixos.
     */
    @JsonProperty("effectiveAttributes")
    public Attributes effectiveAttributes() {
        double strength = attributes.strength();
        double agility = attributes.agility();
        double vitality = attributes.vitality();
        double speed = attributes.speed();
        double defense = attributes.defense();
        double intelligence = attributes.intelligence();

        for (Item item : equipped.values()) {
            for (Affix affix : item.prefixes()) {
                Map<String, Double> modifiers = affix.modifiers();
                strength += modifiers.getOrDefault("strength", 0.0);
                agility += modifiers.getOrDefault("agility", 0.0);
                vitality += modifiers.getOrDefault("vitality", 0.0);
                speed += modifiers.getOrDefault("speed", 0.0);
                defense += modifiers.getOrDefault("defense", 0.0);
                intelligence += modifiers.getOrDefault("intelligence", 0.0);
            }
        }

        return new Attributes(
                (int) Math.round(strength), (int) Math.round(agility), (int) Math.round(vitality),
                (int) Math.round(speed), (int) Math.round(defense), (int) Math.round(intelligence));
    }
}

package com.furios.labirinto_dungeonico.character;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.furios.labirinto_dungeonico.item.Item;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class Character {

    /** RN-11 (fórmula não especificada, assumida nesta versão): 20 + vitality*5 + (level-1)*10. */
    private static final int BASE_HEALTH = 20;
    private static final int HEALTH_PER_VITALITY = 5;
    private static final int HEALTH_PER_LEVEL = 10;

    private final String id;
    private final String name;
    private final GameMode mode;
    private int level;
    private int experience;
    private Attributes attributes;
    private int currentHealth;
    private final List<Item> inventory = new ArrayList<>();
    private final Map<String, Item> equipped = new HashMap<>();

    public Character(String id, String name, Attributes attributes, GameMode mode) {
        this.id = id;
        this.name = name;
        this.attributes = attributes;
        this.mode = mode;
        this.level = 1;
        this.experience = 0;
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

    public Attributes attributes() {
        return attributes;
    }

    public List<Item> inventory() {
        return inventory;
    }

    public Map<String, Item> equipped() {
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

    public void gainExperience(int amount) {
        // TODO: aplicar curva de experiência e disparar level up quando atingir o limiar
        this.experience = Math.max(0, this.experience + amount);
    }
}

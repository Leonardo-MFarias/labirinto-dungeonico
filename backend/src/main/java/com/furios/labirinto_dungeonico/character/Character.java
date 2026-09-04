package com.furios.labirinto_dungeonico.character;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.furios.labirinto_dungeonico.item.Item;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class Character {

    private final String id;
    private final String name;
    private final GameMode mode;
    private int level;
    private int experience;
    private Attributes attributes;
    private final List<Item> inventory = new ArrayList<>();
    private final Map<String, Item> equipped = new HashMap<>();

    public Character(String id, String name, Attributes attributes, GameMode mode) {
        this.id = id;
        this.name = name;
        this.attributes = attributes;
        this.mode = mode;
        this.level = 1;
        this.experience = 0;
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

    public void gainExperience(int amount) {
        // TODO: aplicar curva de experiência e disparar level up quando atingir o limiar
        this.experience += amount;
    }
}

package com.furios.labirinto_dungeonico.combat;

import com.furios.labirinto_dungeonico.character.Attributes;

public record Enemy(String id, String name, Attributes attributes, int currentHealth, int maxHealth) {
}

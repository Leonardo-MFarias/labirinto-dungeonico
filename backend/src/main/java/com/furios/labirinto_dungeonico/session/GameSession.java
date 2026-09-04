package com.furios.labirinto_dungeonico.session;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.furios.labirinto_dungeonico.character.Character;
import com.furios.labirinto_dungeonico.dungeon.DungeonMap;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class GameSession {

    private final String id;
    private final Character character;
    private final DungeonMap dungeonMap;

    public GameSession(String id, Character character, DungeonMap dungeonMap) {
        this.id = id;
        this.character = character;
        this.dungeonMap = dungeonMap;
    }

    public String id() {
        return id;
    }

    public Character character() {
        return character;
    }

    public DungeonMap dungeonMap() {
        return dungeonMap;
    }
}

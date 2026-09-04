package com.furios.labirinto_dungeonico.dungeon;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.furios.labirinto_dungeonico.combat.Enemy;
import com.furios.labirinto_dungeonico.item.Item;

import java.util.ArrayList;
import java.util.List;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class Room {

    private final String id;
    private final RoomType type;
    private final List<Item> items = new ArrayList<>();
    private final List<String> connectedRoomIds = new ArrayList<>();
    private Enemy enemy;

    public Room(String id, RoomType type) {
        this.id = id;
        this.type = type;
    }

    public String id() {
        return id;
    }

    public RoomType type() {
        return type;
    }

    public List<Item> items() {
        return items;
    }

    public List<String> connectedRoomIds() {
        return connectedRoomIds;
    }

    public Enemy enemy() {
        return enemy;
    }

    public void setEnemy(Enemy enemy) {
        this.enemy = enemy;
    }
}

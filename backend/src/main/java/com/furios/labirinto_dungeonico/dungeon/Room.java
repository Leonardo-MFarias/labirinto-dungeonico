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
    private final int x;
    private final int y;
    private final List<Item> items = new ArrayList<>();
    private final List<String> connectedRoomIds = new ArrayList<>();
    private Enemy enemy;

    public Room(String id, RoomType type, int x, int y) {
        this.id = id;
        this.type = type;
        this.x = x;
        this.y = y;
    }

    public String id() {
        return id;
    }

    public RoomType type() {
        return type;
    }

    /** Coluna da célula na grade do autômato celular (0-indexada, cresce para a direita). */
    public int x() {
        return x;
    }

    /** Linha da célula na grade do autômato celular (0-indexada, cresce para baixo). */
    public int y() {
        return y;
    }

    public List<Item> items() {
        return items;
    }

    /**
     * Ids das salas andáveis ortogonalmente adjacentes (cima/baixo/esquerda/direita) nesta
     * grade. Calculado pelo MapGenerator após a suavização do autômato celular; vazio para
     * salas do tipo WALL, que nunca aparecem como vizinhas de uma sala andável (RN-15).
     */
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

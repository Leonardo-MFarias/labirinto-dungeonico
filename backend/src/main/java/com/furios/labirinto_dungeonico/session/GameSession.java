package com.furios.labirinto_dungeonico.session;

import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.furios.labirinto_dungeonico.character.Character;
import com.furios.labirinto_dungeonico.dungeon.DungeonMap;

import java.util.LinkedHashSet;
import java.util.Set;

@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class GameSession {

    private final String id;
    private final Character character;
    private final DungeonMap dungeonMap;
    private String currentRoomId;
    private final Set<String> visitedRoomIds = new LinkedHashSet<>();
    private int depth;

    public GameSession(String id, Character character, DungeonMap dungeonMap, int depth) {
        this.id = id;
        this.character = character;
        this.dungeonMap = dungeonMap;
        this.depth = depth;
        this.currentRoomId = dungeonMap.entranceRoomId();
        this.visitedRoomIds.add(currentRoomId);
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

    public String currentRoomId() {
        return currentRoomId;
    }

    /** RF-17: salas já visitadas na sessão. */
    public Set<String> visitedRoomIds() {
        return visitedRoomIds;
    }

    public int depth() {
        return depth;
    }

    /** RF-16/RF-17: move para {@code roomId} e marca como visitada. Não valida conectividade
     * (RN-15) — isso é responsabilidade de quem chama, que tem acesso à sala de origem. */
    public void moveTo(String roomId) {
        this.currentRoomId = roomId;
        this.visitedRoomIds.add(roomId);
    }

    /** RN-02: derrota em modo NORMAL devolve o personagem à entrada do andar atual. */
    public void returnToEntrance() {
        this.currentRoomId = dungeonMap.entranceRoomId();
        this.visitedRoomIds.add(currentRoomId);
    }
}

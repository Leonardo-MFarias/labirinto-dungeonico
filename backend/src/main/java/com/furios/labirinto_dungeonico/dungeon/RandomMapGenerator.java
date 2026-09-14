package com.furios.labirinto_dungeonico.dungeon;

import org.springframework.stereotype.Service;

@Service
public class RandomMapGenerator implements MapGenerator {

    @Override
    public DungeonMap generate(long seed, int width, int height) {
        // TODO: implementar o autômato celular real:
        //   1. preencher a grade width×height aleatoriamente (piso/parede) com uma seed dada;
        //   2. suavizar por N iterações (regra de vizinhança, ex.: B678/S345678);
        //   3. isolar a maior região andável conectada (flood fill) e descartar o resto como WALL;
        //   4. escolher ENTRANCE/EXIT dentro dessa região e classificar o restante em
        //      EMPTY/LOOT/ENEMY;
        //   5. para cada célula andável, preencher connectedRoomIds com os vizinhos ortogonais
        //      também andáveis.
        String entranceId = "0,0";
        DungeonMap map = new DungeonMap(String.valueOf(seed), entranceId, width, height);
        Room entrance = new Room(entranceId, RoomType.ENTRANCE, 0, 0);
        map.rooms().put(entrance.id(), entrance);
        return map;
    }
}

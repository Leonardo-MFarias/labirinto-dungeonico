package com.furios.labirinto_dungeonico.dungeon;

public interface MapGenerator {

    /**
     * Gera uma masmorra a partir de uma grade width × height, usando um autômato celular
     * (preenchimento aleatório ponderado + iterações de suavização) para decidir quais
     * células são andáveis e quais são WALL. A quantidade final de salas andáveis é
     * emergente do algoritmo, não um parâmetro de entrada (RF-10).
     */
    DungeonMap generate(long seed, int width, int height);
}

package com.furios.labirinto_dungeonico.dungeon;

import org.springframework.stereotype.Service;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Random;

/**
 * Gera a masmorra via autômato celular. Parâmetros de balanceamento (RNF-16 pede que residam
 * fora do fonte; mantidos aqui como constantes por ora — ver Q-06 em docs/requisitos.md):
 * <ul>
 *   <li>{@link #INITIAL_WALL_PROBABILITY}: chance de uma célula nascer parede no preenchimento
 *       aleatório inicial;</li>
 *   <li>{@link #SMOOTHING_ITERATIONS}: quantas vezes a regra de vizinhança B678/S345678
 *       (vizinhança de Moore, 8 células) é aplicada — nasce parede com 6+ vizinhas-parede,
 *       sobrevive como parede com 3+ vizinhas-parede;</li>
 *   <li>{@link #MIN_WALKABLE_RATIO}: fração mínima da grade que a maior região conectada deve
 *       ocupar; abaixo disso a geração é repetida com uma seed derivada (determinística).</li>
 * </ul>
 * A borda da grade é sempre parede, para que a região andável nunca toque a beirada do mapa.
 */
@Service
public class RandomMapGenerator implements MapGenerator {

    private static final double INITIAL_WALL_PROBABILITY = 0.45;
    private static final int SMOOTHING_ITERATIONS = 4;
    private static final int BIRTH_THRESHOLD = 6;
    private static final int SURVIVAL_THRESHOLD = 3;
    private static final double MIN_WALKABLE_RATIO = 0.10;
    private static final int MAX_GENERATION_ATTEMPTS = 10;

    private static final double LOOT_WEIGHT = 0.20;
    private static final double ENEMY_WEIGHT = 0.30;

    @Override
    public DungeonMap generate(long seed, int width, int height) {
        boolean[][] wall = null;
        List<int[]> region = null;

        for (int attempt = 0; attempt < MAX_GENERATION_ATTEMPTS; attempt++) {
            Random random = new Random(seed + attempt);
            wall = fillRandomly(width, height, random);
            for (int i = 0; i < SMOOTHING_ITERATIONS; i++) {
                wall = smooth(wall, width, height);
            }
            region = largestWalkableRegion(wall, width, height);
            if (region.size() >= width * height * MIN_WALKABLE_RATIO) {
                break;
            }
        }

        return buildMap(seed, width, height, wall, region);
    }

    private boolean[][] fillRandomly(int width, int height, Random random) {
        boolean[][] wall = new boolean[width][height];
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                wall[x][y] = isBorder(x, y, width, height) || random.nextDouble() < INITIAL_WALL_PROBABILITY;
            }
        }
        return wall;
    }

    private boolean[][] smooth(boolean[][] wall, int width, int height) {
        boolean[][] next = new boolean[width][height];
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                if (isBorder(x, y, width, height)) {
                    next[x][y] = true;
                    continue;
                }
                int wallNeighbors = countWallNeighbors(wall, width, height, x, y);
                next[x][y] = wall[x][y]
                        ? wallNeighbors >= SURVIVAL_THRESHOLD
                        : wallNeighbors >= BIRTH_THRESHOLD;
            }
        }
        return next;
    }

    private int countWallNeighbors(boolean[][] wall, int width, int height, int x, int y) {
        int count = 0;
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) {
                    continue;
                }
                int nx = x + dx;
                int ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= width || ny >= height || wall[nx][ny]) {
                    count++;
                }
            }
        }
        return count;
    }

    private boolean isBorder(int x, int y, int width, int height) {
        return x == 0 || y == 0 || x == width - 1 || y == height - 1;
    }

    /** Flood fill (adjacência ortogonal) para encontrar a maior região de células andáveis. */
    private List<int[]> largestWalkableRegion(boolean[][] wall, int width, int height) {
        boolean[][] visited = new boolean[width][height];
        List<int[]> largest = new ArrayList<>();

        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                if (wall[x][y] || visited[x][y]) {
                    continue;
                }
                List<int[]> region = floodFill(wall, visited, width, height, x, y);
                if (region.size() > largest.size()) {
                    largest = region;
                }
            }
        }
        return largest;
    }

    private List<int[]> floodFill(boolean[][] wall, boolean[][] visited, int width, int height, int startX, int startY) {
        List<int[]> region = new ArrayList<>();
        Deque<int[]> queue = new ArrayDeque<>();
        queue.add(new int[]{startX, startY});
        visited[startX][startY] = true;

        int[] dxs = {0, 0, -1, 1};
        int[] dys = {-1, 1, 0, 0};

        while (!queue.isEmpty()) {
            int[] cell = queue.poll();
            region.add(cell);
            for (int i = 0; i < 4; i++) {
                int nx = cell[0] + dxs[i];
                int ny = cell[1] + dys[i];
                if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
                    continue;
                }
                if (wall[nx][ny] || visited[nx][ny]) {
                    continue;
                }
                visited[nx][ny] = true;
                queue.add(new int[]{nx, ny});
            }
        }
        return region;
    }

    private DungeonMap buildMap(long seed, int width, int height, boolean[][] wall, List<int[]> region) {
        boolean[][] walkable = new boolean[width][height];
        for (int[] cell : region) {
            walkable[cell[0]][cell[1]] = true;
        }

        Random random = new Random(seed);
        int[] entranceCell = region.get(random.nextInt(region.size()));
        // Sala mais distante da entrada por caminho andável (BFS), maximizando a exploração
        // necessária para alcançar a saída.
        int[] exitCell = farthestCell(walkable, width, height, entranceCell);

        String entranceId = idOf(entranceCell[0], entranceCell[1]);
        DungeonMap map = new DungeonMap(String.valueOf(seed), entranceId, width, height);

        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                RoomType type = roomTypeFor(x, y, walkable, entranceCell, exitCell, random);
                Room room = new Room(idOf(x, y), type, x, y);
                map.rooms().put(room.id(), room);
            }
        }

        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                if (!walkable[x][y]) {
                    continue;
                }
                Room room = map.rooms().get(idOf(x, y));
                addIfWalkable(room, walkable, width, height, x - 1, y, map);
                addIfWalkable(room, walkable, width, height, x + 1, y, map);
                addIfWalkable(room, walkable, width, height, x, y - 1, map);
                addIfWalkable(room, walkable, width, height, x, y + 1, map);
            }
        }

        return map;
    }

    private RoomType roomTypeFor(int x, int y, boolean[][] walkable, int[] entranceCell, int[] exitCell, Random random) {
        if (!walkable[x][y]) {
            return RoomType.WALL;
        }
        if (x == entranceCell[0] && y == entranceCell[1]) {
            return RoomType.ENTRANCE;
        }
        if (x == exitCell[0] && y == exitCell[1]) {
            return RoomType.EXIT;
        }
        double roll = random.nextDouble();
        if (roll < ENEMY_WEIGHT) {
            return RoomType.ENEMY;
        }
        if (roll < ENEMY_WEIGHT + LOOT_WEIGHT) {
            return RoomType.LOOT;
        }
        return RoomType.EMPTY;
    }

    private void addIfWalkable(Room room, boolean[][] walkable, int width, int height, int nx, int ny, DungeonMap map) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height || !walkable[nx][ny]) {
            return;
        }
        room.connectedRoomIds().add(idOf(nx, ny));
    }

    /** BFS a partir de {@code from}, retorna a célula andável mais distante (aproxima o diâmetro da região). */
    private int[] farthestCell(boolean[][] walkable, int width, int height, int[] from) {
        boolean[][] visited = new boolean[width][height];
        Deque<int[]> queue = new ArrayDeque<>();
        queue.add(from);
        visited[from[0]][from[1]] = true;
        int[] dxs = {0, 0, -1, 1};
        int[] dys = {-1, 1, 0, 0};
        int[] last = from;

        while (!queue.isEmpty()) {
            int[] cell = queue.poll();
            last = cell;
            for (int i = 0; i < 4; i++) {
                int nx = cell[0] + dxs[i];
                int ny = cell[1] + dys[i];
                if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
                    continue;
                }
                if (!walkable[nx][ny] || visited[nx][ny]) {
                    continue;
                }
                visited[nx][ny] = true;
                queue.add(new int[]{nx, ny});
            }
        }
        return last;
    }

    private String idOf(int x, int y) {
        return x + "," + y;
    }
}

package com.furios.labirinto_dungeonico.api.controller;

import com.furios.labirinto_dungeonico.dungeon.DungeonMap;
import com.furios.labirinto_dungeonico.dungeon.MapGenerator;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DungeonController {

    private final MapGenerator mapGenerator;

    public DungeonController(MapGenerator mapGenerator) {
        this.mapGenerator = mapGenerator;
    }

    @PostMapping("/api/dungeon/generate")
    public DungeonMap generate(
            @RequestParam(defaultValue = "40") int width,
            @RequestParam(defaultValue = "25") int height,
            @RequestParam(required = false) Long seed) {
        long effectiveSeed = seed != null ? seed : System.currentTimeMillis();
        return mapGenerator.generate(effectiveSeed, width, height);
    }
}

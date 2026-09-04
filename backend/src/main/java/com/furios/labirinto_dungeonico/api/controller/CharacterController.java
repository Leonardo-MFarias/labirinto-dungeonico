package com.furios.labirinto_dungeonico.api.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CharacterController {

    // TODO: expor criação e consulta de personagem via SessionService
    @GetMapping("/api/character/ping")
    public String ping() {
        return "character-module-ready";
    }
}

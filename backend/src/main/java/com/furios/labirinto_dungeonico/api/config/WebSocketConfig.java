package com.furios.labirinto_dungeonico.api.config;

import com.furios.labirinto_dungeonico.api.websocket.CombatSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final CombatSocketHandler combatSocketHandler;

    public WebSocketConfig(CombatSocketHandler combatSocketHandler) {
        this.combatSocketHandler = combatSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(combatSocketHandler, "/ws/combat").setAllowedOrigins("*");
    }
}

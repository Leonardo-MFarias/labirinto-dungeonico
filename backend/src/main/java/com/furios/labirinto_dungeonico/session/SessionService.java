package com.furios.labirinto_dungeonico.session;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class SessionService {

    // TODO: substituir por persistência real (banco de dados) quando o save/load for implementado
    private final Map<String, GameSession> sessions = new ConcurrentHashMap<>();

    public GameSession save(GameSession session) {
        sessions.put(session.id(), session);
        return session;
    }

    public Optional<GameSession> find(String id) {
        return Optional.ofNullable(sessions.get(id));
    }
}

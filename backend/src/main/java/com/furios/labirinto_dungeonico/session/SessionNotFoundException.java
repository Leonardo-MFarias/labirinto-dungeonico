package com.furios.labirinto_dungeonico.session;

public class SessionNotFoundException extends RuntimeException {

    public SessionNotFoundException(String sessionId) {
        super("Sessão não encontrada: " + sessionId);
    }
}

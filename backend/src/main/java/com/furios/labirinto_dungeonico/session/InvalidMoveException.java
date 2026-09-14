package com.furios.labirinto_dungeonico.session;

/** RN-15: movimento recusado por falta de conexão direta entre as salas. */
public class InvalidMoveException extends RuntimeException {

    public InvalidMoveException(String message) {
        super(message);
    }
}

package com.furios.labirinto_dungeonico.session;

/** RF-19: recusado por o personagem não estar na sala EXIT do andar atual. */
public class InvalidDescendException extends RuntimeException {

    public InvalidDescendException(String message) {
        super(message);
    }
}

package com.furios.labirinto_dungeonico.character;

/** RN-24: item não encontrado, categoria incompatível com o slot pedido, ou slot inválido. */
public class InvalidEquipException extends RuntimeException {

    public InvalidEquipException(String message) {
        super(message);
    }
}

import 'item.dart';

enum RoomType { entrance, empty, loot, enemy, exit, wall }

/// Uma célula da grade do autômato celular. Toda posição (x, y) do
/// [DungeonMap] tem uma [Room] correspondente, inclusive as do tipo
/// [RoomType.wall] — não há "buracos" na grade.
class Room {
  const Room({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.items,
    required this.connectedRoomIds,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        type: RoomType.values.byName((json['type'] as String).toLowerCase()),
        x: json['x'] as int,
        y: json['y'] as int,
        items: (json['items'] as List)
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        connectedRoomIds: (json['connectedRoomIds'] as List)
            .map((e) => e as String)
            .toList(),
      );

  final String id;
  final RoomType type;

  /// Coluna da célula na grade (0-indexada, cresce para a direita).
  final int x;

  /// Linha da célula na grade (0-indexada, cresce para baixo).
  final int y;
  final List<Item> items;

  /// Ids das salas andáveis ortogonalmente adjacentes. Sempre vazio para
  /// salas [RoomType.wall].
  final List<String> connectedRoomIds;
}

import 'item.dart';

enum RoomType { entrance, empty, loot, enemy, exit }

class Room {
  const Room({
    required this.id,
    required this.type,
    required this.items,
    required this.connectedRoomIds,
  });

  final String id;
  final RoomType type;
  final List<Item> items;
  final List<String> connectedRoomIds;
}

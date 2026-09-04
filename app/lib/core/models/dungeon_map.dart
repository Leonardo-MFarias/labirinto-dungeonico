import 'room.dart';

class DungeonMap {
  const DungeonMap({
    required this.seed,
    required this.rooms,
    required this.entranceRoomId,
  });

  final String seed;
  final Map<String, Room> rooms;
  final String entranceRoomId;
}

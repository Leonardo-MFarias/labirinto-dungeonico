import 'room.dart';

class DungeonMap {
  const DungeonMap({
    required this.seed,
    required this.width,
    required this.height,
    required this.rooms,
    required this.entranceRoomId,
  });

  factory DungeonMap.fromJson(Map<String, dynamic> json) => DungeonMap(
        seed: json['seed'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        entranceRoomId: json['entranceRoomId'] as String,
        rooms: (json['rooms'] as Map).map(
          (key, value) => MapEntry(
            key as String,
            Room.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );

  final String seed;

  /// Largura da grade do autômato celular, em número de células.
  final int width;

  /// Altura da grade do autômato celular, em número de células.
  final int height;

  /// Todas as células da grade (width × height), indexadas por "{x},{y}",
  /// inclusive as do tipo [RoomType.wall].
  final Map<String, Room> rooms;
  final String entranceRoomId;

  /// Busca a sala na posição (x, y), ou `null` se estiver fora da grade.
  Room? roomAt(int x, int y) => rooms['$x,$y'];
}

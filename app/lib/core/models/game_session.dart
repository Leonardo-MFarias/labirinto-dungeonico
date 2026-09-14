import 'character.dart';
import 'dungeon_map.dart';

class GameSession {
  const GameSession({
    required this.id,
    required this.character,
    required this.dungeonMap,
    required this.currentRoomId,
    required this.visitedRoomIds,
    required this.depth,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
        id: json['id'] as String,
        character: Character.fromJson(json['character'] as Map<String, dynamic>),
        dungeonMap: DungeonMap.fromJson(json['dungeonMap'] as Map<String, dynamic>),
        currentRoomId: json['currentRoomId'] as String,
        visitedRoomIds: (json['visitedRoomIds'] as List).map((e) => e as String).toSet(),
        depth: json['depth'] as int,
      );

  final String id;
  final Character character;
  final DungeonMap dungeonMap;
  final String currentRoomId;
  final Set<String> visitedRoomIds;
  final int depth;
}

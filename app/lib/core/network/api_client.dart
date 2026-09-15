import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/character.dart';
import '../models/game_session.dart';
import '../models/move_response.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> generateDungeon({
    int width = 40,
    int height = 25,
    int? seed,
  }) async {
    // TODO: tratar erros de rede e status codes diferentes de 200
    final query = {
      'width': '$width',
      'height': '$height',
      if (seed != null) 'seed': '$seed',
    };
    final response = await _client.post(
      Uri.parse('$baseUrl/api/dungeon/generate').replace(queryParameters: query),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<GameSession> createSession({
    required String name,
    required GameMode mode,
    int? seed,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'mode': mode.name.toUpperCase(),
        if (seed != null) 'seed': seed,
      }),
    );
    return GameSession.fromJson(_decode(response));
  }

  Future<GameSession> getSession(String sessionId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/session/$sessionId'));
    return GameSession.fromJson(_decode(response));
  }

  Future<Character> getCharacter(String sessionId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/session/$sessionId/character'));
    return Character.fromJson(_decode(response));
  }

  Future<MoveResponse> move(String sessionId, String roomId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/session/$sessionId/move'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'roomId': roomId}),
    );
    return MoveResponse.fromJson(_decode(response));
  }

  Future<GameSession> loot(String sessionId) async {
    final response = await _client.post(Uri.parse('$baseUrl/api/session/$sessionId/loot'));
    return GameSession.fromJson(_decode(response));
  }

  /// RF-19: avança para o próximo andar. Só válido quando o personagem está
  /// na sala de saída do andar atual (400 caso contrário).
  Future<GameSession> descend(String sessionId) async {
    final response = await _client.post(Uri.parse('$baseUrl/api/session/$sessionId/descend'));
    return GameSession.fromJson(_decode(response));
  }

  /// RF-07: distribui um ponto de atributo não gasto. `attribute` é um dos
  /// nomes em SCREAMING_SNAKE_CASE de `AttributeType` no backend (ex.:
  /// "STRENGTH"). 400 se não houver pontos disponíveis.
  Future<GameSession> allocateAttribute(String sessionId, String attribute) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/session/$sessionId/character/attributes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'attribute': attribute}),
    );
    return GameSession.fromJson(_decode(response));
  }

  Future<GameSession> equip(String sessionId, {required String itemId, required String slot}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/session/$sessionId/equip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'itemId': itemId, 'slot': slot}),
    );
    return GameSession.fromJson(_decode(response));
  }

  Future<GameSession> unequip(String sessionId, String slot) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/session/$sessionId/unequip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'slot': slot}),
    );
    return GameSession.fromJson(_decode(response));
  }

  /// Decodifica o corpo como JSON, ou lança [ApiException] se o status não
  /// for 2xx (RNF-06) — usa a mensagem de `{"error": "..."}` quando o
  /// backend a devolve.
  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['error'] as String? ?? 'Erro inesperado (${response.statusCode}).';
      throw ApiException(response.statusCode, message);
    }
    return body;
  }
}

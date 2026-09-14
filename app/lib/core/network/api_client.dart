import 'dart:convert';

import 'package:http/http.dart' as http;

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
}

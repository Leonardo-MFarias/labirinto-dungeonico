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
  }) async {
    // TODO: tratar erros de rede e status codes diferentes de 200
    final response = await _client.post(
      Uri.parse('$baseUrl/api/dungeon/generate?width=$width&height=$height'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

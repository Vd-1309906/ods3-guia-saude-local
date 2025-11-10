import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/campanha_saude_model.dart';
import '../services/api_service.dart';

extension ApiServiceCampanhas on ApiService {
  Future<List<CampanhaSaude>> getCampanhasSaude() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/campanhas');
      
  debugPrint('Chamando API de campanhas: $uri');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => CampanhaSaude.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar campanhas (Status ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Erro ao carregar campanhas: $e');
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/posto_saude_model.dart';

class ApiService {
  // ATENÇÃO: Use este IP para o emulador Android acessar o localhost da sua máquina.
  // Para o simulador iOS, use 'http://localhost:8000'.
  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<List<PostoSaude>> getPostosDeSaude() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/unidades/demas'));

      if (response.statusCode == 200) {
        // Decodifica a resposta JSON (que é uma lista)
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        
        // Converte a lista de JSONs em uma lista de objetos PostoSaude
        return jsonList.map((json) => PostoSaude.fromJson(json)).toList();
      } else {
        // Se a resposta não for OK, lança um erro.
        throw Exception('Falha ao carregar os dados dos postos de saúde');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }
}
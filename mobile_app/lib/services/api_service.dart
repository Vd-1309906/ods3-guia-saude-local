import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/posto_saude_model.dart';

class ApiService {
  // ATENÇÃO: Use este IP para o emulador Android acessar o localhost da sua máquina.
  // Para o simulador iOS, use 'http://localhost:8000'.
static const String _baseUrl = 'http://192.168.18.211:8000'; // <-- VERIFIQUE SEU IP REAL AQUI

Future<List<PostoSaude>> getPostosDeSaude(double latitude, double longitude) async {
  try {
    // Constroi a URL com os query parameters
    final uri = Uri.parse('$_baseUrl/unidades/demas').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );

    print('Chamando API: $uri'); // Ótimo para depurar

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
      return jsonList.map((json) => PostoSaude.fromJson(json)).toList();
    } else {
      // Agora podemos ver o erro 422 aqui se algo ainda estiver errado
      throw Exception('Falha ao carregar os dados (Status ${response.statusCode})');
    }
  } catch (e) {
    throw Exception('Erro de conexão: $e');
  }
}
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/posto_saude_model.dart';

class ApiService {
  // Base URL para chamadas ao backend local (mantida para compatibilidade
  // com extensões/arquivos que ainda referenciam ApiService.baseUrl).
  // Ajuste conforme sua rede de desenvolvimento quando necessário.
  static const String baseUrl = 'http://192.168.18.211:8000';

  // A API pública de UBS (reposicionada conforme solicitação). Mantemos
  // a assinatura getPostosDeSaude(lat, lon) por compatibilidade com o app,
  // mas o endpoint público não aceita lat/lon — filtragem por distância
  // continuará sendo feita localmente pelo app.
  static const String postosPublicUrl = 'https://apidadosabertos.saude.gov.br/assistencia-a-saude/unidade-basicas-de-saude?limit=600&offset=0';
  // CNES endpoints
  static const String cnesTiposUrl = 'https://apidadosabertos.saude.gov.br/cnes/tipounidades';
  static const String cnesEstabelecimentosUrl = 'https://apidadosabertos.saude.gov.br/cnes/estabelecimentos';

  Future<List<PostoSaude>> getPostosDeSaude(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(postosPublicUrl);
  debugPrint('Chamando API pública de UBS: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));

        // O formato esperado tem um array em 'ubs'
        final List<dynamic> ubsList = (decoded['ubs'] as List<dynamic>?) ?? [];

        return ubsList.map((item) {
          // Normalizar campos do JSON para o formato do PostoSaude
          final Map<String, dynamic> j = item as Map<String, dynamic>;

          // identificar id: usa 'cnes' quando disponível
          final id = (j['cnes'] ?? j['id'] ?? '').toString();

          final nome = (j['nome'] ?? '').toString();

          // monta endereço com logradouro + bairro quando disponível
          final logradouro = (j['logradouro'] ?? '').toString();
          final bairro = (j['bairro'] ?? '').toString();
          final endereco = ((logradouro.isNotEmpty) ? logradouro : '') + ((bairro.isNotEmpty) ? ' - $bairro' : '');

          // latitude/longitude no JSON podem vir como strings com vírgula
          double parseCoord(dynamic v) {
            if (v == null) return 0.0;
            if (v is num) return v.toDouble();
            final s = v.toString().replaceAll(',', '.').trim();
            return double.tryParse(s) ?? 0.0;
          }

          final lat = parseCoord(j['latitude']);
          final lon = parseCoord(j['longitude']);

          return PostoSaude(
            id: id.isNotEmpty ? id : 'id_desconhecido_${DateTime.now().millisecondsSinceEpoch}',
            nome: nome.isNotEmpty ? nome : 'Nome não informado',
            endereco: endereco.isNotEmpty ? endereco : 'Endereço não informado',
            latitude: lat,
            longitude: lon,
          );
        }).toList();
      } else {
        throw Exception('Falha ao carregar dados de UBS (Status ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Erro ao consultar API de UBS: $e');
    }
  }

  /// Retorna a lista bruta de UBS como mapas com campos úteis para UI (inclui
  /// `uf`/`municipio` quando presentes no JSON). Útil quando precisamos exibir
  /// informações adicionais sem alterar o modelo `PostoSaude`.
  Future<List<Map<String, dynamic>>> getPostosDeSaudeRaw(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(postosPublicUrl);
      debugPrint('Chamando API pública de UBS (raw): $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> ubsList = (decoded['ubs'] as List<dynamic>?) ?? [];

        return ubsList.map((item) {
          final Map<String, dynamic> j = item as Map<String, dynamic>;

          double parseCoord(dynamic v) {
            if (v == null) return 0.0;
            if (v is num) return v.toDouble();
            final s = v.toString().replaceAll(',', '.').trim();
            return double.tryParse(s) ?? 0.0;
          }

          final id = (j['cnes'] ?? j['id'] ?? '').toString();
          final nome = (j['nome'] ?? '').toString();
          final logradouro = (j['logradouro'] ?? '').toString();
          final bairro = (j['bairro'] ?? '').toString();
          final endereco = ((logradouro.isNotEmpty) ? logradouro : '') + ((bairro.isNotEmpty) ? ' - $bairro' : '');
          final lat = parseCoord(j['latitude']);
          final lon = parseCoord(j['longitude']);

          return {
            'id': id.isNotEmpty ? id : 'id_desconhecido_${DateTime.now().millisecondsSinceEpoch}',
            'nome': nome.isNotEmpty ? nome : 'Nome não informado',
            'endereco': endereco.isNotEmpty ? endereco : (j['endereco'] ?? 'Endereço não informado'),
            'latitude': lat,
            'longitude': lon,
            // campos adicionais se disponíveis
            'municipio': j['municipio'] ?? j['cidade'] ?? '',
            'uf': j['uf'] ?? j['estado'] ?? '',
          };
        }).toList();
      } else {
        throw Exception('Falha ao carregar dados de UBS (Status ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Erro ao consultar API de UBS (raw): $e');
    }
  }

  /// Buscar lista de tipos de unidade CNES
  Future<List<Map<String, dynamic>>> fetchTiposUnidade() async {
    try {
      final uri = Uri.parse(cnesTiposUrl);
      debugPrint('Chamando API CNES - tipos de unidade: $uri');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw Exception('Falha ao buscar tipos CNES: ${resp.statusCode}');
      final Map<String, dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      final List<dynamic> tipos = data['tipos_unidade'] ?? [];
      return tipos.map((t) => {
        'codigo_tipo_unidade': t['codigo_tipo_unidade'],
        'descricao_tipo_unidade': t['descricao_tipo_unidade'],
      }).toList();
    } catch (e) {
      throw Exception('Erro ao buscar tipos CNES: $e');
    }
  }

  /// Buscar estabelecimentos CNES filtrando por tipo/UF/municipio
  Future<List<Map<String, dynamic>>> fetchEstabelecimentosPorTipo({
    required int codigoTipoUnidade,
    int? codigoUf,
    int? codigoMunicipio,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'codigo_tipo_unidade': codigoTipoUnidade.toString(),
        'status': '1',
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (codigoUf != null) params['codigo_uf'] = codigoUf.toString();
      if (codigoMunicipio != null) params['codigo_municipio'] = codigoMunicipio.toString();

      final uri = Uri.parse(cnesEstabelecimentosUrl).replace(queryParameters: params);
      debugPrint('Chamando API CNES - estabelecimentos: $uri');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw Exception('Falha ao buscar estabelecimentos CNES: ${resp.statusCode}');
      final Map<String, dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      final List<dynamic> itens = data['estabelecimentos'] ?? [];

      return itens.map((item) {
        final Map<String, dynamic> j = item as Map<String, dynamic>;
        double parseCoord(dynamic v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          final s = v.toString().replaceAll(',', '.').trim();
          return double.tryParse(s) ?? 0.0;
        }

        final id = j['codigo_cnes']?.toString() ?? j['codigo_estabelecimento_saude']?.toString() ?? '';
        final nome = (j['nome_fantasia'] ?? j['nome_razao_social'] ?? '').toString();
        final endereco = '${j['endereco_estabelecimento'] ?? ''}, ${j['numero_estabelecimento'] ?? ''} - ${j['bairro_estabelecimento'] ?? ''}';
        final lat = parseCoord(j['latitude_estabelecimento_decimo_grau']);
        final lon = parseCoord(j['longitude_estabelecimento_decimo_grau']);

        return {
          'id': id,
          'nome': nome.isNotEmpty ? nome : 'Nome não informado',
          'endereco': endereco.isNotEmpty ? endereco : (j['endereco'] ?? 'Endereço não informado'),
          'latitude': lat,
          'longitude': lon,
          'municipio': j['codigo_municipio'] ?? j['nome_municipio_estabelecimento'] ?? '',
          'uf': j['codigo_uf'] ?? j['sigla_uf_estabelecimento'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Erro ao buscar estabelecimentos CNES: $e');
    }
  }

  /// Consulta o backend local para converter coordenadas em códigos IBGE/UF.
  Future<Map<String, dynamic>> getUfMunicipioCodesFromCoords(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('$baseUrl/unidades/codes-by-coords?lat=$latitude&lon=$longitude');
      debugPrint('Chamando backend para obter códigos por coords: $uri');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw Exception('Falha ao obter códigos do backend: ${resp.statusCode}');
      final Map<String, dynamic> data = json.decode(resp.body);
      return data;
    } catch (e) {
      throw Exception('Erro ao obter códigos por coordenadas: $e');
    }
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/posto_saude_model.dart';

class ApiService {
  // Base URL para chamadas ao backend local (mantida para compatibilidade)
  // Ajuste conforme sua rede de desenvolvimento quando necessário.
  static const String baseUrl = 'http://192.168.18.210:8000';

  // A API pública de UBS
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
        final List<dynamic> ubsList = (decoded['ubs'] as List<dynamic>?) ?? [];

        return ubsList.map((item) {
          final Map<String, dynamic> j = item as Map<String, dynamic>;
          final id = (j['cnes'] ?? j['id'] ?? '').toString();
          final nome = (j['nome'] ?? '').toString();
          final logradouro = (j['logradouro'] ?? '').toString();
          final bairro = (j['bairro'] ?? '').toString();
          final endereco = ((logradouro.isNotEmpty) ? logradouro : '') + ((bairro.isNotEmpty) ? ' - $bairro' : '');

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

  /// Retorna a lista bruta de UBS como mapas com campos úteis para UI
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
  /// **AGORA COM PAGINAÇÃO AUTOMÁTICA (Busca até 10 itens ou 10 segundos)**
  Future<List<Map<String, dynamic>>> fetchEstabelecimentosPorTipo({
    required int codigoTipoUnidade,
    int? codigoUf,
    int? codigoMunicipio,
    int limit = 100,
    int offset = 0,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<Map<String, dynamic>> allEstabelecimentos = [];
    int currentOffset = offset;
    bool keepFetching = true;

    debugPrint('--- Iniciando busca iterativa CNES (Meta: 10 locais ou 10s) ---');

    while (keepFetching) {
      // Critérios de Parada
      if (allEstabelecimentos.length >= 10) {
        debugPrint('Meta de 10 locais atingida.');
        break;
      }
      if (stopwatch.elapsed.inSeconds >= 10) {
        debugPrint('Tempo limite de 10s atingido.');
        break;
      }

      // Montagem da URL com o offset dinâmico
      final params = <String, dynamic>{
        'codigo_tipo_unidade': codigoTipoUnidade.toString(),
        'status': '1',
        'limit': limit.toString(),
        'offset': currentOffset.toString(),
      };
      if (codigoUf != null) params['codigo_uf'] = codigoUf.toString();
      if (codigoMunicipio != null) params['codigo_municipio'] = codigoMunicipio.toString();

      final uri = Uri.parse(cnesEstabelecimentosUrl).replace(queryParameters: params);
      debugPrint('Chamando API CNES (offset $currentOffset): $uri');

      try {
        final resp = await http.get(uri);
        
        if (resp.statusCode != 200) {
          debugPrint('Falha na requisição (Status ${resp.statusCode}). Parando busca.');
          break; // Se der erro na API, paramos para não ficar tentando eternamente
        }

        final Map<String, dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
        final List<dynamic> itens = data['estabelecimentos'] ?? [];

        // Se a lista vier vazia, acabaram os dados na API
        if (itens.isEmpty) {
          keepFetching = false;
          break;
        }

        // Processa os itens desta página
        for (var item in itens) {
          final Map<String, dynamic> j = item as Map<String, dynamic>;
          
          double parseCoord(dynamic v) {
            if (v == null) return 0.0;
            if (v is num) return v.toDouble();
            final s = v.toString().replaceAll(',', '.').trim();
            return double.tryParse(s) ?? 0.0;
          }

          final lat = parseCoord(j['latitude_estabelecimento_decimo_grau']);
          final lon = parseCoord(j['longitude_estabelecimento_decimo_grau']);

          // Só adicionamos se tiver coordenadas válidas (opcional, mas recomendado para o mapa)
          if (lat != 0.0 && lon != 0.0) {
            final id = j['codigo_cnes']?.toString() ?? j['codigo_estabelecimento_saude']?.toString() ?? '';
            final nome = (j['nome_fantasia'] ?? j['nome_razao_social'] ?? '').toString();
            final endereco = '${j['endereco_estabelecimento'] ?? ''}, ${j['numero_estabelecimento'] ?? ''} - ${j['bairro_estabelecimento'] ?? ''}';

            allEstabelecimentos.add({
              'id': id,
              'nome': nome.isNotEmpty ? nome : 'Nome não informado',
              'endereco': endereco.isNotEmpty ? endereco : (j['endereco'] ?? 'Endereço não informado'),
              'latitude': lat,
              'longitude': lon,
              'municipio': j['codigo_municipio'] ?? j['nome_municipio_estabelecimento'] ?? '',
              'uf': j['codigo_uf'] ?? j['sigla_uf_estabelecimento'] ?? '',
            });
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar estabelecimentos CNES: $e');
        break; // Para o loop em caso de exceção
      }

      // Incrementa o offset para a próxima página
      currentOffset += limit;
    }

    stopwatch.stop();
    debugPrint('--- Busca finalizada. Total encontrados: ${allEstabelecimentos.length} ---');
    
    return allEstabelecimentos;
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
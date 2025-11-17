import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EstabelecimentoVacina {
  final String nome;
  final String codigoCnes;
  final String municipio;
  final String uf;

  EstabelecimentoVacina({
    required this.nome,
    required this.codigoCnes,
    required this.municipio,
    required this.uf,
  });
}

class GrupoVacina {
  final String codigo;
  final String descricao;
  final List<EstabelecimentoVacina> estabelecimentos;

  GrupoVacina({
    required this.codigo,
    required this.descricao,
    required this.estabelecimentos,
  });
}

class VacinacaoService {
  
  // Função auxiliar para comparar strings ignorando acentos e caixa alta/baixa
  // Ex: "São Paulo" vira "SAO PAULO"
  String _normalize(String input) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    
    String str = input.toUpperCase();
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  // Busca iterativa filtrando pelo município
  Future<List<GrupoVacina>> fetchGruposPorVacina({
    int limit = 100, 
    int offset = 0,
    String? filtroMunicipio, // Novo parâmetro
    String? filtroUf,       // Novo parâmetro
  }) async {
    final int year = DateTime.now().year;
    
    final Stopwatch stopwatch = Stopwatch()..start();
    final Map<String, GrupoVacina> masterMap = {}; 
    final Set<String> locaisEncontrados = {}; 
    
    int currentOffset = offset;
    bool keepFetching = true;

    // Prepara os filtros normalizados
    final String? targetCity = filtroMunicipio != null ? _normalize(filtroMunicipio) : null;
    final String? targetUf = filtroUf?.toUpperCase();

    debugPrint('--- Iniciando busca de locais em: $targetCity/$targetUf (Meta: 10 locais ou 10s) ---');

    while (keepFetching) {
      // Condições de parada
      if (locaisEncontrados.length >= 10) {
        debugPrint('Meta atingida: ${locaisEncontrados.length} locais únicos encontrados no seu município.');
        break;
      }
      if (stopwatch.elapsed.inSeconds >= 10) {
        debugPrint('Tempo limite atingido (10s). Parando busca com o que foi encontrado.');
        break;
      }

      // A API retorna dados do BRASIL TODO. Nós baixamos e filtramos manualmente.
      // Usamos um limit maior (200) para tentar achar a cidade mais rápido.
      final int stepLimit = 200; 
      final uri = Uri.parse('https://apidadosabertos.saude.gov.br/vacinacao/doses-aplicadas-pni-$year?limit=$stepLimit&offset=$currentOffset');
      
      try {
        final resp = await http.get(uri);
        
        if (resp.statusCode != 200) {
          debugPrint('Erro na requisição (Status ${resp.statusCode}).');
        } else {
          final Map<String, dynamic> data = json.decode(resp.body);
          final List<dynamic> doses = data['doses_aplicadas_pni'] ?? [];

          if (doses.isEmpty) {
            keepFetching = false;
            break;
          }

          for (final item in doses) {
            // Dados do local na API
            final cidadeApi = _normalize((item['nome_municipio_estabelecimento'] ?? '').toString());
            final ufApi = (item['sigla_uf_estabelecimento'] ?? '').toString().toUpperCase();

            // --- LÓGICA DE FILTRO ---
            // Se passamos um município e ele não bate, PULA para o próximo item
            if (targetCity != null && cidadeApi != targetCity) continue;
            if (targetUf != null && ufApi != targetUf) continue;
            // -----------------------

            final codigo = (item['codigo_vacina'] ?? '').toString();
            final descricao = (item['descricao_vacina'] ?? codigo).toString();
            final cnes = (item['codigo_cnes_estabelecimento'] ?? '').toString();
            final nomeEst = (item['nome_razao_social_estabelecimento'] ?? '').toString();

            if (cnes.isEmpty || nomeEst.isEmpty) continue;

            final estabelecimento = EstabelecimentoVacina(
              nome: nomeEst,
              codigoCnes: cnes,
              municipio: (item['nome_municipio_estabelecimento'] ?? '').toString(),
              uf: ufApi,
            );

            locaisEncontrados.add(cnes);

            if (masterMap.containsKey(codigo)) {
              final list = masterMap[codigo]!.estabelecimentos;
              final exists = list.any((e) => e.codigoCnes == estabelecimento.codigoCnes);
              if (!exists) list.add(estabelecimento);
            } else {
              masterMap[codigo] = GrupoVacina(
                codigo: codigo, 
                descricao: descricao, 
                estabelecimentos: [estabelecimento]
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Erro de conexão: $e');
        break; 
      }

      currentOffset += stepLimit; // Pula para a próxima página
    }

    stopwatch.stop();
    debugPrint('--- Busca finalizada. Offset final: $currentOffset. Encontrados: ${locaisEncontrados.length} ---');

    return masterMap.values.toList()..sort((a, b) => a.descricao.compareTo(b.descricao));
  }
}
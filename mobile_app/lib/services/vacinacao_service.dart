import 'dart:convert';
import 'package:http/http.dart' as http;

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
  // Busca os registros de doses aplicadas do PNI para o ano atual
  // e agrupa por código de vacina.
  Future<List<GrupoVacina>> fetchGruposPorVacina({int limit = 600, int offset = 0}) async {
    final int year = DateTime.now().year;
    final uri = Uri.parse('https://apidadosabertos.saude.gov.br/vacinacao/doses-aplicadas-pni-$year?limit=$limit&offset=$offset');

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar dados de vacinação: ${resp.statusCode}');
    }

    final Map<String, dynamic> data = json.decode(resp.body);
    final List<dynamic> doses = data['doses_aplicadas_pni'] ?? [];

    // Agrupa por codigo_vacina
    final Map<String, GrupoVacina> map = {};

    for (final item in doses) {
      final codigo = (item['codigo_vacina'] ?? '').toString();
      final descricao = (item['descricao_vacina'] ?? codigo).toString();

      final estabelecimento = EstabelecimentoVacina(
        nome: (item['nome_razao_social_estabelecimento'] ?? '').toString(),
        codigoCnes: (item['codigo_cnes_estabelecimento'] ?? '').toString(),
        municipio: (item['nome_municipio_estabelecimento'] ?? '').toString(),
        uf: (item['sigla_uf_estabelecimento'] ?? '').toString(),
      );

      if (map.containsKey(codigo)) {
        // evita duplicatas por nome/cnes
        final list = map[codigo]!.estabelecimentos;
        final exists = list.any((e) => e.nome == estabelecimento.nome && e.codigoCnes == estabelecimento.codigoCnes);
        if (!exists) list.add(estabelecimento);
      } else {
        map[codigo] = GrupoVacina(codigo: codigo, descricao: descricao, estabelecimentos: [estabelecimento]);
      }
    }

    return map.values.toList()..sort((a, b) => a.descricao.compareTo(b.descricao));
  }
}

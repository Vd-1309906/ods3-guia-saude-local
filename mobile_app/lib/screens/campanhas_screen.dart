import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/vacinacao_service.dart';
import '../services/app_settings.dart';
import 'package:geolocator/geolocator.dart';

class CampanhasScreen extends StatefulWidget {
  const CampanhasScreen({super.key});

  @override
  State<CampanhasScreen> createState() => _CampanhasScreenState();
}

class _CampanhasScreenState extends State<CampanhasScreen> {
  final ApiService _apiService = ApiService();
  final VacinacaoService _vacinacaoService = VacinacaoService();
  List<GrupoVacina>? _gruposVacina;
  List<GrupoVacina>? _gruposOriginais; // guarda grupos não filtrados
  List<dynamic>? _todosPostos; // postos carregados para filtragem (mapa simple)
  final _raioController = TextEditingController(text: AppSettings.searchRadiusKm.toString());
  double _raioEmKm = AppSettings.searchRadiusKm;
  bool _loading = true;
  String? _error;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _carregarCampanhas();
  }

  Future<void> _carregarCampanhas() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final grupos = await _vacinacaoService.fetchGruposPorVacina(limit: 500, offset: 0);

      try {
        _userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (_) {
        _userPosition = null;
      }

      // Se conseguimos posição, carregamos postos locais para filtrar
      if (_userPosition != null) {
        try {
          _todosPostos = await _apiServiceGetPostos(_userPosition!.latitude, _userPosition!.longitude);
        } catch (_) {
          _todosPostos = [];
        }
      } else {
        _todosPostos = [];
      }

      // Guarda originais e aplica filtro inicial conforme raio
      _gruposOriginais = grupos;
      final filtered = _filtrarGruposPorRaio(grupos);

      setState(() {
        _gruposVacina = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar campanhas de vacinação: $e';
        _loading = false;
      });
    }
  }

  // Filtra as listas de estabelecimentos por postos próximos dentro do raio
  List<GrupoVacina> _filtrarGruposPorRaio(List<GrupoVacina> grupos) {
    if (_userPosition == null) return grupos;

    final double raioMetros = _raioEmKm * 1000;

    List<GrupoVacina> result = [];

    for (final g in grupos) {
      final List<EstabelecimentoVacina> matches = [];
      for (final est in g.estabelecimentos) {
        // verifica se existe algum posto que case por nome/cnes e esteja dentro do raio
        bool hasNearby = false;
        for (final posto in _todosPostos ?? []) {
          final nomePosto = (posto['nome'] ?? '').toString().toLowerCase();
          final nomeEst = est.nome.toLowerCase();
          final matchesName = nomePosto.contains(nomeEst) || nomeEst.contains(nomePosto);
          final matchesCnes = est.codigoCnes.isNotEmpty && (posto['id']?.toString() == est.codigoCnes);
          if (matchesName || matchesCnes) {
            final lat = (posto['latitude'] as double?) ?? 0.0;
            final lon = (posto['longitude'] as double?) ?? 0.0;
            if (lat == 0.0 && lon == 0.0) continue;
            final distancia = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, lat, lon);
            if (distancia <= raioMetros) {
              hasNearby = true;
              break;
            }
          }
        }
        if (hasNearby) matches.add(est);
      }
      if (matches.isNotEmpty) {
        result.add(GrupoVacina(codigo: g.codigo, descricao: g.descricao, estabelecimentos: matches));
      }
    }
    return result;
  }

  void _onRaioChanged(String value) {
    setState(() {
      _raioEmKm = double.tryParse(value) ?? _raioEmKm;
      AppSettings.searchRadiusKm = _raioEmKm;
      if (_gruposOriginais != null) {
        _gruposVacina = _filtrarGruposPorRaio(_gruposOriginais!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campanhas de Vacinação'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarCampanhas,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Always show the radius input at the top so the user can change it even when there are no groups
    final radiusField = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          const Expanded(child: Text('Raio (km):', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _raioController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                hintText: 'km',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              onChanged: _onRaioChanged,
            ),
          ),
        ],
      ),
    );

    // Content area below the radius field
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _carregarCampanhas, child: const Text('Tentar novamente')),
          ],
        ),
      );
    } else if (_gruposVacina == null || _gruposVacina!.isEmpty) {
      content = const Center(child: Text('Nenhuma campanha de vacinação encontrada'));
    } else {
      content = RefreshIndicator(
        onRefresh: _carregarCampanhas,
        child: ListView.builder(
          itemCount: _gruposVacina!.length,
          itemBuilder: (context, index) {
            final grupo = _gruposVacina![index];
            return _buildGrupoVacinaCard(grupo);
          },
        ),
      );
    }

    return Column(
      children: [
        radiusField,
        Expanded(child: content),
      ],
    );
  }

  Widget _buildGrupoVacinaCard(GrupoVacina grupo) {
    // Calcula postos correspondentes a este grupo dentro do raio
    final postosParaGrupo = _postosParaGrupo(grupo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(grupo.descricao.isNotEmpty ? grupo.descricao : grupo.codigo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Postos próximos: ${postosParaGrupo.length}'),
        leading: const Icon(Icons.health_and_safety, color: Colors.teal),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: postosParaGrupo.isNotEmpty
                  ? postosParaGrupo.map((posto) {
                      return ListTile(
                        title: Text(posto['nome'] ?? 'Nome desconhecido'),
                        subtitle: Text('${posto['endereco'] ?? ''}'),
                        leading: const Icon(Icons.local_hospital, color: Colors.red),
                        onTap: () {
                          // Move camera / highlight could be implemented in map screen; here we simply show details
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(posto['nome'] ?? 'Detalhes'),
                                content: Text('${posto['endereco'] ?? ''}\nID: ${posto['id'] ?? ''}\nEstado (UF): ${posto['uf'] ?? posto['municipio'] ?? ''}'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
                              ),
                            );
                          }
                        },
                      );
                    }).toList()
                  : [
                      const ListTile(
                        title: Text('Nenhum posto próximo encontrado para esta vacina.'),
                      )
                    ],
            ),
          ),
        ],
      ),
    );
  }

  // Retorna lista de postos (maps) que correspondem aos estabelecimentos do grupo
  List<Map<String, dynamic>> _postosParaGrupo(GrupoVacina grupo) {
    final List<Map<String, dynamic>> encontrados = [];
    if (_userPosition == null) return encontrados;
    final double raioMetros = _raioEmKm * 1000;
    final postos = _todosPostos ?? [];

    for (final est in grupo.estabelecimentos) {
      for (final posto in postos) {
        final nomePosto = (posto['nome'] ?? '').toString().toLowerCase();
        final nomeEst = est.nome.toLowerCase();
        final matchesName = nomePosto.contains(nomeEst) || nomeEst.contains(nomePosto);
        final matchesCnes = est.codigoCnes.isNotEmpty && (posto['id']?.toString() == est.codigoCnes);
        if (matchesName || matchesCnes) {
          final lat = (posto['latitude'] as double?) ?? 0.0;
          final lon = (posto['longitude'] as double?) ?? 0.0;
          if (lat == 0.0 && lon == 0.0) continue;
          final distancia = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, lat, lon);
          if (distancia <= raioMetros) {
            // evita duplicatas por id
            final id = posto['id']?.toString() ?? posto['nome']?.toString() ?? '';
            if (!encontrados.any((p) => (p['id']?.toString() ?? '') == id)) {
              encontrados.add(Map<String, dynamic>.from(posto as Map));
            }
          }
        }
      }
    }

    return encontrados;
  }

  

  // Helper: chama a API de postos (usa ApiService existente)
  Future<List<dynamic>> _apiServiceGetPostos(double lat, double lon) async {
    try {
      // Use raw version to get additional metadata (uf/municipio) when present
      final lista = await _apiService.getPostosDeSaudeRaw(lat, lon);
      return lista.map((p) => {
        'nome': p['nome'],
        'id': p['id'],
        'endereco': p['endereco'],
        'latitude': p['latitude'],
        'longitude': p['longitude'],
        'municipio': p['municipio'] ?? '',
        'uf': p['uf'] ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
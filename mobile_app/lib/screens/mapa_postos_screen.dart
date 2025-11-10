import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/posto_saude_model.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'package:geolocator/geolocator.dart'; // Certifique-se que isto está importado

class MapaPostosScreen extends StatefulWidget {
  const MapaPostosScreen({super.key});

  @override
  State<MapaPostosScreen> createState() => _MapaPostosScreenState();
}

class _MapaPostosScreenState extends State<MapaPostosScreen> {
  final ApiService _apiService = ApiService();
  Future<List<PostoSaude>>? _postosFuture;
  List<PostoSaude>? _todosPostos; // Lista completa de postos
  List<Map<String, dynamic>>? _tiposUnidade;
  int? _selectedTipoCodigo;
  bool _ignoreMunicipio = false;
  bool _ignoreUf = false;
  int? _detectedCodigoUf;
  String? _detectedUfSigla;
  String? _detectedCodigoMunicipio;
  final _raioController = TextEditingController(text: AppSettings.searchRadiusKm.toString()); // Raio inicial
  double _raioEmKm = AppSettings.searchRadiusKm; // Valor padrão

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // Variável para guardar a localização do usuário
  LatLng? _userPosition;

  @override
  void dispose() {
    _raioController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // Pega tipos de unidade e localização do usuário
    try {
      // buscar tipos CNES
      final tipos = await _apiService.fetchTiposUnidade();
      if (mounted) setState(() => _tiposUnidade = tipos);
    } catch (e) {
      debugPrint('Erro ao buscar tipos de unidade: $e');
    }

    // Obtém localização e tenta detectar códigos UF/município via backend
    try {
      final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      debugPrint('Localização do usuário: ${position.latitude}, ${position.longitude}');
      if (mounted) setState(() => _userPosition = LatLng(position.latitude, position.longitude));
      _moveCameraToPosition(_userPosition!);

      try {
        final codes = await _apiService.getUfMunicipioCodesFromCoords(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _detectedCodigoMunicipio = (codes['codigo_municipio'] ?? '')?.toString();
            _detectedCodigoUf = codes['codigo_uf'] is int ? codes['codigo_uf'] as int : int.tryParse((codes['codigo_uf'] ?? '').toString());
            _detectedUfSigla = codes['uf_sigla']?.toString() ?? '';
          });
        }
      } catch (e) {
        debugPrint('Erro ao obter códigos por coords: $e');
      }
    } catch (e) {
      debugPrint('Erro ao obter localização do usuário: $e');
    }

    // mantém _postosFuture vazio até o usuário realizar busca por tipo
    setState(() {
      _postosFuture = Future.value(<PostoSaude>[]);
    });
  }

  // Nota: a busca inicial de tipos e códigos por coordenadas é feita em
  // _fetchInitialData(); a busca de estabelecimentos é executada quando o
  // usuário escolhe um tipo e pressiona "Buscar estabelecimentos".

  // Função para mover a câmera
  void _moveCameraToPosition(LatLng position, {double zoom = 14.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, zoom),
    );
  }

  // Função quando toca num item da lista
  void _onPostoTapped(PostoSaude posto) {
    final LatLng postoPosition = LatLng(posto.latitude, posto.longitude);
    _moveCameraToPosition(postoPosition, zoom: 16.0); 
  }

  void _atualizarListaPostos() {
    if (_todosPostos != null && _userPosition != null) {
      setState(() {
        // Atualiza o raio em km baseado no valor do campo de texto
        _raioEmKm = double.tryParse(_raioController.text) ?? AppSettings.searchRadiusKm;
        AppSettings.searchRadiusKm = _raioEmKm;
        // Recarrega a lista de postos para atualizar a UI
        _postosFuture = Future.value(_todosPostos);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postos próximos'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Mapa reduzido com cantos arredondados
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-19.9168, -43.9345), // Centro de BH como posição inicial
                      zoom: 14,
                    ),
                    myLocationEnabled: true, // Mostra o "ponto azul"
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_userPosition != null) {
                        _moveCameraToPosition(_userPosition!);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          // Lista (ocupando um pouco mais de espaço agora)
            // Filtros CNES (tipo / UF / município)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de estabelecimento:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  (_tiposUnidade == null)
                      ? const CircularProgressIndicator()
                      : DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedTipoCodigo,
                          hint: const Text('Selecione um tipo'),
                          items: _tiposUnidade!.map((t) {
                            final codigo = (t['codigo_tipo_unidade'] is int) ? t['codigo_tipo_unidade'] as int : int.tryParse((t['codigo_tipo_unidade'] ?? '').toString()) ?? 0;
                            return DropdownMenuItem<int>(
                              value: codigo,
                              child: Text('${t['descricao_tipo_unidade'] ?? t['codigo_tipo_unidade']}'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() => _selectedTipoCodigo = v);
                          },
                        ),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ignorar município'),
                          value: _ignoreMunicipio,
                          onChanged: (v) => setState(() => _ignoreMunicipio = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ignorar estado (UF)'),
                          value: _ignoreUf,
                          onChanged: (v) => setState(() => _ignoreUf = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  if (_detectedCodigoUf != null || (_detectedCodigoMunicipio != null && _detectedCodigoMunicipio!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text('Detectado: UF=${_detectedUfSigla ?? _detectedCodigoUf ?? '-'}  Município=${_detectedCodigoMunicipio ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Campo de raio (abaixo dos filtros)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
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
                      onSubmitted: (_) => _atualizarListaPostos(),
                    ),
                  ),
                  IconButton(onPressed: _atualizarListaPostos, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
            // Botão de busca abaixo do campo de raio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _selectedTipoCodigo == null
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final codigoUf = _ignoreUf ? null : _detectedCodigoUf;
                            final codigoMun = _ignoreMunicipio
                                ? null
                                : (_detectedCodigoMunicipio != null && _detectedCodigoMunicipio!.isNotEmpty
                                    ? int.tryParse(_detectedCodigoMunicipio!)
                                    : null);
                            final lista = await _apiService.fetchEstabelecimentosPorTipo(
                              codigoTipoUnidade: _selectedTipoCodigo!,
                              codigoUf: codigoUf,
                              codigoMunicipio: codigoMun,
                              limit: 200,
                              offset: 0,
                            );

                            final postos = lista
                                .map((p) => PostoSaude(
                                      id: (p['id'] ?? '').toString(),
                                      nome: (p['nome'] ?? '').toString(),
                                      endereco: (p['endereco'] ?? '').toString(),
                                      latitude: (p['latitude'] is double)
                                          ? p['latitude'] as double
                                          : double.tryParse((p['latitude'] ?? '0').toString()) ?? 0.0,
                                      longitude: (p['longitude'] is double)
                                          ? p['longitude'] as double
                                          : double.tryParse((p['longitude'] ?? '0').toString()) ?? 0.0,
                                    ))
                                .where((pst) => pst.latitude != 0.0 && pst.longitude != 0.0)
                                .toList();

                            setState(() {
                              _todosPostos = postos;
                              _postosFuture = Future.value(_todosPostos);
                            });
                          } catch (e) {
                            debugPrint('Erro ao buscar estabelecimentos CNES: $e');
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(content: Text('Erro ao buscar estabelecimentos: $e')));
                          }
                        },
                  child: const Text('Buscar estabelecimentos'),
                ),
              ),
            ),
            Expanded(
            flex: 6,
            child: FutureBuilder<List<PostoSaude>>(
              future: _postosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro ao carregar dados: ${snapshot.error}'));
                }
                if (snapshot.hasData) {
                  final postos = snapshot.data!;
                  if (postos.isEmpty) {
                    return const Center(
                        child: Text('Nenhum posto de saúde encontrado.'));
                  }

                  // ----- INÍCIO DA LÓGICA DO FILTRO 2KM -----
                  if (_userPosition == null) {
                    return const Center(child: Text("A obter localização para filtrar..."));
                  }

                  final double raioEmMetros = _raioEmKm * 1000; // Converte km para metros
                  final List<PostoSaude> postosProximos = [];

                  for (final posto in postos) {
                    // Calcula a distância
                    final double distancia = Geolocator.distanceBetween(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                      posto.latitude,
                      posto.longitude,
                    );

                    // Adiciona à lista apenas se estiver dentro do raio
                    if (distancia <= raioEmMetros) {
                      postosProximos.add(posto);
                    }
                  }

                  if (postosProximos.isEmpty) {
                    return Center(
                        child: Text('Nenhum posto encontrado a menos de ${_raioController.text}km.'));
                  }
                  // ----- FIM DA LÓGICA DO FILTRO 2KM -----


                  // --- Lógica de Marcadores (agora usa 'postosProximos') ---
                  Set<Marker> allMarkers = {};
                  for (final posto in postosProximos) { // <-- MUDANÇA AQUI
                    allMarkers.add(
                      Marker(
                        markerId: MarkerId(posto.id),
                        position: LatLng(posto.latitude, posto.longitude),
                        infoWindow: InfoWindow(
                          title: posto.nome,
                          snippet: posto.endereco,
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _markers.clear();
                        _markers.addAll(allMarkers);
                      });
                    }
                  });
                  // --- Fim da Lógica de Marcadores ---

                  // --- ListView (agora usa 'postosProximos') ---
                  return ListView.builder(
                    itemCount: postosProximos.length, // <-- MUDANÇA AQUI
                    itemBuilder: (context, index) {
                      final posto = postosProximos[index]; // <-- MUDANÇA AQUI
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(posto.nome),
                          subtitle: Text(posto.endereco),
                          leading:
                              const Icon(Icons.local_hospital, color: Colors.red),
                          onTap: () => _onPostoTapped(posto),
                        ),
                      );
                    },
                  );
                }
                return const Center(
                    child: Text('Nenhum posto de saúde encontrado.'));
              },
            ),
          ),
        ],
      ),
    );
  }

}
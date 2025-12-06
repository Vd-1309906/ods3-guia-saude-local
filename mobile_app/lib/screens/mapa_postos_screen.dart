import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/posto_saude_model.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MapaPostosScreen extends StatefulWidget {
  const MapaPostosScreen({super.key});

  @override
  State<MapaPostosScreen> createState() => _MapaPostosScreenState();
}

class _MapaPostosScreenState extends State<MapaPostosScreen> {
  final ApiService _apiService = ApiService();
  Future<List<PostoSaude>>? _postosFuture;
  List<PostoSaude>? _todosPostos;
  List<Map<String, dynamic>>? _tiposUnidade;
  int? _selectedTipoCodigo;
  bool _ignoreMunicipio = false;
  bool _ignoreUf = false;
  int? _detectedCodigoUf;
  String? _detectedUfSigla;
  String? _detectedCodigoMunicipio;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  LatLng? _userPosition;
  TimeOfDay _tipTime = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadTime();
  }

  Future<void> _loadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('tip_hour');
    final minute = prefs.getInt('tip_minute');
    if (hour != null && minute != null) {
      if (mounted) {
        setState(() {
          _tipTime = TimeOfDay(hour: hour, minute: minute);
        });
      }
    }
  }

  Future<void> _saveTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tip_hour', time.hour);
    await prefs.setInt('tip_minute', time.minute);
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _tipTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          _tipTime = picked;
        });
      }
      await _saveTime(picked);
      await NotificationService().scheduleWeeklyHealthTip(time: picked);

      if (mounted) {
        final formattedTime = picked.format(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dica de saúde agendada para domingo às $formattedTime!'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final tipos = await _apiService.fetchTiposUnidade();
      tipos.sort((a, b) => (a['descricao_tipo_unidade'] as String)
          .compareTo(b['descricao_tipo_unidade'] as String));
      if (mounted) setState(() => _tiposUnidade = tipos);
    } catch (e) {
      debugPrint('Erro ao buscar tipos de unidade: $e');
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() =>
            _userPosition = LatLng(position.latitude, position.longitude));
      }
      _moveCameraToPosition(_userPosition!);

      try {
        final codes = await _apiService.getUfMunicipioCodesFromCoords(
            position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _detectedCodigoMunicipio =
                (codes['codigo_municipio'] ?? '')?.toString();
            _detectedCodigoUf = codes['codigo_uf'] is int
                ? codes['codigo_uf'] as int
                : int.tryParse((codes['codigo_uf'] ?? '').toString());
            _detectedUfSigla = codes['uf_sigla']?.toString() ?? '';
          });
        }
      } catch (e) {
        debugPrint('Erro ao obter códigos por coords: $e');
      }
    } catch (e) {
      debugPrint('Erro ao obter localização do usuário: $e');
    }

    if (mounted) {
      setState(() {
        _postosFuture = Future.value(<PostoSaude>[]);
      });
    }
  }

  void _moveCameraToPosition(LatLng position, {double zoom = 14.0}) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, zoom));
  }

  void _onPostoTapped(PostoSaude posto) {
    final LatLng postoPosition = LatLng(posto.latitude, posto.longitude);
    _moveCameraToPosition(postoPosition, zoom: 16.0);
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
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-19.9168, -43.9345),
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
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
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tipo de estabelecimento:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                (_tiposUnidade == null)
                    ? const CircularProgressIndicator()
                    : DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedTipoCodigo,
                        hint: const Text('Selecione um tipo'),
                        itemHeight: null,
                        items: _tiposUnidade!.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final t = entry.value;
                          final codigo = (t['codigo_tipo_unidade'] is int)
                              ? t['codigo_tipo_unidade'] as int
                              : int.tryParse(
                                      (t['codigo_tipo_unidade'] ?? '')
                                          .toString()) ??
                                  0;
                          return DropdownMenuItem<int>(
                            value: codigo,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: (idx < _tiposUnidade!.length - 1)
                                    ? Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1))
                                    : null,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                '${t['descricao_tipo_unidade'] ?? t['codigo_tipo_unidade']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                        onChanged: (v) =>
                            setState(() => _ignoreMunicipio = v ?? false),
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
                if (_detectedCodigoUf != null ||
                    (_detectedCodigoMunicipio != null &&
                        _detectedCodigoMunicipio!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Detectado: UF=${_detectedUfSigla ?? _detectedCodigoUf ?? '-'}  Município=${_detectedCodigoMunicipio ?? '-'}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.schedule, color: Colors.blueAccent),
                    tooltip: 'Agendar Dica de Saúde Semanal',
                    onPressed: _showTimePicker,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedTipoCodigo == null
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final codigoUf = _ignoreUf ? null : _detectedCodigoUf;
                              final codigoMun = _ignoreMunicipio
                                  ? null
                                  : (_detectedCodigoMunicipio != null &&
                                          _detectedCodigoMunicipio!.isNotEmpty
                                      ? int.tryParse(_detectedCodigoMunicipio!)
                                      : null);
                              final lista =
                                  await _apiService.fetchEstabelecimentosPorTipo(
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
                                        endereco:
                                            (p['endereco'] ?? '').toString(),
                                        latitude: (p['latitude'] is double)
                                            ? p['latitude'] as double
                                            : double.tryParse(
                                                    (p['latitude'] ?? '0')
                                                        .toString()) ??
                                                0.0,
                                        longitude: (p['longitude'] is double)
                                            ? p['longitude'] as double
                                            : double.tryParse(
                                                    (p['longitude'] ?? '0')
                                                        .toString()) ??
                                                0.0,
                                      ))
                                  .where((pst) =>
                                      pst.latitude != 0.0 &&
                                      pst.longitude != 0.0)
                                  .toList();

                              if (_userPosition != null) {
                                for (var posto in postos) {
                                  posto.distancia =
                                      Geolocator.distanceBetween(
                                    _userPosition!.latitude,
                                    _userPosition!.longitude,
                                    posto.latitude,
                                    posto.longitude,
                                  );
                                }
                                postos.sort((a, b) => (a.distancia ?? 0)
                                    .compareTo(b.distancia ?? 0));
                              }

                              if (mounted) {
                                setState(() {
                                  _todosPostos = postos;
                                  _postosFuture = Future.value(_todosPostos);
                                });
                              }
                            } catch (e) {
                              debugPrint(
                                  'Erro ao buscar estabelecimentos CNES: $e');
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Erro ao buscar estabelecimentos: $e')),
                              );
                            }
                          },
                    child: const Text('Buscar estabelecimentos'),
                  ),
                ],
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

                  Set<Marker> allMarkers = {};
                  for (final posto in postos) {
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

                  return ListView.builder(
                    itemCount: postos.length,
                    itemBuilder: (context, index) {
                      final posto = postos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(posto.nome),
                          subtitle: Text(
                            posto.distancia != null
                                ? "${posto.endereco}\n📍 ${(posto.distancia! / 1000).toStringAsFixed(2)} km de distância"
                                : posto.endereco,
                          ),
                          leading: const Icon(Icons.local_hospital,
                              color: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NotificationService().showRandomHealthTipNow();
        },
        tooltip: 'Receber Dica de Saúde',
        child: const Icon(Icons.lightbulb_outline),
      ),
    );
  }
}


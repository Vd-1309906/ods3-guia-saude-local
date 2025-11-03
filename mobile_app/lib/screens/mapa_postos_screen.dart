import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/posto_saude_model.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart'; // Certifique-se que isto está importado

class MapaPostosScreen extends StatefulWidget {
  const MapaPostosScreen({Key? key}) : super(key: key);

  @override
  _MapaPostosScreenState createState() => _MapaPostosScreenState();
}

class _MapaPostosScreenState extends State<MapaPostosScreen> {
  final ApiService _apiService = ApiService();
  Future<List<PostoSaude>>? _postosFuture;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // Posição Falsa (Praça Sete, BH) para garantir que o filtro 2km funcione
  static const LatLng _fakeUserPosition = LatLng(-19.9190, -43.9386);
  
  // Variável para guardar a localização do usuário
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _postosFuture = _fetchPostosComLocalizacao();
  }

  Future<List<PostoSaude>> _fetchPostosComLocalizacao() async {
    // --- Lógica para pedir permissão (continua igual) ---
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviço de localização está desabilitado.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissão de localização foi negada.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissão de localização negada permanentemente.');
    }
    // --- Fim: Lógica para pedir permissão ---

    // ----- INÍCIO DA MUDANÇA (LOCALIZAÇÃO FORÇADA) -----
    
    // Posição real (comentada por agora para testes)
    // Position position = await Geolocator.getCurrentPosition(
    //     desiredAccuracy: LocationAccuracy.high);

    // Posição Falsa (Praça Sete, BH) para garantir que o filtro 2km funcione
    Position position = Position(
        latitude: _fakeUserPosition.latitude,
        longitude: _fakeUserPosition.longitude,
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, altitudeAccuracy: 0,
        heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0
    );
    
    print('Localização (FORÇADA PARA TESTE): ${position.latitude}, ${position.longitude}');
    // ----- FIM DA MUDANÇA -----


    // Guarda a posição do usuário e move a câmera
    if (mounted) {
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
      });
      _moveCameraToPosition(_userPosition!);
    }

    // A API é chamada (o backend vai ignorar a lat/lon e usar o código de BH)
    return _apiService.getPostosDeSaude(position.latitude, position.longitude);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postos a menos de 2km'), // Título atualizado
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 5, 
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _fakeUserPosition, // Mapa começa na Praça Sete
                zoom: 14,
              ),
              myLocationEnabled: true, // Mostra o "ponto azul" (que será o falso)
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_userPosition != null) {
                  _moveCameraToPosition(_userPosition!);
                }
              },
            ),
          ),
          // Lista
          Expanded(
            flex: 5,
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

                  const double raioEmMetros = 2000; // 2 KM
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
                    return const Center(
                        child: Text('Nenhum posto encontrado a menos de 2km.'));
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
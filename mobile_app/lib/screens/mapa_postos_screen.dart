import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/posto_saude_model.dart';
import '../services/api_service.dart';

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

  // Posição inicial do mapa (Centro de Ribeirão das Neves, MG)
  static const LatLng _initialPosition = LatLng(-19.7669, -44.0853);

  @override
  void initState() {
    super.initState();
    // Inicia a busca pelos dados assim que a tela é criada
    _postosFuture = _apiService.getPostosDeSaude();
  }

  void _onPostoTapped(PostoSaude posto) {
    // Posição do posto selecionado
    final LatLng postoPosition = LatLng(posto.latitude, posto.longitude);

    // Cria um novo marcador para o posto
    final Marker marker = Marker(
      markerId: MarkerId(posto.id),
      position: postoPosition,
      infoWindow: InfoWindow(
        title: posto.nome,
        snippet: posto.endereco,
      ),
    );

    setState(() {
      // Limpa os marcadores antigos e adiciona apenas o novo
      _markers.clear();
      _markers.add(marker);
    });

    // Anima a câmera do mapa para a posição do novo marcador
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(postoPosition, 15.0), // Zoom de 15 é bom para visualização de ruas
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postos de Saúde (DEMAS)'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Metade superior da tela: O Mapa
          Expanded(
            flex: 5, // O mapa ocupa 50% do espaço
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 12,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
            ),
          ),
          // Metade inferior da tela: A Lista de Postos
          Expanded(
            flex: 5, // A lista ocupa os outros 50%
            child: FutureBuilder<List<PostoSaude>>(
              future: _postosFuture,
              builder: (context, snapshot) {
                // Enquanto os dados estão carregando, mostra um spinner
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Se deu erro, mostra a mensagem de erro
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
                }
                // Se os dados chegaram com sucesso, constrói a lista
                if (snapshot.hasData) {
                  final postos = snapshot.data!;
                  return ListView.builder(
                    itemCount: postos.length,
                    itemBuilder: (context, index) {
                      final posto = postos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(posto.nome),
                          subtitle: Text(posto.endereco),
                          leading: const Icon(Icons.local_hospital, color: Colors.red),
                          onTap: () => _onPostoTapped(posto),
                        ),
                      );
                    },
                  );
                }
                // Caso padrão
                return const Center(child: Text('Nenhum posto de saúde encontrado.'));
              },
            ),
          ),
        ],
      ),
    );
  }
}
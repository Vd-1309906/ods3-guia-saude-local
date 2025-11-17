import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/vacinacao_service.dart';
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
  
  bool _loading = true;
  String? _error;
  String? _cidadeDetectada;
  String? _ufDetectada;

  @override
  void initState() {
    super.initState();
    _iniciarBuscaInteligente();
  }

  Future<void> _iniciarBuscaInteligente() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _gruposVacina = null;
    });

    try {
      // 1. Pegar coordenadas GPS
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // 2. Converter GPS -> Nome da Cidade (via Backend Python)
      // O backend retorna algo como: {"nome_municipio": "Ribeirão das Neves", "sigla_uf": "MG", ...}
      final dadosLoc = await _apiService.getUfMunicipioCodesFromCoords(
        position.latitude, 
        position.longitude
      );

      final cidade = dadosLoc['nome_municipio'] as String?;
      final uf = dadosLoc['sigla_uf'] as String?; // Ou 'uf_sigla' dependendo do seu backend

      if (cidade == null) {
        throw Exception("Não foi possível identificar o nome da sua cidade.");
      }

      setState(() {
        _cidadeDetectada = cidade;
        _ufDetectada = uf;
      });

      // 3. Buscar vacinas filtrando pela cidade encontrada
      // O loop de 10 segundos acontece aqui dentro
      final grupos = await _vacinacaoService.fetchGruposPorVacina(
        limit: 200, 
        offset: 200, // Começar de um offset maior as vezes ajuda a pegar dados recentes
        filtroMunicipio: cidade,
        filtroUf: uf
      );

      if (mounted) {
        setState(() {
          _gruposVacina = grupos;
          _loading = false;
        });
      }

    } catch (e) {
      debugPrint("Erro na busca: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campanhas na sua Cidade'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _iniciarBuscaInteligente,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.teal[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cidadeDetectada != null 
                      ? "Buscando locais em: $_cidadeDetectada - $_ufDetectada"
                      : "Detectando sua localização...",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 4),
                const Text(
                  "O sistema buscará até encontrar 10 locais ou por 10 segundos.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Conteúdo Principal
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Varrendo base de dados do governo..."),
            Text("Isso pode levar alguns segundos.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text("Ocorreu um erro:", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _iniciarBuscaInteligente,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gruposVacina == null || _gruposVacina!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Nenhum registro de vacinação recente encontrado para o seu município nos dados abertos do governo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _gruposVacina!.length,
      itemBuilder: (context, index) {
        return _buildGrupoVacinaCard(_gruposVacina![index]);
      },
    );
  }

  Widget _buildGrupoVacinaCard(GrupoVacina grupo) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(
          grupo.descricao.isNotEmpty ? grupo.descricao : "Vacina ${grupo.codigo}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${grupo.estabelecimentos.length} locais encontrados',
          style: TextStyle(color: Colors.teal[700]),
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.teal[100],
          child: const Icon(Icons.local_hospital, color: Colors.teal),
        ),
        children: grupo.estabelecimentos.map((est) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            leading: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            title: Text(est.nome, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("CNES: ${est.codigoCnes}"),
          );
        }).toList(),
      ),
    );
  }
}
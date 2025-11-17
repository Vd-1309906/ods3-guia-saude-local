// Ficheiro: mobile_app/lib/models/posto_saude_model.dart

class PostoSaude {
  final String id;
  final String nome;
  final String endereco;
  final double latitude;
  final double longitude;
  double? distancia;

  PostoSaude({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    this.distancia,

  });

  //
  // --- FUNÇÃO CORRIGIDA ---
  //
  factory PostoSaude.fromJson(Map<String, dynamic> json) {
    double parseCoord(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '.').trim();
      return double.tryParse(s) ?? 0.0;
    }

    // Try common fields: 'cnes' or 'id'
    final idField = json['cnes'] ?? json['id'] ?? json['codigo'] ?? '';
    final id = idField.toString();

    final nome = (json['nome'] ?? json['nome_fantasia'] ?? '').toString();

    // Construir um endereço básico a partir de logradouro/bairro ou campo 'endereco'
    final logradouro = (json['logradouro'] ?? '').toString();
    final bairro = (json['bairro'] ?? '').toString();
    final endereco = (json['endereco'] ?? '').toString();
    final enderecoFinal = endereco.isNotEmpty
        ? endereco
        : ((logradouro.isNotEmpty) ? logradouro + ((bairro.isNotEmpty) ? ' - $bairro' : '') : (bairro.isNotEmpty ? bairro : ''));

    return PostoSaude(
      id: id.isNotEmpty ? id : 'id_desconhecido_${DateTime.now().millisecondsSinceEpoch}',
      nome: nome.isNotEmpty ? nome : 'Nome não informado',
      endereco: enderecoFinal.isNotEmpty ? enderecoFinal : 'Endereço não informado',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
    );
  }
}
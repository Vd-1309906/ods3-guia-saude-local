class PostoSaude {
  final String id;
  final String nome;
  final String endereco;
  final double latitude;
  final double longitude;

  PostoSaude({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.latitude,
    required this.longitude,
  });

  // Factory constructor para criar uma instância a partir de um JSON
  factory PostoSaude.fromJson(Map<String, dynamic> json) {
    return PostoSaude(
      id: json['id'] as String,
      nome: json['nome'] as String,
      endereco: json['endereco'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }
}
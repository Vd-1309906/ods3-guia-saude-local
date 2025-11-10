class CampanhaSaude {
  final String id;
  final String titulo;
  final String descricao;
  final String dataInicio;
  final String dataFim;
  final String? imagem;
  final String publico; // público alvo
  final String local;
  final bool ativa;

  CampanhaSaude({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataInicio,
    required this.dataFim,
    this.imagem,
    required this.publico,
    required this.local,
    required this.ativa,
  });

  factory CampanhaSaude.fromJson(Map<String, dynamic> json) {
    return CampanhaSaude(
      id: json['id'],
      titulo: json['titulo'],
      descricao: json['descricao'],
      dataInicio: json['data_inicio'],
      dataFim: json['data_fim'],
      imagem: json['imagem'],
      publico: json['publico'],
      local: json['local'],
      ativa: json['ativa'] ?? true,
    );
  }
}
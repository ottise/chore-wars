class ActionProposalModel {
  final String id, title, description, status, type;
  const ActionProposalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.type,
  });
  bool get isCompleted => status != 'PENDING';
  factory ActionProposalModel.fromJson(Map<String, dynamic> json) =>
      ActionProposalModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'].toString(),
        type: json['type'].toString(),
      );
}

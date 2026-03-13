enum SelectionMode { single, multi }

class ScanView {
  const ScanView({
    required this.id,
    required this.name,
    required this.cidr,
    required this.startIp,
    required this.endIp,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String cidr;
  final String startIp;
  final String endIp;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScanView copyWith({
    String? id,
    String? name,
    String? cidr,
    String? startIp,
    String? endIp,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScanView(
      id: id ?? this.id,
      name: name ?? this.name,
      cidr: cidr ?? this.cidr,
      startIp: startIp ?? this.startIp,
      endIp: endIp ?? this.endIp,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

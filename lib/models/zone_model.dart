import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneModel {
  String? id; // document ID (zoneId)
  bool? active;
  String? description;
  String? name;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  ZoneModel({
    this.id,
    this.active,
    this.description,
    this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['zoneId'] ?? json['id'],
      active: json['active'],
      description: json['description'],
      name: json['name'],
      createdAt: json['createdAt'] is Timestamp ? json['createdAt'] : null,
      updatedAt: json['updatedAt'] is Timestamp ? json['updatedAt'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zoneId': id,
      'active': active,
      'description': description,
      'name': name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

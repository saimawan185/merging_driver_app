class VehicleType {
  String? shortDescription;
  String? vehicleIcon;
  String? name;
  String? description;
  String? id;
  bool? isActive;
  String? capacity;
  String? supportedVehicle;
  num? delivery_charges_per_km;
  num? minimum_delivery_charges;
  num? minimum_delivery_charges_within_km;
  num? delivery_charges_per_minute; // ← new field from second model

  VehicleType({
    this.shortDescription,
    this.vehicleIcon,
    this.name,
    this.description,
    this.id,
    this.isActive,
    this.capacity,
    this.supportedVehicle,
    this.delivery_charges_per_km,
    this.minimum_delivery_charges,
    this.minimum_delivery_charges_within_km,
    this.delivery_charges_per_minute,
  });

  // ── fromJson ──────────────────────────────────────────────
  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      shortDescription: json['short_description'],
      vehicleIcon: json['vehicle_icon'],
      name: json['name'],
      description: json['description'],
      id: json['id'],
      isActive: json['isActive'],
      capacity: json['capacity'],
      supportedVehicle: json['supported_vehicle'],
      delivery_charges_per_km:
          (json['delivery_charges_per_km'] ?? 0.0).toDouble(),
      minimum_delivery_charges:
          (json['minimum_delivery_charges'] ?? 0.0).toDouble(),
      minimum_delivery_charges_within_km:
          (json['minimum_delivery_charges_within_km'] ?? 0.0).toDouble(),
      delivery_charges_per_minute:
          (json['delivery_charges_per_minute'] ?? 0.0).toDouble(),
    );
  }

  // ── toJson ────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['short_description'] = shortDescription;
    data['vehicle_icon'] = vehicleIcon;
    data['name'] = name;
    data['description'] = description;
    data['id'] = id;
    data['isActive'] = isActive;
    data['capacity'] = capacity;
    data['supported_vehicle'] = supportedVehicle;
    data['delivery_charges_per_km'] = delivery_charges_per_km;
    data['minimum_delivery_charges'] = minimum_delivery_charges;
    data['minimum_delivery_charges_within_km'] =
        minimum_delivery_charges_within_km;
    data['delivery_charges_per_minute'] = delivery_charges_per_minute;
    return data;
  }
}

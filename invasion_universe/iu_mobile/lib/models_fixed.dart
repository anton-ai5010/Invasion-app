class User {
  final int id;
  final String email;
  final String? username;
  final String role;
  final String locale;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.username,
    required this.role,
    required this.locale,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'] as String?,
      role: json['role'] ?? 'user',
      locale: json['locale'] ?? 'ru',
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
    );
  }
}

class Zone {
  final int id;
  final String name;
  final String code;
  final bool isActive;

  Zone({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}

class Seat {
  final int id;
  final int zoneId;
  final String label;
  final String seatType;
  final int hourlyPriceCents;
  final bool isActive;

  Seat({
    required this.id,
    required this.zoneId,
    required this.label,
    required this.seatType,
    required this.hourlyPriceCents,
    required this.isActive,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id'],
      zoneId: json['zone_id'] ?? 0,
      label: json['label'] ?? '',
      seatType: json['seat_type'] ?? 'standard',
      hourlyPriceCents: json['hourly_price_cents'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  String get priceDisplay => '${(hourlyPriceCents / 100).toStringAsFixed(0)} ₽/час';
}

class ZoneRow {
  final String row;
  final List<Seat> seats;

  ZoneRow({required this.row, required this.seats});

  factory ZoneRow.fromJson(Map<String, dynamic> json) {
    return ZoneRow(
      row: json['row'] ?? '',
      seats: (json['seats'] as List? ?? [])
          .map((s) => Seat.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ZoneLayout {
  final int zoneId;
  final List<ZoneRow> rows;

  ZoneLayout({required this.zoneId, required this.rows});

  factory ZoneLayout.fromJson(Map<String, dynamic> json) {
    return ZoneLayout(
      zoneId: json['zone_id'] ?? 0,
      rows: (json['rows'] as List? ?? [])
          .map((r) => ZoneRow.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isFree;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isFree,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['start_time'] != null 
        ? DateTime.parse(json['start_time']).toUtc()
        : DateTime.now().toUtc(),
      endTime: json['end_time'] != null 
        ? DateTime.parse(json['end_time']).toUtc()
        : DateTime.now().toUtc(),
      isFree: json['is_free'] ?? false,
    );
  }

  String get timeRange {
    final start = '${startTime.hour.toString().padLeft(2, '0')}:00';
    final end = '${endTime.hour.toString().padLeft(2, '0')}:00';
    return '$start - $end';
  }
}

class SeatAvailability {
  final int seatId;
  final String label;
  final List<TimeSlot> slots;

  SeatAvailability({
    required this.seatId,
    required this.label,
    required this.slots,
  });

  factory SeatAvailability.fromJson(Map<String, dynamic> json) {
    return SeatAvailability(
      seatId: json['seat_id'] ?? 0,
      label: json['label'] ?? '',
      slots: (json['slots'] as List? ?? [])
          .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Booking {
  final int id;
  final int userId;
  final int seatId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final int priceCents;
  final int penaltyCents;
  final DateTime createdAt;
  final Seat? seat;
  final Zone? zone;

  Booking({
    required this.id,
    required this.userId,
    required this.seatId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.priceCents,
    required this.penaltyCents,
    required this.createdAt,
    this.seat,
    this.zone,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      userId: json['user_id'] ?? 0,
      seatId: json['seat_id'] ?? 0,
      startTime: json['start_time'] != null 
        ? DateTime.parse(json['start_time']).toUtc()
        : DateTime.now().toUtc(),
      endTime: json['end_time'] != null 
        ? DateTime.parse(json['end_time']).toUtc()
        : DateTime.now().toUtc(),
      status: json['status'] ?? 'pending',
      priceCents: json['price_cents'] ?? 0,
      penaltyCents: json['penalty_cents'] ?? 0,
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']).toUtc()
        : DateTime.now().toUtc(),
      seat: json['seat'] != null 
        ? Seat.fromJson(json['seat'] as Map<String, dynamic>) 
        : null,
      zone: json['zone'] != null 
        ? Zone.fromJson(json['zone'] as Map<String, dynamic>) 
        : null,
    );
  }

  String get priceDisplay => '${(priceCents / 100).toStringAsFixed(0)} ₽';
  String get penaltyDisplay => '${(penaltyCents / 100).toStringAsFixed(0)} ₽';
  bool get canCancel => status == 'pending' || status == 'paid';
}

class AdminBooking {
  final int id;
  final String status;
  final DateTime startTime;
  final DateTime endTime;
  final int priceCents;
  final int penaltyCents;
  final String seatLabel;
  final int zoneId;
  final String userEmail;

  AdminBooking({
    required this.id,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.priceCents,
    required this.penaltyCents,
    required this.seatLabel,
    required this.zoneId,
    required this.userEmail,
  });

  factory AdminBooking.fromJson(Map<String, dynamic> j) => AdminBooking(
    id: j['id'],
    status: j['status'] ?? 'pending',
    startTime: j['start_time'] != null
      ? DateTime.parse(j['start_time']).toUtc()
      : DateTime.now().toUtc(),
    endTime: j['end_time'] != null
      ? DateTime.parse(j['end_time']).toUtc()
      : DateTime.now().toUtc(),
    priceCents: j['price_cents'] ?? 0,
    penaltyCents: j['penalty_cents'] ?? 0,
    seatLabel: j['seat_label'] ?? '',
    zoneId: j['zone_id'] ?? 0,
    userEmail: j['user_email'] ?? '',
  );

  String get priceDisplay => '${(priceCents / 100).toStringAsFixed(0)} ₽';
}

class RowPriceResult {
  final int zoneId;
  final String row;
  final int updated;

  RowPriceResult({required this.zoneId, required this.row, required this.updated});
  
  factory RowPriceResult.fromJson(Map<String, dynamic> j) =>
      RowPriceResult(
        zoneId: j['zone_id'] ?? 0,
        row: j['row'] ?? '',
        updated: j['updated'] ?? 0,
      );
}
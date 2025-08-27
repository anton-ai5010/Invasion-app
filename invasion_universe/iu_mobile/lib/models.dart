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
      username: json['username'],
      role: json['role'],
      locale: json['locale'],
      createdAt: DateTime.parse(json['created_at']),
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
      name: json['name'],
      code: json['code'],
      isActive: json['is_active'],
    );
  }
}

class Seat {
  final int id;
  final int zoneId;
  final String label;
  final int hourlyPriceCents;
  final bool isActive;
  final String? row;
  final String? column;

  Seat({
    required this.id,
    required this.zoneId,
    required this.label,
    required this.hourlyPriceCents,
    required this.isActive,
    this.row,
    this.column,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id'],
      zoneId: json['zone_id'],
      label: json['label'],
      hourlyPriceCents: json['hourly_price_cents'],
      isActive: json['is_active'],
      row: json['row'],
      column: json['column'],
    );
  }

  String get priceDisplay => '${(hourlyPriceCents / 100).toStringAsFixed(0)} ₽/час';
}

class ZoneLayout {
  final Zone zone;
  final Map<String, List<Seat>> seatsByRow;

  ZoneLayout({required this.zone, required this.seatsByRow});

  factory ZoneLayout.fromJson(Map<String, dynamic> json) {
    final zone = Zone.fromJson(json['zone']);
    final seatsByRow = <String, List<Seat>>{};
    
    (json['seats_by_row'] as Map<String, dynamic>).forEach((row, seats) {
      seatsByRow[row] = (seats as List).map((s) => Seat.fromJson(s)).toList();
    });

    return ZoneLayout(zone: zone, seatsByRow: seatsByRow);
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
      userId: json['user_id'],
      seatId: json['seat_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      status: json['status'],
      priceCents: json['price_cents'],
      penaltyCents: json['penalty_cents'],
      createdAt: DateTime.parse(json['created_at']),
      seat: json['seat'] != null ? Seat.fromJson(json['seat']) : null,
      zone: json['zone'] != null ? Zone.fromJson(json['zone']) : null,
    );
  }

  String get priceDisplay => '${(priceCents / 100).toStringAsFixed(0)} ₽';
  String get penaltyDisplay => '${(penaltyCents / 100).toStringAsFixed(0)} ₽';
  
  bool get canCancel => status == 'pending' || status == 'paid';
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
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      isFree: json['is_free'],
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
      seatId: json['seat_id'],
      label: json['label'],
      slots: (json['slots'] as List).map((s) => TimeSlot.fromJson(s)).toList(),
    );
  }
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
    status: j['status'],
    startTime: DateTime.parse(j['start_time']).toUtc(),
    endTime: DateTime.parse(j['end_time']).toUtc(),
    priceCents: j['price_cents'],
    penaltyCents: j['penalty_cents'],
    seatLabel: j['seat_label'],
    zoneId: j['zone_id'],
    userEmail: j['user_email'],
  );

  String get priceDisplay => '${(priceCents / 100).toStringAsFixed(0)} ₽';
}

class RowPriceResult {
  final int zoneId;
  final String row;
  final int updated;

  RowPriceResult({required this.zoneId, required this.row, required this.updated});
  
  factory RowPriceResult.fromJson(Map<String, dynamic> j) =>
      RowPriceResult(zoneId: j['zone_id'], row: j['row'], updated: j['updated']);
}
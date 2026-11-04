// Modèle : le billet d'un participant (TicketParticipation), avec son badge
// d'accès chiffré et horodaté (collection `reservations`).

class EventTicket {
  final int? id;
  final int? eventId;
  final String eventTitle;
  final String attendeeName;
  final String email;
  final String ownerKey;

  /// Numéro du billet, par exemple « CT-1735…-2026 ».
  final String ticket;

  /// Badge chiffré « CTB2.… » (absent pour les anciens billets).
  final String? badge;
  final String? date;
  final double price;
  final String status;
  final bool checkedIn;
  final String? issuedAt;
  final String? validUntil;

  const EventTicket({
    this.id,
    this.eventId,
    required this.eventTitle,
    required this.attendeeName,
    this.email = '',
    required this.ownerKey,
    required this.ticket,
    this.badge,
    this.date,
    this.price = 0,
    this.status = 'Réservé',
    this.checkedIn = false,
    this.issuedAt,
    this.validUntil,
  });

  factory EventTicket.fromMap(Map<String, Object?> map) => EventTicket(
    id: map['id'] as int?,
    eventId: (map['eventId'] as num?)?.toInt(),
    eventTitle: map['eventTitle']?.toString() ?? 'Événement',
    attendeeName: map['attendeeName']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
    ownerKey: map['ownerKey']?.toString() ?? '',
    ticket: map['ticket']?.toString() ?? '',
    badge: map['badge']?.toString(),
    date: map['date']?.toString(),
    price: (map['price'] as num?)?.toDouble() ?? 0,
    status: map['status']?.toString() ?? 'Réservé',
    checkedIn: map['checkedIn'] == true,
    issuedAt: map['issuedAt']?.toString(),
    validUntil: map['validUntil']?.toString(),
  );

  Map<String, Object?> toMap() => {
    'eventId': ?eventId,
    'eventTitle': eventTitle,
    'attendeeName': attendeeName,
    'email': email,
    'ownerKey': ownerKey,
    'ticket': ticket,
    'badge': ?badge,
    'date': ?date,
    'price': price,
    'status': status,
    'checkedIn': checkedIn,
    'issuedAt': ?issuedAt,
    'validUntil': ?validUntil,
  };
}

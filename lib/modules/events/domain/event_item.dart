// Modèle : un événement (date, ville, places, prix du billet…).

import 'package:crowdtech/shared/utils/formatters.dart';

class EventItem {
  final int? id;
  final String title;
  final String date;
  final String city;
  final int seats;
  final String? time;
  final String? venue;
  final double? price;
  final String? category;
  final String? description;
  final String? imageUrl;
  final String? imageData;
  const EventItem({
    this.id,
    required this.title,
    required this.date,
    required this.city,
    required this.seats,
    this.time,
    this.venue,
    this.price,
    this.category,
    this.description,
    this.imageUrl,
    this.imageData,
  });

  factory EventItem.fromMap(Map<String, Object?> map) => EventItem(
    id: map['id'] as int?,
    title: map['title']! as String,
    date: map['date']! as String,
    city: map['city']! as String,
    seats: (map['seats']! as num).toInt(),
    time: map['time'] as String?,
    venue: map['venue'] as String?,
    price: (map['price'] as num?)?.toDouble(),
    category: map['category'] as String?,
    description: map['description'] as String?,
    imageUrl: map['imageUrl'] as String?,
    imageData: map['imageData'] as String?,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'date': date,
    'city': city,
    'seats': seats,
    'time': ?time,
    'venue': ?venue,
    'price': ?price,
    'category': ?category,
    'description': ?description,
    'imageUrl': ?imageUrl,
    'imageData': ?imageData,
  };

  bool get isFree => (price ?? 0) <= 0;

  /// La date de l'événement est passée : on ne peut plus réserver.
  /// Une date illisible (ex. « 12 Nov 2026 ») n'est jamais considérée passée.
  bool get isPast {
    final day = parseFlexibleDate(date);
    if (day == null) return false;
    final now = DateTime.now();
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  EventItem copyWithId(int value) =>
      EventItem.fromMap({...toMap(), 'id': value});
}

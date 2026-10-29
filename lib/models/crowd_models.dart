class NewsItem {
  final int? id;
  final String title;
  final String source;
  final int credibility;
  final String tag;
  final String summary;
  final String? ownerKey;
  const NewsItem({
    this.id,
    required this.title,
    required this.source,
    required this.credibility,
    required this.tag,
    required this.summary,
    this.ownerKey,
  });

  factory NewsItem.fromMap(Map<String, Object?> map) => NewsItem(
    id: map['id'] as int?,
    title: map['title']! as String,
    source: map['source']! as String,
    credibility: map['credibility']! as int,
    tag: map['tag']! as String,
    summary: map['summary']! as String,
    ownerKey: map['ownerKey'] as String?,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'source': source,
    'credibility': credibility,
    'tag': tag,
    'summary': summary,
    if (ownerKey != null) 'ownerKey': ownerKey,
  };

  NewsItem copyWithId(int value) => NewsItem(
    id: value,
    title: title,
    source: source,
    credibility: credibility,
    tag: tag,
    summary: summary,
    ownerKey: ownerKey,
  );

  NewsItem copyWithCredibility(int value) => NewsItem(
    id: id,
    title: title,
    source: source,
    credibility: value,
    tag: tag,
    summary: summary,
    ownerKey: ownerKey,
  );
}

class FundingProject {
  final int? id;
  final String title;
  final String company;
  final double amountRaised;
  final double goal;
  final double tokenPrice;
  final int progress;
  final String feature;
  final String? ownerKey;
  const FundingProject({
    this.id,
    required this.title,
    required this.company,
    required this.amountRaised,
    required this.goal,
    required this.tokenPrice,
    required this.progress,
    required this.feature,
    this.ownerKey,
  });

  factory FundingProject.fromMap(Map<String, Object?> map) => FundingProject(
    id: map['id'] as int?,
    title: map['title']! as String,
    company: map['company']! as String,
    amountRaised: (map['amountRaised']! as num).toDouble(),
    goal: (map['goal']! as num).toDouble(),
    tokenPrice: (map['tokenPrice']! as num).toDouble(),
    progress: map['progress']! as int,
    feature: map['feature']! as String,
    ownerKey: map['ownerKey'] as String?,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'company': company,
    'amountRaised': amountRaised,
    'goal': goal,
    'tokenPrice': tokenPrice,
    'progress': progress,
    'feature': feature,
    if (ownerKey != null) 'ownerKey': ownerKey,
  };

  FundingProject copyWithId(int value) => FundingProject(
    id: value,
    title: title,
    company: company,
    amountRaised: amountRaised,
    goal: goal,
    tokenPrice: tokenPrice,
    progress: progress,
    feature: feature,
    ownerKey: ownerKey,
  );

  FundingProject copyWithRaised(double amount) => FundingProject(
    id: id,
    title: title,
    company: company,
    amountRaised: amount,
    goal: goal,
    tokenPrice: tokenPrice,
    progress: (amount / goal * 100).round().clamp(0, 100),
    feature: feature,
    ownerKey: ownerKey,
  );
}

class ProductItem {
  final int? id;
  final String name;
  final double price;
  final double? rating;
  final String category;
  const ProductItem({
    this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.category,
  });

  factory ProductItem.fromMap(Map<String, Object?> map) => ProductItem(
    id: map['id'] as int?,
    name: map['name']! as String,
    price: (map['price']! as num).toDouble(),
    rating: (map['rating'] as num?)?.toDouble(),
    category: map['category']! as String,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'price': price,
    'rating': rating,
    'category': category,
  };

  ProductItem copyWithId(int value) => ProductItem(
    id: value,
    name: name,
    price: price,
    rating: rating,
    category: category,
  );
}

class EventItem {
  final int? id;
  final String title;
  final String date;
  final String city;
  final int seats;
  const EventItem({
    this.id,
    required this.title,
    required this.date,
    required this.city,
    required this.seats,
  });

  factory EventItem.fromMap(Map<String, Object?> map) => EventItem(
    id: map['id'] as int?,
    title: map['title']! as String,
    date: map['date']! as String,
    city: map['city']! as String,
    seats: map['seats']! as int,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'date': date,
    'city': city,
    'seats': seats,
  };

  EventItem copyWithId(int value) =>
      EventItem(id: value, title: title, date: date, city: city, seats: seats);
}

class CrowdUser {
  final String name;
  final String email;
  final String role;

  const CrowdUser({
    required this.name,
    required this.email,
    required this.role,
  });
}

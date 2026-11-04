// Modèle : une actualité (titre, source, fiabilité, auteur, lien, date…).

class NewsItem {
  final int? id;
  final String title;
  final String source;
  final int credibility;
  final String tag;
  final String summary;
  final String? author;
  final String? url;
  final String? publishedAt;
  final String? ownerKey;
  final String? imageUrl;
  final String? imageData;
  const NewsItem({
    this.id,
    required this.title,
    required this.source,
    required this.credibility,
    required this.tag,
    required this.summary,
    this.author,
    this.url,
    this.publishedAt,
    this.ownerKey,
    this.imageUrl,
    this.imageData,
  });

  factory NewsItem.fromMap(Map<String, Object?> map) => NewsItem(
    id: map['id'] as int?,
    title: map['title']! as String,
    source: map['source']! as String,
    credibility: (map['credibility']! as num).toInt(),
    tag: map['tag']! as String,
    summary: map['summary']! as String,
    author: map['author'] as String?,
    url: map['url'] as String?,
    publishedAt: map['publishedAt'] as String?,
    ownerKey: map['ownerKey'] as String?,
    imageUrl: map['imageUrl'] as String?,
    imageData: map['imageData'] as String?,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'source': source,
    'credibility': credibility,
    'tag': tag,
    'summary': summary,
    'author': ?author,
    'url': ?url,
    'publishedAt': ?publishedAt,
    'ownerKey': ?ownerKey,
    'imageUrl': ?imageUrl,
    'imageData': ?imageData,
  };

  NewsItem copyWithCredibility(int value) =>
      NewsItem.fromMap({'id': id, ...toMap(), 'credibility': value});
}

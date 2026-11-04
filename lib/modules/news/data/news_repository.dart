// Données du module Actus : articles, commentaires, notes et signalements.

import 'package:crowdtech/core/database/collection_repository.dart';

abstract final class NewsRepository {
  static const articles = CollectionRepository('news');
  static const comments = CollectionRepository('news_comments');
  static const votes = CollectionRepository('news_votes');
  static const reports = CollectionRepository('comment_reports');
}

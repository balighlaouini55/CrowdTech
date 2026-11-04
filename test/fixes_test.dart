// Régressions : accès sans compte, événements passés, nombres importés.

import 'dart:async';

import 'package:crowdtech/app/crowdtech_app.dart';
import 'package:crowdtech/app/home_page.dart';
import 'package:crowdtech/core/database/crowdtech_database.dart';
import 'package:crowdtech/modules/auth/presentation/welcome_page.dart';
import 'package:crowdtech/modules/events/domain/event_item.dart';
import 'package:crowdtech/modules/funding/domain/funding_project.dart';
import 'package:crowdtech/modules/news/domain/news_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('une route protégée sans compte renvoie à l’accueil', (
    tester,
  ) async {
    await CrowdTechDatabase.useMemoryForTesting();
    await tester.pumpWidget(const CrowdTechApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(navigator.pushNamed('/funding'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(WelcomePage), findsWidgets);
  });

  test('un événement passé est détecté, une date illisible ne l’est pas', () {
    EventItem event(String date) =>
        EventItem(title: 'Forum', date: date, city: 'Tunis', seats: 10);

    expect(event('01/01/2020').isPast, isTrue);
    expect(event('2020-01-01').isPast, isTrue);
    expect(event('12/12/2099').isPast, isFalse);
    expect(event('12 Nov 2026').isPast, isFalse);
  });

  test('les nombres décimaux importés sont acceptés par les modèles', () {
    final project = FundingProject.fromMap({
      'title': 'Projet',
      'company': 'Société',
      'amountRaised': 10,
      'goal': 100,
      'tokenPrice': 5,
      'progress': 10.0,
      'feature': 'Fonction',
    });
    final news = NewsItem.fromMap({
      'title': 'Titre',
      'source': 'Source',
      'credibility': 90.0,
      'tag': 'IA',
      'summary': 'Résumé',
    });
    final event = EventItem.fromMap({
      'title': 'Forum',
      'date': '12/12/2099',
      'city': 'Tunis',
      'seats': 30.0,
    });

    expect(project.progress, 10);
    expect(news.credibility, 90);
    expect(event.seats, 30);
  });
}

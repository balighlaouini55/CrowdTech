import 'package:flutter/material.dart';

import '../data/crowdtech_database.dart';
import 'data_record_details_page.dart';
import 'data_record_list_tile.dart';
import 'simulation_pages.dart';

class DataRecordListPage extends StatefulWidget {
  final String title;
  final String collection;
  final String emptyMessage;
  final bool ownedOnly;
  final String? accountKey;

  const DataRecordListPage({
    required this.title,
    required this.collection,
    required this.emptyMessage,
    this.ownedOnly = false,
    this.accountKey,
    super.key,
  });

  @override
  State<DataRecordListPage> createState() => _DataRecordListPageState();
}

class _DataRecordListPageState extends State<DataRecordListPage> {
  bool loading = true;
  String? error;
  List<Map<String, Object?>> records = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await CrowdTechDatabase.getItems(widget.collection);
      if (!mounted) return;
      setState(() {
        records = rows
            .where((row) {
              if (!widget.ownedOnly || widget.accountKey == null) return true;
              return row['ownerKey'] == widget.accountKey ||
                  row['accountKey'] == widget.accountKey ||
                  row['email'] == widget.accountKey;
            })
            .toList()
            .reversed
            .toList();
        loading = false;
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger ces données : $exception';
        loading = false;
      });
    }
  }

  String titleOf(Map<String, Object?> record) {
    for (final key in [
      'title',
      'name',
      'projectTitle',
      'productName',
      'eventTitle',
      'customerName',
      'attendeeName',
    ]) {
      final value = record[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return 'Enregistrement #${record['id']}';
  }

  String subtitleOf(Map<String, Object?> record) {
    final parts = [
      record['company'],
      record['category'],
      record['date'],
      record['email'],
      record['status'],
    ].whereType<String>().where((value) => value.isNotEmpty);
    return parts.join(' • ');
  }

  Future<void> openDetails(Map<String, Object?> record) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => widget.collection == 'reservations'
            ? TicketBadgePage(
                eventTitle: record['eventTitle']?.toString() ?? 'Événement',
                attendeeName:
                    record['attendeeName']?.toString() ?? 'Participant',
                ticket: record['ticket']?.toString() ?? '',
              )
            : DataRecordDetailsPage(title: titleOf(record), record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: load,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: load,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : records.isEmpty
          ? Center(child: Text(widget.emptyMessage))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final subtitle = subtitleOf(record);
                final title = titleOf(record);
                return DataRecordListTile(
                  title: title,
                  subtitle: subtitle,
                  onTap: () => openDetails(record),
                );
              },
            ),
    );
  }
}

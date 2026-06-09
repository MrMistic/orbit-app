import 'dart:async';

import 'package:flutter/material.dart';

import '../../../database/object_box.dart';

/// A search result with a source label, title, subtitle, and optional route.
class SearchResult {
  const SearchResult({
    required this.source,
    required this.title,
    this.subtitle,
    this.icon,
  });
  final String source;
  final String title;
  final String? subtitle;
  final IconData? icon;
}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  void _search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final results = <SearchResult>[];
    final ob = ObjectBox.instance;

    // Todos
    for (final t in ob.todoBox.getAll()) {
      if (_matches(t.title, q) || _matches(t.notes, q)) {
        results.add(SearchResult(
          source: 'Todo', title: t.title,
          subtitle: t.done ? '✓ Done' : (t.notes ?? ''),
          icon: Icons.check_circle_outline,
        ));
      }
    }

    // Notes
    for (final n in ob.noteBox.getAll()) {
      if (_matches(n.title, q) || _matches(n.body, q)) {
        results.add(SearchResult(
          source: 'Note', title: n.title,
          subtitle: n.body.length > 60 ? '${n.body.substring(0, 60)}…' : n.body,
          icon: Icons.note_outlined,
        ));
      }
    }

    // Recipes
    for (final r in ob.recipeBox.getAll()) {
      if (_matches(r.name, q) || _matches(r.description, q) || _matches(r.tagsRaw, q)) {
        results.add(SearchResult(
          source: 'Recipe', title: r.name,
          subtitle: r.description ?? r.tagList.join(', '),
          icon: Icons.restaurant_outlined,
        ));
      }
    }

    // Contacts
    for (final c in ob.crmContactBox.getAll()) {
      if (_matches(c.name, q) || _matches(c.notes, q) || _matches(c.relationship, q)) {
        results.add(SearchResult(
          source: 'Contact', title: c.name,
          subtitle: c.relationship ?? c.notes ?? '',
          icon: Icons.people_outline,
        ));
      }
    }

    // Media
    for (final m in ob.mediaBox.getAll()) {
      if (_matches(m.title, q) || _matches(m.author, q) || _matches(m.notes, q)) {
        results.add(SearchResult(
          source: 'Media', title: m.title,
          subtitle: [m.author, m.mediaType].where((s) => s != null && s.isNotEmpty).join(' · '),
          icon: Icons.menu_book_outlined,
        ));
      }
    }

    // Projects
    for (final p in ob.projectBox.getAll()) {
      if (_matches(p.name, q) || _matches(p.description, q) || _matches(p.tasks, q)) {
        results.add(SearchResult(
          source: 'Project', title: p.name,
          subtitle: p.description ?? p.status,
          icon: Icons.rocket_launch_outlined,
        ));
      }
    }

    // Skills
    for (final s in ob.skillBox.getAll()) {
      if (_matches(s.name, q) || _matches(s.category, q)) {
        results.add(SearchResult(
          source: 'Skill', title: s.name,
          subtitle: '${s.totalHours.toStringAsFixed(1)} hours',
          icon: Icons.school_outlined,
        ));
      }
    }

    // Maintenance
    for (final m in ob.maintenanceBox.getAll()) {
      if (_matches(m.title, q) || _matches(m.category, q) || _matches(m.notes, q)) {
        results.add(SearchResult(
          source: 'Maintenance', title: m.title,
          subtitle: m.category ?? '',
          icon: Icons.build_outlined,
        ));
      }
    }

    // Subscriptions
    for (final s in ob.subscriptionBox.getAll()) {
      if (_matches(s.name, q) || _matches(s.category, q) || _matches(s.notes, q)) {
        results.add(SearchResult(
          source: 'Subscription', title: s.name,
          subtitle: '\$${s.monthlyCost.toStringAsFixed(2)}/mo',
          icon: Icons.subscriptions_outlined,
        ));
      }
    }

    // Bucket list
    for (final b in ob.bucketListBox.getAll()) {
      if (_matches(b.title, q) || _matches(b.notes, q) || _matches(b.category, q)) {
        results.add(SearchResult(
          source: 'Bucket list', title: b.title,
          subtitle: b.done ? '✓ Done' : (b.category ?? ''),
          icon: Icons.explore_outlined,
        ));
      }
    }

    // Important dates
    for (final d in ob.importantDateBox.getAll()) {
      if (_matches(d.title, q) || _matches(d.notes, q)) {
        results.add(SearchResult(
          source: 'Date', title: d.title,
          subtitle: '${d.daysUntil} days away',
          icon: Icons.event_outlined,
        ));
      }
    }

    // Bets
    for (final b in ob.betRecordBox.getAll()) {
      if (_matches(b.description, q) || _matches(b.sport, q) || _matches(b.sportsbook, q)) {
        results.add(SearchResult(
          source: 'Bet', title: b.description,
          subtitle: '${b.status} · \$${b.stake.toStringAsFixed(2)}',
          icon: Icons.casino_outlined,
        ));
      }
    }

    setState(() => _results = results);
  }

  bool _matches(String? text, String query) {
    if (text == null || text.isEmpty) return false;
    return text.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search everything…',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                _controller.text.isEmpty
                    ? 'Search across all your data'
                    : 'No results',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i];
                return ListTile(
                  leading: Icon(r.icon ?? Icons.search),
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    r.subtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    r.source,
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                );
              },
            ),
    );
  }
}

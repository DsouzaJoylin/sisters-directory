import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------
// Theme tokens — kept consistent with admin_dashboard_screen.dart /
// admin_add_sister_screen.dart / view_profile_screen.dart.
// ---------------------------------------------------------------------
class _C {
  static const primary = Color(0xFF6A1B9A);
  static const primaryLight = Color(0xFFF5F0F8);
  static const accent = Color(0xFF6A3DE8);
  static const surface = Color(0xFFFFFFFF);
  static const page = Color(0xFFF7F5FB);
  static const textPrimary = Color(0xFF1A0A3B);
  static const textSecondary = Color(0xFF6B5E8A);
  static const divider = Color(0xFFEAE4F8);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
}

class _SisterRow {
  final String id;
  final Map<String, dynamic> data;
  _SisterRow({required this.id, required this.data});
}

/// ---------------------------------------------------------------------
/// DeleteSisterScreen
/// ---------------------------------------------------------------------
/// Reached from the admin dashboard's "Delete Sister" quick action.
/// The admin searches for a sister by name, then taps a delete icon on
/// her result card. Deleting removes the sister's main document plus
/// every subcollection doc listed in [_knownSubcollectionDocs] below.
///
/// This runs entirely client-side (no Cloud Functions), so it works on
/// the free Spark Firestore plan — no billing required.
///
/// ⚠️ MAINTENANCE NOTE: Firestore's client SDK has no way to discover a
/// document's subcollections automatically — that capability only exists
/// server-side (Admin SDK / Cloud Functions, which requires the paid
/// Blaze plan). So this list is manually maintained. It currently
/// matches every subcollection AdminAddSisterScreen writes:
///   sisters/{id}/formation/details
///   sisters/{id}/religiousLife/details
/// If you ever add a new subcollection anywhere else in the app (e.g.
/// sisters/{id}/notes/{noteId}), add its path pattern to
/// [_knownSubcollectionDocs] too, or it will be silently orphaned when a
/// sister is deleted.
/// ---------------------------------------------------------------------
class DeleteSisterScreen extends StatefulWidget {
  const DeleteSisterScreen({super.key});

  @override
  State<DeleteSisterScreen> createState() => _DeleteSisterScreenState();
}

class _DeleteSisterScreenState extends State<DeleteSisterScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;
  List<_SisterRow> _results = [];

  // Tracks which sister id is currently mid-delete, so only that row
  // shows a spinner instead of the whole list locking up.
  String? _deletingId;

  // Every subcollection doc that lives under a sister document, relative
  // to sisters/{id}/. Keep this in sync with wherever the app writes new
  // subcollections (currently: AdminAddSisterScreen._save()). This is the
  // one list that has to be kept accurate for delete to be complete.
  static const List<String> _knownSubcollectionDocs = [
    'formation/details',
    'religiousLife/details',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      final snap = await FirebaseFirestore.instance.collection('sisters').get();
      final found = <_SisterRow>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['fullName'] ?? '').toString();
        if (name.toLowerCase().contains(query.toLowerCase())) {
          found.add(_SisterRow(id: doc.id, data: data));
        }
      }

      if (!mounted) return;
      setState(() => _results = found);
    } catch (e) {
      if (!mounted) return;
      _snack('Search failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _results = [];
      _hasSearched = false;
    });
  }

  Future<void> _confirmAndDelete(_SisterRow sister) async {
    final name = (sister.data['fullName'] ?? 'this sister').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sister?'),
        content: Text(
          'This permanently removes "$name" and all of her records — '
          'personal details, education, documents and photo, formation, '
          'and religious life. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _C.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _deleteSister(sister);
  }

  // ---------------------------------------------------------------
  // Deletes the sister's main document plus every subcollection doc in
  // _knownSubcollectionDocs, all in one batch (atomic — either all of it
  // succeeds or none of it does). Pure Firestore client SDK, no Cloud
  // Functions, so this costs nothing beyond normal Firestore usage.
  // ---------------------------------------------------------------
  Future<void> _deleteSister(_SisterRow sister) async {
    setState(() => _deletingId = sister.id);
    try {
      final sisterRef =
          FirebaseFirestore.instance.collection('sisters').doc(sister.id);
      final batch = FirebaseFirestore.instance.batch();

      // Deleting a doc that doesn't exist is a safe no-op in Firestore,
      // so it's fine to always queue every known path even if a
      // particular sister never had that section filled in.
      for (final path in _knownSubcollectionDocs) {
        batch.delete(sisterRef.collection(path.split('/')[0]).doc(path.split('/')[1]));
      }
      batch.delete(sisterRef);

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _results.removeWhere((r) => r.id == sister.id);
      });
      _snack('${(sister.data['fullName'] ?? 'Sister').toString()} deleted.');
    } catch (e) {
      if (!mounted) return;
      _snack('Delete failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? _C.error : _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _s(dynamic v) =>
      (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.page,
      appBar: AppBar(
        title: const Text('Delete Sister'),
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            if (_hasSearched) _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search by sister\'s name',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _C.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Joylin Joyce Dsouza',
                    isDense: true,
                    filled: true,
                    fillColor: _C.primaryLight,
                    prefixIcon: const Icon(Icons.search, color: _C.accent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ),
              if (_hasSearched) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close, color: _C.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            const Icon(Icons.search_off, size: 18, color: _C.textSecondary),
            const SizedBox(width: 8),
            Text(
              'No sisters found for that name.',
              style: const TextStyle(color: _C.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_results.length} sister(s) found',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _C.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        for (final sister in _results) _sisterCard(sister),
      ],
    );
  }

  Widget _sisterCard(_SisterRow sister) {
    final data = sister.data;
    final isDeleting = _deletingId == sister.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _C.primary.withOpacity(0.15),
            child: const Icon(Icons.person, color: _C.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s(data['fullName']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DOB: ${_s(data['dob'])} · ${_s(data['mobile'])}',
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Delete sister',
                  icon: const Icon(Icons.delete_outline, color: _C.error),
                  onPressed: () => _confirmAndDelete(sister),
                ),
        ],
      ),
    );
  }
}
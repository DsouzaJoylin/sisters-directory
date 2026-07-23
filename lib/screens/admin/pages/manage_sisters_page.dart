import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import '../../../widgets/sister_avatar.dart';
import '../../user/view_profile_screen.dart';

/// Full directory management page: search, filter by status, and
/// take actions (approve/reject/view+edit/delete) on any sister.
///
/// Works directly against the real 'sisters' collection schema
/// (raw Map<String, dynamic> documents) rather than a strict model,
/// since the schema has several optional/legacy fields. Editing opens
/// the real ViewProfileScreen, which already handles per-section
/// editing (Personal Info, Education, Formation, Religious Life,
/// Documents) rather than duplicating that here.
class ManageSistersPage extends StatefulWidget {
  const ManageSistersPage({super.key});

  @override
  State<ManageSistersPage> createState() => _ManageSistersPageState();
}

class _ManageSistersPageState extends State<ManageSistersPage> {
  String _statusFilter = 'all';
  String _searchQuery = '';

  final _searchController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _sistersRef =>
      FirebaseFirestore.instance.collection('sisters');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var filtered = docs;

    if (_statusFilter != 'all') {
      filtered = filtered.where((doc) {
        final status = (doc.data()['status'] as String?) ?? 'approved';
        return status == _statusFilter;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((doc) {
        final data = doc.data();
        final fullName = (data['fullName'] as String? ?? '').toLowerCase();
        final email = (data['email'] as String? ?? '').toLowerCase();
        final mobile = (data['mobileNumber'] as String? ?? '').toLowerCase();
        return fullName.contains(q) || email.contains(q) || mobile.contains(q);
      }).toList();
    }

    return filtered;
  }

  Future<void> _confirmDelete(String uid, String fullName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Sister'),
        content: Text(
            'Remove ${fullName.isEmpty ? 'this sister' : fullName} from the directory? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sistersRef.doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fullName.isEmpty ? 'Sister' : fullName} removed')),
        );
      }
    }
  }

  Future<void> _setStatus(String uid, String status) async {
    await _sistersRef.doc(uid).update({'status': status});
  }

  void _openProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewProfileScreen(sisterId: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _sistersRef.orderBy('fullName').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load directory: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final docs = _applyFilters(snapshot.data?.docs ?? []);

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sisters match your filters.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) => _buildSisterTile(docs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or mobile number',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        DropdownButton<String>(
          value: _statusFilter,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _statusFilter = value);
          },
        ),
      ],
    );
  }

  Widget _buildSisterTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final fullName = (data['fullName'] as String?) ?? '';
    final email = (data['email'] as String?) ?? '';
    final mobile = (data['mobileNumber'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'approved';

    return ListTile(
      onTap: () => _openProfile(doc.id),
      leading: SisterAvatar(
        fullName: fullName,
        photoBase64: extractPhotoBase64(data),
      ),
      title: Text(fullName.isEmpty ? 'Unnamed Sister' : fullName),
      subtitle: Text(email.isNotEmpty ? email : mobile),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusChip(status),
          const SizedBox(width: 4),
          if (status == 'pending') ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
              tooltip: 'Approve',
              onPressed: () => _setStatus(doc.id, 'approved'),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.hourglass_empty_outlined, color: AppColors.pending),
              tooltip: 'Mark as pending',
              onPressed: () => _setStatus(doc.id, 'pending'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            tooltip: 'View / Edit',
            onPressed: () => _openProfile(doc.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Remove',
            onPressed: () => _confirmDelete(doc.id, fullName),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = status == 'pending' ? AppColors.pending : AppColors.approved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
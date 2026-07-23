import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import '../../../widgets/sister_avatar.dart';
import '../../user/view_profile_screen.dart';
import 'dashboard_card.dart';

/// Directory search box for the dashboard. Debounces input and
/// queries the real 'sisters' collection client-side (Firestore
/// doesn't support full-text search natively). Tapping a result
/// calls [onSisterSelected] with that sister's uid if provided;
/// otherwise it falls back to opening ViewProfileScreen itself.
class SearchCard extends StatefulWidget {
  const SearchCard({super.key, this.onSisterSelected});

  /// Called with the tapped sister's Firestore doc id (uid). When
  /// null, SearchCard opens ViewProfileScreen itself instead.
  final ValueChanged<String>? onSisterSelected;

  @override
  State<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);

      try {
        final snapshot =
            await FirebaseFirestore.instance.collection('sisters').get();
        final q = query.trim().toLowerCase();

        final matches = snapshot.docs.where((doc) {
          final data = doc.data();
          final fullName = (data['fullName'] as String? ?? '').toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();
          final mobile = (data['mobileNumber'] as String? ?? '').toLowerCase();
          return fullName.contains(q) || email.contains(q) || mobile.contains(q);
        }).toList();

        if (mounted) {
          setState(() {
            _results = matches;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _results = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  void _openProfile(String uid) {
    if (widget.onSisterSelected != null) {
      widget.onSisterSelected!(uid);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewProfileScreen(sisterId: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Search Directory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or mobile number',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        )
                      : null),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final doc = _results[index];
                  final data = doc.data();
                  final fullName = (data['fullName'] as String?) ?? '';
                  final email = (data['email'] as String?) ?? '';
                  final mobile = (data['mobileNumber'] as String?) ?? '';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SisterAvatar(
                      fullName: fullName,
                      photoBase64: extractPhotoBase64(data),
                      radius: 20,
                    ),
                    title: Text(fullName.isEmpty ? 'Unnamed Sister' : fullName),
                    subtitle: Text(email.isNotEmpty ? email : mobile),
                    onTap: () => _openProfile(doc.id),
                  );
                },
              ),
            ),
          ] else if (_controller.text.trim().isNotEmpty && !_isSearching) ...[
            const SizedBox(height: 12),
            const Text(
              'No sisters found matching your search.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
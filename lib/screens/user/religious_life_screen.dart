import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
//  MODEL — Communities Served entry
// ─────────────────────────────────────────────

class CommunityEntry {
  String id;
  String name;
  String from;
  String to;
  String ministry;

  CommunityEntry({
    required this.id,
    this.name = '',
    this.from = '',
    this.to = '',
    this.ministry = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'from': from,
        'to': to,
        'ministry': ministry,
      };

  factory CommunityEntry.fromMap(Map<String, dynamic> m) => CommunityEntry(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        from: m['from'] ?? '',
        to: m['to'] ?? '',
        ministry: m['ministry'] ?? '',
      );
}

class ReligiousLifeScreen extends StatefulWidget {
  /// When opened by an admin editing someone else's record, pass that
  /// sister's uid here. When null, defaults to the signed-in user (normal
  /// self-service flow).
  final String? sisterUid;

  const ReligiousLifeScreen({super.key, this.sisterUid});

  @override
  State<ReligiousLifeScreen> createState() => _ReligiousLifeScreenState();
}

class _ReligiousLifeScreenState extends State<ReligiousLifeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = true;

  // ─── Controllers ──────────────────────────────────────────────────────────
  final _provinceCtrl          = TextEditingController();
  final _congregationCtrl      = TextEditingController();
  final _currentCommunityCtrl  = TextEditingController();
  final _designationCtrl       = TextEditingController();
  final _currentMissionCtrl    = TextEditingController();

  // ─── Communities Served (dynamic list) ────────────────────────────────────
  List<CommunityEntry> _communitiesServed = [];

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF6A1B9A);
  static const _purpleLight = Color(0xFF9C27B0);
  static const _purpleDark  = Color(0xFF4A148C);
  static const _purpleMid   = Color(0xFF7B1FA2);

  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_purpleDark, _purple, _purpleLight],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in [
      _provinceCtrl,
      _congregationCtrl,
      _currentCommunityCtrl,
      _designationCtrl,
      _currentMissionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Firebase ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final uid = widget.sisterUid ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔍 [ReligiousLife] loadData uid = $uid');
      if (uid == null) {
        _showSnackBar('You are not signed in. Please log in again.',
            isError: true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .collection('religiousLife')
          .doc('details')
          .get();

      debugPrint('🔍 [ReligiousLife] doc.exists = ${doc.exists}');

      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _provinceCtrl.text         = d['province'] ?? '';
          _congregationCtrl.text     = d['congregation'] ?? '';
          _currentCommunityCtrl.text = d['currentCommunity'] ?? '';
          _designationCtrl.text      = d['designation'] ?? '';
          _currentMissionCtrl.text   = d['currentMission'] ?? '';

          final rawList = d['communitiesServed'] as List<dynamic>? ?? [];
          _communitiesServed = rawList
              .map((e) => CommunityEntry.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        });
      }
    } on FirebaseException catch (e, st) {
      // Surfaces the REAL Firestore error code (e.g. permission-denied,
      // unavailable, not-found) instead of a generic message.
      debugPrint('❌ [ReligiousLife] FirebaseException on load: '
          '${e.code} — ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error loading data (${e.code}): ${e.message}',
          isError: true);
    } catch (e, st) {
      debugPrint('❌ [ReligiousLife] Unexpected error on load: $e');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uid = widget.sisterUid ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔍 [ReligiousLife] saveData uid = $uid');
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'not-authenticated',
          message: 'No signed-in user found. Please log in again.',
        );
      }

      final payload = {
        'province':          _provinceCtrl.text.trim(),
        'congregation':      _congregationCtrl.text.trim(),
        'currentCommunity':  _currentCommunityCtrl.text.trim(),
        'designation':       _designationCtrl.text.trim(),
        'currentMission':    _currentMissionCtrl.text.trim(),
        'communitiesServed': _communitiesServed.map((e) => e.toMap()).toList(),
        'updatedAt':         FieldValue.serverTimestamp(),
      };

      debugPrint('🔍 [ReligiousLife] Writing payload to '
          'sisters/$uid/religiousLife/details: $payload');

      await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .collection('religiousLife')
          .doc('details')
          .set(payload, SetOptions(merge: true));

      debugPrint('✅ [ReligiousLife] Save succeeded.');
      _showSnackBar('Religious life details saved successfully!');
    } on FirebaseException catch (e, st) {
      // This is the block that will tell you WHY it's not saving.
      // Common e.code values:
      //  - 'permission-denied' → your Firestore Security Rules are blocking
      //    writes to sisters/{uid}/religiousLife/{doc}. Check that your rules
      //    allow: match /sisters/{uid}/religiousLife/{doc} {
      //             allow read, write: if request.auth != null && request.auth.uid == uid; }
      //  - 'unavailable' → device offline / Firestore can't be reached.
      //  - 'not-found' → (rare on set(), usually fine since set() creates docs)
      debugPrint('❌ [ReligiousLife] FirebaseException on save: '
          '${e.code} — ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error saving data (${e.code}): ${e.message}',
          isError: true);
    } catch (e, st) {
      debugPrint('❌ [ReligiousLife] Unexpected error on save: $e');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error saving data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Form',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Clear all religious life fields?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            onPressed: () {
              Navigator.pop(context);
              _formKey.currentState?.reset();
              setState(() {
                for (final c in [
                  _provinceCtrl,
                  _congregationCtrl,
                  _currentCommunityCtrl,
                  _designationCtrl,
                  _currentMissionCtrl,
                ]) {
                  c.clear();
                }
                _communitiesServed = [];
              });
            },
            child:
                const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
  }

  // ─── Communities Served — Add/Edit Dialog ──────────────────────────────────

  void _openAddCommunityDialog({CommunityEntry? editing}) {
    debugPrint('🟣 [ReligiousLife] Opening ${editing == null ? "Add" : "Edit"} community dialog');
    final isEdit = editing != null;
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final fromCtrl = TextEditingController(text: editing?.from ?? '');
    final toCtrl = TextEditingController(text: editing?.to ?? '');
    final ministryCtrl = TextEditingController(text: editing?.ministry ?? '');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _headerGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.church_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Edit Community' : 'Add Community Served',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _dialogField(nameCtrl, 'Community Name', Icons.location_city_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dialogField(fromCtrl, 'From (Year)', Icons.arrow_forward_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogField(toCtrl, 'To (Year)', Icons.arrow_back_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dialogField(ministryCtrl, 'Ministry', Icons.volunteer_activism_rounded),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      icon: Icon(
                          isEdit ? Icons.save_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 18),
                      label: Text(isEdit ? 'Update' : 'Add',
                          style: const TextStyle(color: Colors.white)),
                      onPressed: () {
                        if (dialogFormKey.currentState!.validate()) {
                          setState(() {
                            if (isEdit) {
                              editing.name = nameCtrl.text.trim();
                              editing.from = fromCtrl.text.trim();
                              editing.to = toCtrl.text.trim();
                              editing.ministry = ministryCtrl.text.trim();
                            } else {
                              _communitiesServed.add(CommunityEntry(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                name: nameCtrl.text.trim(),
                                from: fromCtrl.text.trim(),
                                to: toCtrl.text.trim(),
                                ministry: ministryCtrl.text.trim(),
                              ));
                            }
                          });
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _purple, size: 20),
        filled: true,
        fillColor: const Color(0xFFF3E5F5),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _purple.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
        ),
        labelStyle: const TextStyle(color: _purpleMid, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _deleteCommunity(int index) {
    setState(() => _communitiesServed.removeAt(index));
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Community?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This entry will be removed from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _deleteCommunity(index);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.of(context).size.width > 800 ? 760.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // 1 — Community & Province
                              _buildSection(
                                title: 'Community & Province',
                                icon: Icons.account_balance_outlined,
                                iconColor: const Color.fromARGB(255, 221, 207, 237),
                                children: [
                                  _buildField(
                                    ctrl: _provinceCtrl,
                                    label: 'Province',
                                    hint: 'Enter province name',
                                    icon: Icons.map_outlined,
                                    validator:
                                        _requiredValidator('Province'),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    ctrl: _congregationCtrl,
                                    label: 'Congregation',
                                    hint: 'Enter congregation name',
                                    icon: Icons.groups_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    ctrl: _currentCommunityCtrl,
                                    label: 'Current Community',
                                    hint: 'Enter current community',
                                    icon: Icons.home_work_outlined,
                                    validator: _requiredValidator(
                                        'Current Community'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2 — Role & Assignment
                              _buildSection(
                                title: 'Role & Assignment',
                                icon: Icons.badge_outlined,
                                iconColor: _purpleMid,
                                children: [
                                  _buildField(
                                    ctrl: _designationCtrl,
                                    label: 'Designation',
                                    hint:
                                        'e.g. Superior, Teacher, Nurse, Doctor, Social Worker',
                                    icon: Icons.title_outlined,
                                    validator:
                                        _requiredValidator('Designation'),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    ctrl: _currentMissionCtrl,
                                    label: 'Current Mission',
                                    hint: 'Enter current mission',
                                    icon: Icons.flag_outlined,
                                    validator: _requiredValidator(
                                        'Current Mission'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3 — Communities Served (dynamic list)
                              _buildCommunitiesServedCard(),

                              const SizedBox(height: 28),
                              _buildActionButtons(),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Sliver App Bar ───────────────────────────────────────────────────────
  // NOTE: Only ONE title is rendered. The large centered title lives in the
  // expanded flexibleSpace background and fades out as the app bar
  // collapses. We deliberately do NOT also set FlexibleSpaceBar.title (or
  // SliverAppBar.title) — doing so renders a second, left-aligned title
  // that overlaps/duplicates the centered one during the collapse
  // transition, which is what caused the "double, off-center heading" bug.

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      stretch: true,
      backgroundColor: _purpleDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: () {
            setState(() => _isFetching = true);
            _loadData();
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A148C),
                Color(0xFF6A1B9A),
                Color(0xFF9C27B0),
                Color(0xFFCE93D8),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: 10, left: -20,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.church_rounded,
                          size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Religious Life',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Community & Apostolate Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Card ─────────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shadowColor: _purple.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withOpacity(0.85),
                        iconColor.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: _purple.withOpacity(0.15), height: 1),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  // ─── Communities Served Card ──────────────────────────────────────────────

  Widget _buildCommunitiesServedCard() {
    return Card(
      elevation: 3,
      shadowColor: _purple.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _purpleDark.withOpacity(0.10),
                  _purpleLight.withOpacity(0.06),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _purpleLight.withOpacity(0.85),
                        _purpleLight.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _purpleLight.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.church_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Communities Served',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _purpleLight,
                    ),
                  ),
                ),
                // Fixed: wrapped in a shrink-wrapped, non-expanding container
                // so it can't be squeezed to zero width by the Expanded
                // title next to it, and it now uses Material+InkWell (see
                // _gradientButton below) which hit-tests reliably.
                _gradientButton(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onTap: () => _openAddCommunityDialog(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: _purple.withOpacity(0.15), height: 1),
          ),
          // list
          if (_communitiesServed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_city_rounded,
                        size: 40, color: _purple.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    const Text(
                      'No communities added yet.\nTap + Add to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _communitiesServed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _communityTile(_communitiesServed[i], i),
            ),
        ],
      ),
    );
  }

  Widget _communityTile(CommunityEntry entry, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withOpacity(0.15)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: _headerGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ),
        title: Text(
          entry.name.isNotEmpty ? entry.name : 'Unnamed Community',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.from.isNotEmpty || entry.to.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.date_range_rounded,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.from.isNotEmpty ? entry.from : "—"} → ${entry.to.isNotEmpty ? entry.to : "Present"}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (entry.ministry.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.volunteer_activism_rounded,
                      size: 12, color: _purple),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.ministry,
                      style: TextStyle(fontSize: 12, color: _purple),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, color: _purple, size: 18),
              onPressed: () => _openAddCommunityDialog(editing: entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded,
                  color: Colors.red.shade400, size: 18),
              onPressed: () => _confirmDelete(index),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  // ─── FIXED: Material + InkWell instead of GestureDetector ─────────────────
  // GestureDetector alone can silently fail to register taps in tightly
  // packed Rows (e.g. next to an Expanded Text) because it only hit-tests
  // its child's painted bounds and gives no visual feedback, making it hard
  // to tell if a tap even registered. Material + InkWell guarantees a
  // properly sized tap target, shows a ripple so you can visually confirm
  // the tap landed, and is the standard Flutter pattern for tappable
  // decorated containers.
  Widget _gradientButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: _headerGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _purpleMid.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Input Widgets ────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _purple),
        alignLabelWithHint: maxLines > 1,
        labelStyle: const TextStyle(color: _purple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purple.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ─── Validators ───────────────────────────────────────────────────────────

  String? Function(String?) _requiredValidator(String fieldName) {
    return (v) {
      if (v == null || v.trim().isEmpty) return '$fieldName is required';
      if (v.trim().length < 2) return 'Minimum 2 characters required';
      return null;
    };
  }

  // ─── Action Buttons ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final isWide = MediaQuery.of(context).size.width > 480;

    final saveBtn = SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveData,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          _isLoading ? 'Saving…' : 'Save Religious Life',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          disabledBackgroundColor: _purple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: _purple.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );

    final resetBtn = SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _resetForm,
        icon: const Icon(Icons.refresh_outlined),
        label: const Text('Reset',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: const BorderSide(color: _purple, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );

    if (isWide) {
      return Row(children: [
        Expanded(child: saveBtn),
        const SizedBox(width: 12),
        Expanded(child: resetBtn),
      ]);
    }
    return Column(children: [
      SizedBox(width: double.infinity, child: saveBtn),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: resetBtn),
    ]);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FormationScreen extends StatefulWidget {
  /// When opened by an admin editing someone else's record, pass that
  /// sister's uid here. When null, defaults to the signed-in user (normal
  /// self-service flow).
  final String? sisterUid;

  const FormationScreen({super.key, this.sisterUid});

  @override
  State<FormationScreen> createState() => _FormationScreenState();
}

class _FormationScreenState extends State<FormationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = true;

  // ─── Expansion state ──────────────────────────────────────────────────────
  final Map<String, bool> _expanded = {
    'candidate': true,
    'studentCandidate': false,
    'postulancy': false,
    'novitiate': false,
    'firstProfession': false,
    'finalProfession': false,
    'additional': false,
  };

  // ─── Controllers ──────────────────────────────────────────────────────────
  // Candidate
  final _candidatePlaceCtrl      = TextEditingController();
  final _candidateDirectressCtrl = TextEditingController();
  int? _candidateFromYear;
  int? _candidateToYear;

  // Student Candidate
  final _studentCandidatePlaceCtrl      = TextEditingController();
  final _studentCandidateDirectressCtrl = TextEditingController();
  int? _studentCandidateFromYear;
  int? _studentCandidateToYear;

  // Postulancy
  final _postulancyPlaceCtrl      = TextEditingController();
  final _postulancyDirectressCtrl = TextEditingController();
  int? _postulancyFromYear;
  int? _postulancyToYear;

  // Novitiate
  final _novitiatePlaceCtrl      = TextEditingController();
  final _novitiateDirectressCtrl = TextEditingController();
  int? _novitiateFromYear;
  int? _novitiateToYear;

  // First Profession
  final _firstProfessionPlaceCtrl      = TextEditingController();
  final _firstProfessionDirectressCtrl = TextEditingController();
  int? _firstProfessionYear;

  // Final Profession
  final _finalProfessionPlaceCtrl      = TextEditingController();
  final _finalProfessionDirectressCtrl = TextEditingController();
  int? _finalProfessionYear;

  // Additional — only spiritual director remains
  final _spiritualDirectorCtrl = TextEditingController();

  // ─── Completion flags ─────────────────────────────────────────────────────
  Map<String, bool> get _stageCompleted => {
        'candidate': _candidatePlaceCtrl.text.length >= 3 &&
            _candidateFromYear != null &&
            _candidateToYear != null,
        'studentCandidate': _studentCandidatePlaceCtrl.text.length >= 3 &&
            _studentCandidateFromYear != null &&
            _studentCandidateToYear != null,
        'postulancy': _postulancyPlaceCtrl.text.length >= 3 &&
            _postulancyFromYear != null &&
            _postulancyToYear != null,
        'novitiate': _novitiatePlaceCtrl.text.length >= 3 &&
            _novitiateFromYear != null &&
            _novitiateToYear != null,
        'firstProfession': _firstProfessionPlaceCtrl.text.length >= 3 &&
            _firstProfessionYear != null,
        'finalProfession': _finalProfessionPlaceCtrl.text.length >= 3 &&
            _finalProfessionYear != null,
        'additional': _spiritualDirectorCtrl.text.isNotEmpty,
      };

  static const _purple     = Color(0xFF6A1B9A);
  static const _purpleDark = Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _loadFormationData();
  }

  @override
  void dispose() {
    for (final c in [
      _candidatePlaceCtrl, _candidateDirectressCtrl,
      _studentCandidatePlaceCtrl, _studentCandidateDirectressCtrl,
      _postulancyPlaceCtrl, _postulancyDirectressCtrl,
      _novitiatePlaceCtrl, _novitiateDirectressCtrl,
      _firstProfessionPlaceCtrl, _firstProfessionDirectressCtrl,
      _finalProfessionPlaceCtrl, _finalProfessionDirectressCtrl,
      _spiritualDirectorCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Firebase ─────────────────────────────────────────────────────────────

  Future<void> _loadFormationData() async {
    try {
      final uid = widget.sisterUid ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔍 [Formation] loadData uid = $uid');
      if (uid == null) {
        _showSnackBar('You are not signed in. Please log in again.',
            isError: true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .collection('formation')
          .doc('details')
          .get();

      debugPrint('🔍 [Formation] doc.exists = ${doc.exists}');

      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _candidatePlaceCtrl.text      = d['candidatePlace'] ?? '';
          _candidateDirectressCtrl.text = d['candidateDirectress'] ?? '';
          _candidateFromYear            = d['candidateFromYear'];
          _candidateToYear              = d['candidateToYear'];

          _studentCandidatePlaceCtrl.text      = d['studentCandidatePlace'] ?? '';
          _studentCandidateDirectressCtrl.text = d['studentCandidateDirectress'] ?? '';
          _studentCandidateFromYear            = d['studentCandidateFromYear'];
          _studentCandidateToYear              = d['studentCandidateToYear'];

          _postulancyPlaceCtrl.text      = d['postulancyPlace'] ?? '';
          _postulancyDirectressCtrl.text = d['postulancyDirectress'] ?? '';
          _postulancyFromYear            = d['postulancyFromYear'];
          _postulancyToYear              = d['postulancyToYear'];

          _novitiatePlaceCtrl.text      = d['noviciatePlace'] ?? '';
          _novitiateDirectressCtrl.text = d['novitiateDirectress'] ?? '';
          _novitiateFromYear            = d['novitiateFromYear'];
          _novitiateToYear              = d['novitiateToYear'];

          _firstProfessionPlaceCtrl.text      = d['firstProfessionPlace'] ?? '';
          _firstProfessionDirectressCtrl.text = d['firstProfessionDirectress'] ?? '';
          _firstProfessionYear                = d['firstProfessionYear'];

          _finalProfessionPlaceCtrl.text      = d['finalProfessionPlace'] ?? '';
          _finalProfessionDirectressCtrl.text = d['finalProfessionDirectress'] ?? '';
          _finalProfessionYear                = d['finalProfessionYear'];

          _spiritualDirectorCtrl.text = d['spiritualDirector'] ?? '';
        });
      }
    } on FirebaseException catch (e, st) {
      debugPrint('❌ [Formation] FirebaseException on load: '
          '${e.code} — ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error loading data (${e.code}): ${e.message}',
          isError: true);
    } catch (e, st) {
      debugPrint('❌ [Formation] Unexpected error on load: $e');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _saveFormation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uid = widget.sisterUid ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔍 [Formation] saveData uid = $uid');
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'not-authenticated',
          message: 'No signed-in user found. Please log in again.',
        );
      }

      final payload = {
        'candidatePlace':      _candidatePlaceCtrl.text.trim(),
        'candidateDirectress': _candidateDirectressCtrl.text.trim(),
        'candidateFromYear':   _candidateFromYear,
        'candidateToYear':     _candidateToYear,

        'studentCandidatePlace':      _studentCandidatePlaceCtrl.text.trim(),
        'studentCandidateDirectress': _studentCandidateDirectressCtrl.text.trim(),
        'studentCandidateFromYear':   _studentCandidateFromYear,
        'studentCandidateToYear':     _studentCandidateToYear,

        'postulancyPlace':      _postulancyPlaceCtrl.text.trim(),
        'postulancyDirectress': _postulancyDirectressCtrl.text.trim(),
        'postulancyFromYear':   _postulancyFromYear,
        'postulancyToYear':     _postulancyToYear,

        'noviciatePlace':      _novitiatePlaceCtrl.text.trim(),
        'novitiateDirectress': _novitiateDirectressCtrl.text.trim(),
        'novitiateFromYear':   _novitiateFromYear,
        'novitiateToYear':     _novitiateToYear,

        'firstProfessionPlace':      _firstProfessionPlaceCtrl.text.trim(),
        'firstProfessionDirectress': _firstProfessionDirectressCtrl.text.trim(),
        'firstProfessionYear':       _firstProfessionYear,

        'finalProfessionPlace':      _finalProfessionPlaceCtrl.text.trim(),
        'finalProfessionDirectress': _finalProfessionDirectressCtrl.text.trim(),
        'finalProfessionYear':       _finalProfessionYear,

        'spiritualDirector': _spiritualDirectorCtrl.text.trim(),
        'updatedAt':         FieldValue.serverTimestamp(),
      };

      debugPrint('🔍 [Formation] Writing payload to '
          'sisters/$uid/formation/details: $payload');

      await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .collection('formation')
          .doc('details')
          .set(payload, SetOptions(merge: true));

      // Denormalize firstProfessionYear onto the main sister profile doc so
      // admins can search/group sisters by profession year without having
      // to query every sister's formation subcollection individually.
      await FirebaseFirestore.instance.collection('sisters').doc(uid).set({
        'firstProfessionYear': _firstProfessionYear,
      }, SetOptions(merge: true));

      debugPrint('✅ [Formation] Save succeeded.');
      _showSnackBar('Formation details saved successfully!');
      if (mounted) setState(() {});
    } on FirebaseException catch (e, st) {
      // Tells you WHY it's not saving. Common e.code values:
      //  - 'permission-denied' → Firestore Security Rules block writes to
      //    sisters/{uid}/formation/{doc}. Rule should look like:
      //    match /sisters/{uid}/formation/{docId} {
      //      allow read, write: if request.auth != null && request.auth.uid == uid; }
      //  - 'unavailable' → device offline / can't reach Firestore.
      debugPrint('❌ [Formation] FirebaseException on save: '
          '${e.code} — ${e.message}');
      debugPrintStack(stackTrace: st);
      _showSnackBar('Error saving data (${e.code}): ${e.message}',
          isError: true);
    } catch (e, st) {
      debugPrint('❌ [Formation] Unexpected error on save: $e');
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
        content: const Text('Clear all formation fields?'),
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
                  _candidatePlaceCtrl, _candidateDirectressCtrl,
                  _studentCandidatePlaceCtrl, _studentCandidateDirectressCtrl,
                  _postulancyPlaceCtrl, _postulancyDirectressCtrl,
                  _novitiatePlaceCtrl, _novitiateDirectressCtrl,
                  _firstProfessionPlaceCtrl, _firstProfessionDirectressCtrl,
                  _finalProfessionPlaceCtrl, _finalProfessionDirectressCtrl,
                  _spiritualDirectorCtrl,
                ]) {
                  c.clear();
                }
                _candidateFromYear = _candidateToYear = null;
                _studentCandidateFromYear = _studentCandidateToYear = null;
                _postulancyFromYear = _postulancyToYear = null;
                _novitiateFromYear = _novitiateToYear = null;
                _firstProfessionYear = null;
                _finalProfessionYear = null;
              });
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
  }

  // ─── Year Picker ──────────────────────────────────────────────────────────

  Future<int?> _pickYear({int? initialYear, int? maxYear}) async {
    final now = DateTime.now().year;
    final max = maxYear ?? now;
    int selectedYear = initialYear ?? now;

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Year',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 260,
            height: 260,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: selectedYear > 1900
                          ? () => setDlg(() => selectedYear--)
                          : null,
                    ),
                    Text('$selectedYear',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _purple)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: selectedYear < max
                          ? () => setDlg(() => selectedYear++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: max - 1900 + 1,
                    itemBuilder: (_, i) {
                      final year = 1900 + i;
                      final isSelected = year == selectedYear;
                      return GestureDetector(
                        onTap: () => setDlg(() => selectedYear = year),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? _purple : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? _purple
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            '$year',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _purple),
              onPressed: () => Navigator.pop(ctx, selectedYear),
              child: const Text('Select',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
                            horizontal: 16, vertical: 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // ── Candidate ────────────────────────────
                              _buildStageCard(
                                key: 'candidate',
                                title: 'Candidate',
                                icon: Icons.person_add_outlined,
                                color: const Color(0xFF7B1FA2),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _candidatePlaceCtrl,
                                    label: 'Candidate Place',
                                    hint: 'Enter formation place',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildYearRangeRow(
                                    label: 'Candidate Year',
                                    fromYear: _candidateFromYear,
                                    toYear: _candidateToYear,
                                    onFromPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _candidateFromYear);
                                      if (y != null)
                                        setState(() => _candidateFromYear = y);
                                    },
                                    onToPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _candidateToYear);
                                      if (y != null)
                                        setState(() => _candidateToYear = y);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _candidateDirectressCtrl,
                                    label: 'Candidate Directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── Student Candidate ─────────────────────
                              _buildStageCard(
                                key: 'studentCandidate',
                                title: 'Student Candidate',
                                icon: Icons.school_outlined,
                                color: const Color(0xFF6A1B9A),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _studentCandidatePlaceCtrl,
                                    label: 'Student Candidate Place',
                                    hint: 'Enter formation place',
                                    required: false,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildYearRangeRow(
                                    label: 'Student Candidate Year',
                                    fromYear: _studentCandidateFromYear,
                                    toYear: _studentCandidateToYear,
                                    onFromPick: () async {
                                      final y = await _pickYear(
                                          initialYear:
                                              _studentCandidateFromYear);
                                      if (y != null)
                                        setState(() =>
                                            _studentCandidateFromYear = y);
                                    },
                                    onToPick: () async {
                                      final y = await _pickYear(
                                          initialYear:
                                              _studentCandidateToYear);
                                      if (y != null)
                                        setState(() =>
                                            _studentCandidateToYear = y);
                                    },
                                    required: false,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _studentCandidateDirectressCtrl,
                                    label: 'Student Candidate Directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── Postulancy ────────────────────────────
                              _buildStageCard(
                                key: 'postulancy',
                                title: 'Postulancy',
                                icon: Icons.auto_stories_outlined,
                                color: const Color(0xFF4A148C),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _postulancyPlaceCtrl,
                                    label: 'Postulancy Place',
                                    hint: 'Enter formation place',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildYearRangeRow(
                                    label: 'Postulancy Year',
                                    fromYear: _postulancyFromYear,
                                    toYear: _postulancyToYear,
                                    onFromPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _postulancyFromYear);
                                      if (y != null)
                                        setState(() => _postulancyFromYear = y);
                                    },
                                    onToPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _postulancyToYear);
                                      if (y != null)
                                        setState(() => _postulancyToYear = y);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _postulancyDirectressCtrl,
                                    label: 'Postulancy Directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── Novitiate ─────────────────────────────
                              _buildStageCard(
                                key: 'novitiate',
                                title: 'Novitiate',
                                icon: Icons.brightness_5_outlined,
                                color: const Color(0xFF6A1B9A),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _novitiatePlaceCtrl,
                                    label: 'Novitiate Place',
                                    hint: 'Enter formation place',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildYearRangeRow(
                                    label: 'Novitiate Year',
                                    fromYear: _novitiateFromYear,
                                    toYear: _novitiateToYear,
                                    onFromPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _novitiateFromYear);
                                      if (y != null)
                                        setState(() => _novitiateFromYear = y);
                                    },
                                    onToPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _novitiateToYear);
                                      if (y != null)
                                        setState(() => _novitiateToYear = y);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _novitiateDirectressCtrl,
                                    label: 'Novitiate Directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── First Profession ──────────────────────
                              _buildStageCard(
                                key: 'firstProfession',
                                title: 'First Profession',
                                icon: Icons.workspace_premium_outlined,
                                color: const Color(0xFF7B1FA2),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _firstProfessionPlaceCtrl,
                                    label: 'First Profession Place',
                                    hint: 'Enter formation place',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildSingleYearPicker(
                                    label: 'First Profession Year',
                                    year: _firstProfessionYear,
                                    onPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _firstProfessionYear);
                                      if (y != null)
                                        setState(
                                            () => _firstProfessionYear = y);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _firstProfessionDirectressCtrl,
                                    label: 'Junior directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── Final Profession ──────────────────────
                              _buildStageCard(
                                key: 'finalProfession',
                                title: 'Final Profession',
                                icon: Icons.military_tech_outlined,
                                color: const Color(0xFF4A148C),
                                children: [
                                  _buildPlaceField(
                                    ctrl: _finalProfessionPlaceCtrl,
                                    label: 'Final Profession Place',
                                    hint: 'Enter formation place',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildSingleYearPicker(
                                    label: 'Final Profession Year',
                                    year: _finalProfessionYear,
                                    onPick: () async {
                                      final y = await _pickYear(
                                          initialYear: _finalProfessionYear);
                                      if (y != null)
                                        setState(
                                            () => _finalProfessionYear = y);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    ctrl: _finalProfessionDirectressCtrl,
                                    label: 'Tertain Directress',
                                    hint: 'Enter directress name',
                                    icon: Icons.person_outline,
                                  ),
                                ],
                              ),

                              // ── Additional — only Spiritual Director ───
                              _buildStageCard(
                                key: 'additional',
                                title: 'On going formation',
                                icon: Icons.info_outline,
                                color: const Color(0xFF6A1B9A),
                                children: [
                                  _buildTextField(
                                    ctrl: _spiritualDirectorCtrl,
                                    label: 'Spiritual Director / Directress',
                                    hint: 'Enter spiritual director name',
                                    icon: Icons.self_improvement_outlined,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return 'Spiritual Director is required';
                                      return null;
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
                              _buildActionButtons(),
                              const SizedBox(height: 32),
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
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
            _loadFormationData();
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
                Color.fromARGB(255, 201, 231, 103),
                Color.fromARGB(255, 234, 221, 241),
                Color.fromARGB(255, 234, 173, 244),
                Color.fromARGB(255, 154, 238, 160),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 80,
                  height: 80,
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
                  child: const Icon(Icons.menu_book_rounded,
                      size: 42, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Religious Formation Details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 19,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        title: const Text('Formation',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        titlePadding:
            const EdgeInsetsDirectional.only(start: 56, bottom: 16),
      ),
    );
  }

  // ─── Stage Card ───────────────────────────────────────────────────────────

  Widget _buildStageCard({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final isExpanded = _expanded[key] ?? false;
    final isComplete = _stageCompleted[key] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shadowColor: color.withOpacity(0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            InkWell(
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(18))
                  : BorderRadius.circular(18),
              onTap: () => setState(() => _expanded[key] = !isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(18))
                      : BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    if (isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Done',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Field Helpers ────────────────────────────────────────────────────────

  Widget _buildPlaceField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    bool required = true,
  }) {
    return _buildTextField(
      ctrl: ctrl,
      label: label,
      hint: hint,
      icon: Icons.location_on_outlined,
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return '$label is required';
              if (v.trim().length < 3) return 'Minimum 3 characters required';
              return null;
            }
          : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _purple),
        labelStyle: const TextStyle(color: _purple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purple.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildYearRangeRow({
    required String label,
    required int? fromYear,
    required int? toYear,
    required VoidCallback onFromPick,
    required VoidCallback onToPick,
    bool fromError = false,
    bool toError = false,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _purple, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _yearPickerButton(
                label: 'From',
                year: fromYear,
                onTap: onFromPick,
                hasError: required && fromError,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _yearPickerButton(
                label: 'To',
                year: toYear,
                onTap: onToPick,
                hasError: required && toError,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleYearPicker({
    required String label,
    required int? year,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _purple, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        _yearPickerButton(label: 'Select Year', year: year, onTap: onPick),
      ],
    );
  }

  Widget _yearPickerButton({
    required String label,
    required int? year,
    required VoidCallback onTap,
    bool hasError = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError ? Colors.red.shade400 : _purple.withOpacity(0.35),
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: _purple, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                year != null ? '$year' : label,
                style: TextStyle(
                  color: year != null ? Colors.black87 : Colors.grey.shade500,
                  fontWeight:
                      year != null ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: _purple),
          ],
        ),
      ),
    );
  }

  // ─── Action Buttons ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final isWide = MediaQuery.of(context).size.width > 480;

    final saveBtn = SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveFormation,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          _isLoading ? 'Saving...' : 'Save Formation',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: _purple.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );

    final resetBtn = SizedBox(
      height: 52,
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
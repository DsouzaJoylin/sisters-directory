import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ─────────────────────────────────────────────────
  final _sslcSchool          = TextEditingController();
  final _sslcYear            = TextEditingController();
  final _pucCollege          = TextEditingController();
  final _pucYear             = TextEditingController();
  final _degree              = TextEditingController();
  final _degreeCollege       = TextEditingController();
  final _degreeYear          = TextEditingController();
  final _pg                  = TextEditingController();
  final _pgCollege           = TextEditingController();
  final _pgYear              = TextEditingController();
  final _bed                 = TextEditingController();
  final _med                 = TextEditingController();
  final _otherQualifications = TextEditingController();
  final _talents             = TextEditingController();

  bool _isSaving  = false;
  bool _isLoading = true;

  // ── Teal-green palette (distinct from Personal Info purple) ──────
  static const Color _top    = Color(0xFF00695C); // deep teal
  static const Color _mid    = Color(0xFF26A69A); // medium teal
  static const Color _bottom = Color(0xFF80CBC4); // soft mint
  static const Color _accent = Color(0xFF00897B); // button / focus teal

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sslcSchool.dispose();
    _sslcYear.dispose();
    _pucCollege.dispose();
    _pucYear.dispose();
    _degree.dispose();
    _degreeCollege.dispose();
    _degreeYear.dispose();
    _pg.dispose();
    _pgCollege.dispose();
    _pgYear.dispose();
    _bed.dispose();
    _med.dispose();
    _otherQualifications.dispose();
    _talents.dispose();
    super.dispose();
  }

  // ── Firestore load ───────────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .get();

      if (doc.exists) {
        final edu = doc.data()?['education'] as Map<String, dynamic>?;
        if (edu != null) {
          setState(() {
            _sslcSchool.text          = edu['sslcSchool']          ?? '';
            _sslcYear.text            = edu['sslcYear']?.toString() ?? '';
            _pucCollege.text          = edu['pucCollege']           ?? '';
            _pucYear.text             = edu['pucYear']?.toString()  ?? '';
            _degree.text              = edu['degree']               ?? '';
            _degreeCollege.text       = edu['degreeCollege']        ?? '';
            _degreeYear.text          = edu['degreeYear']?.toString()  ?? '';
            _pg.text                  = edu['pg']                   ?? '';
            _pgCollege.text           = edu['pgCollege']            ?? '';
            _pgYear.text              = edu['pgYear']?.toString()   ?? '';
            _bed.text                 = edu['bed']                  ?? '';
            _med.text                 = edu['med']                  ?? '';
            _otherQualifications.text = edu['otherQualifications']  ?? '';
            _talents.text             = edu['Talents']              ?? '';
          });
        }
      }
    } catch (_) {
      // silently ignore — user just starts with empty fields
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Firestore save ───────────────────────────────────────────────
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .set({
        'education': {
          'sslcSchool':          _sslcSchool.text.trim(),
          'sslcYear':            _sslcYear.text.trim(),
          'pucCollege':          _pucCollege.text.trim(),
          'pucYear':             _pucYear.text.trim(),
          'degree':              _degree.text.trim(),
          'degreeCollege':       _degreeCollege.text.trim(),
          'degreeYear':          _degreeYear.text.trim(),
          'pg':                  _pg.text.trim(),
          'pgCollege':           _pgCollege.text.trim(),
          'pgYear':              _pgYear.text.trim(),
          'bed':                 _bed.text.trim(),
          'med':                 _med.text.trim(),
          'otherQualifications': _otherQualifications.text.trim(),
          'Talents':             _talents.text.trim(),
        }
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('Education details saved ✓');
      Navigator.pop(context);
    } catch (e) {
      _showSnack('Failed to save. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Year picker dialog ───────────────────────────────────────────
  Future<void> _pickYear(TextEditingController ctrl) async {
    final now    = DateTime.now().year;
    int selected = int.tryParse(ctrl.text) ?? now;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int temp = selected;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Select Year',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 260,
            height: 220,
            child: StatefulBuilder(
              builder: (ctx2, setS) => ListWheelScrollView.useDelegate(
                itemExtent: 44,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(
                    initialItem: now - temp),
                onSelectedItemChanged: (i) => setS(() => temp = now - i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: now - 1960 + 1,
                  builder: (_, i) {
                    final y = now - i;
                    return Center(
                      child: Text(
                        '$y',
                        style: TextStyle(
                          fontSize: y == temp ? 22 : 16,
                          fontWeight: y == temp
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: y == temp ? _accent : Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (picked != null) ctrl.text = picked.toString();
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _accent))
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  // ── Gradient header ────────────────────────────
                  SliverAppBar(
                    expandedHeight: 210,
                    pinned: true,
                    backgroundColor: _top,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_top, _mid, _bottom],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.menu_book_rounded,
                                    size: 54, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              const Text('Education',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  )),
                              const SizedBox(height: 4),
                              Text('Academic & other qualifications',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Cards ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Column(
                        children: [
                          // ── SSLC ───────────────────────────────
                          _SectionCard(
                            icon: Icons.school_outlined,
                            title: 'SSLC / 10th',
                            accent: _accent,
                            children: [
                              _field('School Name', _sslcSchool,
                                  icon: Icons.account_balance_outlined,
                                  hint: 'e.g. St. Mary\'s High School'),
                              _yearField('Year of Passing', _sslcYear),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── PUC ────────────────────────────────
                          _SectionCard(
                            icon: Icons.business_outlined,
                            title: 'PUC / 12th',
                            accent: _accent,
                            children: [
                              _field('College Name', _pucCollege,
                                  icon: Icons.account_balance_outlined,
                                  hint: 'e.g. Christ Pre-University College'),
                              _yearField('Year of Passing', _pucYear),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Degree ─────────────────────────────
                          _SectionCard(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Degree / Bachelor\'s',
                            accent: _accent,
                            children: [
                              _field('Degree Name', _degree,
                                  icon: Icons.auto_stories_outlined,
                                  hint: 'e.g. B.Sc, B.A, B.Com, BCA',
                                  required: false),
                              _field('College Name', _degreeCollege,
                                  icon: Icons.account_balance_outlined,
                                  hint: 'e.g. St. Agnes College',
                                  required: false),
                              _yearField('Year of Passing', _degreeYear,
                                  required: false),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Post Graduation ─────────────────────
                          _SectionCard(
                            icon: Icons.military_tech_outlined,
                            title: 'Post Graduation',
                            accent: _accent,
                            children: [
                              _field('PG Degree', _pg,
                                  icon: Icons.auto_stories_outlined,
                                  hint: 'e.g. M.Sc, M.A, MCA',
                                  required: false),
                              _field('College Name', _pgCollege,
                                  icon: Icons.account_balance_outlined,
                                  hint: 'e.g. Mangalore University',
                                  required: false),
                              _yearField('Year of Passing', _pgYear,
                                  required: false),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── B.Ed / M.Ed ─────────────────────────
                          _SectionCard(
                            icon: Icons.cast_for_education_outlined,
                            title: 'Teaching Qualifications',
                            accent: _accent,
                            children: [
                              _field('B.Ed', _bed,
                                  icon: Icons.edit_note_outlined,
                                  hint: 'Institution & year (optional)',
                                  required: false),
                              _field('M.Ed', _med,
                                  icon: Icons.edit_note_outlined,
                                  hint: 'Institution & year (optional)',
                                  required: false,
                                  isLast: true),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── Other / Talents ─────────────────────
                          _SectionCard(
                            icon: Icons.star_outline_rounded,
                            title: 'Other Details',
                            accent: _accent,
                            children: [
                              _field(
                                'Other Qualifications & Certificates',
                                _otherQualifications,
                                icon: Icons.card_membership_outlined,
                                hint:
                                    'Diplomas, short courses, certificates…',
                                maxLines: 3,
                                required: false,
                              ),
                              _field(
                                'Talents & Skills',
                                _talents,
                                icon: Icons.emoji_events_outlined,
                                hint:
                                    'Music, art, sport, languages, etc.',
                                maxLines: 3,
                                required: false,
                                isLast: true,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Save button ─────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    _accent.withOpacity(0.55),
                                elevation: 4,
                                shadowColor: _accent.withOpacity(0.45),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white))
                                  : const Text('SAVE',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Field helpers ────────────────────────────────────────────────

  Widget _field(
    String label,
    TextEditingController c, {
    IconData? icon,
    String? hint,
    int maxLines = 1,
    bool required = true,
    bool isLast = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: TextFormField(
          controller: c,
          maxLines: maxLines,
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
          decoration: _dec(label, icon: icon, hint: hint,
              required: required),
        ),
      );

  /// Year field — tapping opens the wheel picker
  Widget _yearField(
    String label,
    TextEditingController c, {
    bool required = true,
    bool isLast = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: TextFormField(
          controller: c,
          readOnly: true,
          onTap: () => _pickYear(c),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
          decoration: _dec(
            label,
            icon: Icons.calendar_today_outlined,
            hint: required ? 'Tap to select year' : 'Optional',
            required: required,
            suffix: const Icon(Icons.expand_more_rounded,
                color: _accent, size: 20),
          ),
        ),
      );

  InputDecoration _dec(
    String label, {
    IconData? icon,
    String? hint,
    Widget? suffix,
    bool required = true,
  }) =>
      InputDecoration(
        labelText: required ? label : '$label  (optional)',
        hintText: hint,
        prefixIcon:
            icon != null ? Icon(icon, color: _accent, size: 20) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF0FAFA),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
      );
}

// ── Reusable section card ────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    required this.accent,
  });

  final IconData   icon;
  final String     title;
  final List<Widget> children;
  final Color      accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// ── Sibling data model ───────────────────────────────────────────────
class _Sibling {
  final TextEditingController name         = TextEditingController();
  final TextEditingController occupation   = TextEditingController();
  final TextEditingController qualification = TextEditingController();

  void dispose() {
    name.dispose();
    occupation.dispose();
    qualification.dispose();
  }

  Map<String, String> toMap() => {
        'name':          name.text.trim(),
        'occupation':    occupation.text.trim(),
        'qualification': qualification.text.trim(),
      };

  void fromMap(Map<String, dynamic> m) {
    name.text          = m['name']          ?? '';
    occupation.text    = m['occupation']    ?? '';
    qualification.text = m['qualification'] ?? '';
  }
}

// ────────────────────────────────────────────────────────────────────
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Required fields
  final fullName      = TextEditingController();
  final baptismName   = TextEditingController();
  final dobController = TextEditingController();
  final birthPlace    = TextEditingController();
  final mobile        = TextEditingController();
  final email         = TextEditingController();
  final father        = TextEditingController();
  final mother        = TextEditingController();
  final address       = TextEditingController();

  // New optional fields
  final fatherOccupation   = TextEditingController();
  final motherOccupation   = TextEditingController();
  final qualification      = TextEditingController();

  // Siblings (optional, dynamic list)
  final List<_Sibling> _siblings = [];

  // Holds the actual picked DateTime so we can derive month/day for
  // the birthday-notification feature (stored separately from the
  // display string in dobController).
  DateTime? _selectedDob;

  // Profile photo. Uploading here writes to the exact same field the
  // Documents screen uses (sisters/{uid}.documents.photoBase64), so
  // whichever screen the photo was last changed on, both stay in
  // sync automatically.
  String _photoBase64 = '';
  Uint8List? _pickedPhotoBytes;
  bool _isUploadingPhoto = false;

  String? selectedBloodGroup;
  bool _isSaving = false;

  final List<String> bloodGroups = [
    'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'
  ];

  // ── Purple palette ──────────────────────────────────────────────
  static const Color _top    = Color(0xFF6A1B9A);
  static const Color _bottom = Color(0xFFCE93D8);
  static const Color _accent = Color(0xFF8E24AA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    fullName.dispose();
    baptismName.dispose();
    dobController.dispose();
    birthPlace.dispose();
    mobile.dispose();
    email.dispose();
    father.dispose();
    mother.dispose();
    address.dispose();
    fatherOccupation.dispose();
    motherOccupation.dispose();
    qualification.dispose();
    for (final s in _siblings) s.dispose();
    super.dispose();
  }

  // ── Firebase load ───────────────────────────────────────────────
  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('sisters')
        .doc(uid)
        .get();
    if (!doc.exists) return;
    final d = doc.data()!;
    setState(() {
      fullName.text           = d['fullName']          ?? '';
      baptismName.text        = d['baptismName']       ?? '';
      dobController.text      = d['dob']               ?? '';
      birthPlace.text         = d['birthPlace']        ?? '';
      email.text               = d['email']             ?? '';
      father.text              = d['fatherName']        ?? '';
      mother.text              = d['motherName']        ?? '';
      address.text             = d['address']           ?? '';
      fatherOccupation.text    = d['fatherOccupation']  ?? '';
      motherOccupation.text    = d['motherOccupation']  ?? '';
      qualification.text       = d['qualification']     ?? '';

      // Mobile number is stored as +91XXXXXXXXXX (E.164) to match
      // the register screen, admin_add_sister_screen.dart, and the
      // birthday-SMS Cloud Function. Strip the +91 prefix back off
      // for display in this field.
      final storedMobile = d['mobileNumber'] as String?;
      if (storedMobile != null && storedMobile.startsWith('+91')) {
        mobile.text = storedMobile.substring(3);
      } else if (storedMobile != null) {
        mobile.text = storedMobile;
      }

      // Rebuild the DateTime from birthMonth/birthDay/birthYear if
      // present, so re-saving doesn't lose precision.
      final bMonth = d['birthMonth'];
      final bDay = d['birthDay'];
      final bYear = d['birthYear'];
      if (bMonth is int && bDay is int && bYear is int) {
        _selectedDob = DateTime(bYear, bMonth, bDay);
      }

      final bg = d['bloodGroup'] as String?;
      if (bg != null && bloodGroups.contains(bg)) selectedBloodGroup = bg;

      // Pull the photo from the same top-level sisters/{uid} document,
      // under the 'documents' map — this is exactly where the
      // Documents screen saves it, so no extra Firestore read is
      // needed and the two screens always stay in sync automatically.
      final docsMap = d['documents'];
      if (docsMap is Map<String, dynamic>) {
        _photoBase64 = docsMap['photoBase64'] ?? '';
      } else if (docsMap is Map) {
        _photoBase64 = (docsMap['photoBase64'] as String?) ?? '';
      }

      // Load siblings
      final raw = d['siblings'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            final s = _Sibling();
            s.fromMap(item);
            _siblings.add(s);
          }
        }
      }
    });
  }

  // ── Firebase save ───────────────────────────────────────────────
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBloodGroup == null) {
      _showSnack('Please select a blood group', isError: true);
      return;
    }
    if (_selectedDob == null) {
      _showSnack('Please select date of birth', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final sisterRef =
          FirebaseFirestore.instance.collection('sisters').doc(uid);

      // Only default 'status' to 'pending' on a sister's very first
      // save — never overwrite an admin's approval just because she
      // edited her own profile afterwards.
      final existing = await sisterRef.get();
      final hasStatus = existing.data()?['status'] != null;

      // Format mobile number to E.164 (+91XXXXXXXXXX) — same format
      // used in the register screen, admin_add_sister_screen.dart,
      // and expected by the birthday SMS Cloud Function.
      final formattedMobile = "+91${mobile.text.trim()}";

      await sisterRef.set({
        'fullName':          fullName.text.trim(),
        'baptismName':       baptismName.text.trim(),
        'dob':               dobController.text.trim(),
        'birthMonth':        _selectedDob!.month,
        'birthDay':          _selectedDob!.day,
        'birthYear':         _selectedDob!.year,
        'birthPlace':        birthPlace.text.trim(),
        'mobileNumber':      formattedMobile,
        'email':             email.text.trim(),
        'bloodGroup':        selectedBloodGroup,
        'fatherName':        father.text.trim(),
        'fatherOccupation':  fatherOccupation.text.trim(),
        'motherName':        mother.text.trim(),
        'motherOccupation':  motherOccupation.text.trim(),
        'qualification':     qualification.text.trim(),
        'address':           address.text.trim(),
        'siblings':          _siblings.map((s) => s.toMap()).toList(),
        'profileCompleted':  true,
        if (!hasStatus) 'status': 'pending',
        if (!hasStatus) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('Personal information saved ✓');
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  // ── Photo pick & upload ──────────────────────────────────────────
  // Uses XFile.readAsBytes() directly (never dart:io File), so this
  // works identically on mobile and on web/computer — same fix
  // applied on the Documents screen.
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
          source: source, maxWidth: 600, imageQuality: 75);
      if (picked == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);

      // Rough size guard: Firestore doc limit is ~1 MB
      if (b64.length > 900000) {
        _showSnack('Image too large. Please choose a smaller photo.',
            isError: true);
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Dot-path key so only photoBase64 inside the 'documents' map
      // is touched — other fields the Documents screen saves there
      // (aadhaarNumber, panNumber, etc.) are left untouched.
      await FirebaseFirestore.instance
          .collection('sisters')
          .doc(uid)
          .set({'documents.photoBase64': b64}, SetOptions(merge: true));

      setState(() {
        _pickedPhotoBytes = bytes;
        _photoBase64 = b64;
      });

      _showSnack('Profile photo updated ✓');
    } catch (e) {
      _showSnack('Could not upload photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Update Profile Photo',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _accent)),
              const SizedBox(height: 16),

              // Camera — mobile only, same reasoning as Documents
              // screen: desktop browser camera capture is unreliable.
              if (!kIsWeb) ...[
                _photoSheetOption(
                    Icons.camera_alt_rounded, 'Take Photo', Colors.indigo,
                    () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.camera);
                }),
                const SizedBox(height: 10),
              ],

              _photoSheetOption(
                  kIsWeb
                      ? Icons.upload_file_rounded
                      : Icons.photo_library_rounded,
                  kIsWeb ? 'Upload from Computer' : 'Choose from Gallery',
                  _accent, () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSheetOption(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _addSibling() => setState(() => _siblings.add(_Sibling()));

  void _removeSibling(int i) {
    _siblings[i].dispose();
    setState(() => _siblings.removeAt(i));
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Gradient header ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _top,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_top, _bottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      _photoAvatar(),
                      const SizedBox(height: 12),
                      const Text('Personal Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 4),
                      Text('Keep your profile up to date',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

            // ── Form card ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  children: [
                    // ── Basic Details card ──────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Basic Details'),
                          _field('Full Name', fullName,
                              icon: Icons.badge_outlined),
                          _field('Baptismal Name', baptismName,
                              icon: Icons.church_outlined),

                          // DOB date picker
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: dobController,
                              readOnly: true,
                              onTap: _pickDate,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                              decoration: _dec(
                                'Date of Birth',
                                icon: Icons.cake_outlined,
                                suffix: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: _accent),
                              ),
                            ),
                          ),

                          _field('Place of Birth', birthPlace,
                              icon: Icons.location_city_outlined),

                          _sectionLabel('Education'),
                          _optionalField('Qualification', qualification,
                              icon: Icons.school_outlined),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Contact card ────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Contact'),

                          // Mobile
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: mobile,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _dec('Mobile Number',
                                  icon: Icons.phone_outlined,
                                  prefixText: '+91 '),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 10)
                                  return 'Enter a 10-digit number';
                                return null;
                              },
                            ),
                          ),

                          // Email
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                final ok = RegExp(
                                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                                    .hasMatch(v.trim());
                                if (!ok) return 'Enter a valid email';
                                return null;
                              },
                              decoration:
                                  _dec('Email', icon: Icons.email_outlined),
                            ),
                          ),

                          _sectionLabel('Health'),

                          // Blood group
                          Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: DropdownButtonFormField<String>(
                              value: selectedBloodGroup,
                              decoration: _dec('Blood Group',
                                  icon: Icons.bloodtype_outlined),
                              items: bloodGroups
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedBloodGroup = v),
                              validator: (v) =>
                                  v == null ? 'Please select' : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Family card ─────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Family'),

                          // Father
                          _field("Father's Name", father,
                              icon: Icons.man_outlined),
                          _optionalField(
                              "Father's Occupation", fatherOccupation,
                              icon: Icons.work_outline),

                          const SizedBox(height: 4),
                          const Divider(height: 24),

                          // Mother
                          _field("Mother's Name", mother,
                              icon: Icons.woman_outlined),
                          _optionalField(
                              "Mother's Occupation", motherOccupation,
                              icon: Icons.work_outline),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Siblings card ───────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _sectionLabelWidget('Siblings'),
                              TextButton.icon(
                                onPressed: _addSibling,
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 18, color: _accent),
                                label: const Text('Add',
                                    style: TextStyle(
                                        color: _accent,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),

                          if (_siblings.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No siblings added  •  all fields optional',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13),
                                ),
                              ),
                            ),

                          for (int i = 0; i < _siblings.length; i++)
                            _siblingTile(i),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Address card ────────────────────────────
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Address'),
                          _field('Address', address,
                              icon: Icons.home_outlined, maxLines: 3),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Save button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _accent.withOpacity(0.6),
                          elevation: 4,
                          shadowColor: _accent.withOpacity(0.5),
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
                                    letterSpacing: 1.2)),
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

  // ── Profile photo avatar (lives in the header) ────────────────────
  // This is the ONE avatar on the screen. Tapping it or the edit
  // badge opens the same picker used on the Documents screen.
  // Uploading writes straight to Firestore (documents.photoBase64),
  // so it's saved immediately — no need to hit the main SAVE button
  // for the photo specifically.
  Widget _photoAvatar() {
    ImageProvider? imgProvider;
    if (_pickedPhotoBytes != null) {
      imgProvider = MemoryImage(_pickedPhotoBytes!);
    } else if (_photoBase64.isNotEmpty) {
      try {
        imgProvider = MemoryImage(base64Decode(_photoBase64));
      } catch (_) {
        imgProvider = null;
      }
    }

    return GestureDetector(
      onTap: _isUploadingPhoto ? null : _showPhotoOptions,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
            ),
            child: ClipOval(
              child: imgProvider != null
                  ? Image(image: imgProvider, fit: BoxFit.cover)
                  : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 44),
            ),
          ),
          if (_isUploadingPhoto)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black38, shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          // Edit/upload badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                imgProvider != null
                    ? Icons.edit_rounded
                    : Icons.add_a_photo_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sibling tile ─────────────────────────────────────────────────
  Widget _siblingTile(int i) {
    final s = _siblings[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sibling ${i + 1}',
                  style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              GestureDetector(
                onTap: () => _removeSibling(i),
                child: const Icon(Icons.remove_circle_outline,
                    color: Colors.redAccent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _optionalField('Name', s.name,
              icon: Icons.person_outline),
          _optionalField('Occupation', s.occupation,
              icon: Icons.work_outline),
          _optionalField('Qualification', s.qualification,
              icon: Icons.school_outlined, isLast: true),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Required field
  Widget _field(
    String label,
    TextEditingController c, {
    IconData? icon,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          maxLines: maxLines,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          decoration: _dec(label, icon: icon),
        ),
      );

  /// Optional field — no validator, subtle "(optional)" hint
  Widget _optionalField(
    String label,
    TextEditingController c, {
    IconData? icon,
    bool isLast = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
        child: TextFormField(
          controller: c,
          decoration: _dec('$label  (optional)', icon: icon),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: _sectionLabelWidget(text),
      );

  Widget _sectionLabelWidget(String text) => Text(text,
      style: const TextStyle(
          color: _accent,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.6));

  InputDecoration _dec(String label,
          {IconData? icon, Widget? suffix, String? prefixText}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: _accent, size: 20)
            : null,
        prefixText: prefixText,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAF5FF),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple.shade100),
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
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
      );
}

// ── Reusable white card with shadow ──────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}
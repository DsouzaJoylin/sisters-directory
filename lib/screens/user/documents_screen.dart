import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────

class DocumentsData {
  final String aadhaarNumber;
  final String panNumber;
  final String passportNumber;
  final String voterId;
  final String drivingLicence;
  final String photoBase64; // stored as base64 string in Firestore

  const DocumentsData({
    this.aadhaarNumber = '',
    this.panNumber = '',
    this.passportNumber = '',
    this.voterId = '',
    this.drivingLicence = '',
    this.photoBase64 = '',
  });

  Map<String, dynamic> toMap() => {
        'aadhaarNumber': aadhaarNumber,
        'panNumber': panNumber,
        'passportNumber': passportNumber,
        'voterId': voterId,
        'drivingLicence': drivingLicence,
        'photoBase64': photoBase64,
      };

  factory DocumentsData.fromMap(Map<String, dynamic> m) => DocumentsData(
        aadhaarNumber: m['aadhaarNumber'] ?? '',
        panNumber: m['panNumber'] ?? '',
        passportNumber: m['passportNumber'] ?? '',
        voterId: m['voterId'] ?? '',
        drivingLicence: m['drivingLicence'] ?? '',
        photoBase64: m['photoBase64'] ?? '',
      );
}

// ─────────────────────────────────────────────
//  THEME TOKENS  (matches CommunityServiceScreen)
// ─────────────────────────────────────────────

class _C {
  static const gradStart = Color(0xFF6A3DE8);
  static const gradMid = Color(0xFF9B5DE5);
  static const gradEnd = Color(0xFFF15BB5);
  static const surface = Color(0xFFF8F6FF);
  static const cardBg = Colors.white;
  static const accent = Color(0xFF6A3DE8);
  static const accentLight = Color(0xFFEDE8FF);
  static const textPrimary = Color(0xFF1A0A3B);
  static const textSecondary = Color(0xFF6B5E8A);
  static const divider = Color(0xFFEAE4F8);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
}

const _grad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_C.gradStart, _C.gradMid, _C.gradEnd],
  stops: [0.0, 0.5, 1.0],
);

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────

class DocumentsScreen extends StatefulWidget {
  final String sisterId;
  const DocumentsScreen({super.key, required this.sisterId});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  late final TextEditingController _aadhaarCtrl;
  late final TextEditingController _panCtrl;
  late final TextEditingController _passportCtrl;
  late final TextEditingController _voterCtrl;
  late final TextEditingController _licenceCtrl;

  // Photo state (base64 stored in Firestore).
  // We keep the raw bytes for the live preview instead of a dart:io
  // File — File(path) has no meaning on web (no real filesystem path
  // is returned by the picker there), which is why photo upload
  // previously failed silently on computer/browser but worked on
  // phone. Uint8List + MemoryImage works identically on every
  // platform, so this is the one code path we need.
  String _photoBase64 = '';
  Uint8List? _pickedBytes;
  bool _isPickingPhoto = false;

  // ── Firestore ────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance.collection('sisters').doc(widget.sisterId);

  @override
  void initState() {
    super.initState();
    _aadhaarCtrl = TextEditingController();
    _panCtrl = TextEditingController();
    _passportCtrl = TextEditingController();
    _voterCtrl = TextEditingController();
    _licenceCtrl = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _passportCtrl.dispose();
    _voterCtrl.dispose();
    _licenceCtrl.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final snap = await _docRef.get();
      if (snap.exists) {
        final raw = snap.data()?['documents'];
        if (raw != null) {
          final d = DocumentsData.fromMap(Map<String, dynamic>.from(raw));
          _aadhaarCtrl.text = d.aadhaarNumber;
          _panCtrl.text = d.panNumber;
          _passportCtrl.text = d.passportNumber;
          _voterCtrl.text = d.voterId;
          _licenceCtrl.text = d.drivingLicence;
          _photoBase64 = d.photoBase64;
        }
      }
    } catch (e) {
      _snack('Failed to load: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Save ─────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fix the errors before saving.', error: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = DocumentsData(
        aadhaarNumber: _aadhaarCtrl.text.trim(),
        panNumber: _panCtrl.text.trim().toUpperCase(),
        passportNumber: _passportCtrl.text.trim().toUpperCase(),
        voterId: _voterCtrl.text.trim().toUpperCase(),
        drivingLicence: _licenceCtrl.text.trim().toUpperCase(),
        photoBase64: _photoBase64,
      );
      await _docRef.set(
          {'documents': data.toMap()}, SetOptions(merge: true));
      _snack('Documents saved successfully!');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Photo picker (no Firebase Storage) ───────
  // Works on both mobile and web/computer: we read the picked file
  // as bytes directly from the XFile the picker returns, and never
  // touch dart:io File. That's the part that's platform-safe.
  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
          source: source, maxWidth: 600, imageQuality: 75);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Convert to base64 for Firestore storage
      final b64 = base64Encode(bytes);

      // Rough size guard: Firestore doc limit is ~1 MB
      if (b64.length > 900000) {
        _snack('Image too large. Please choose a smaller photo.',
            error: true);
        return;
      }

      setState(() {
        _pickedBytes = bytes;
        _photoBase64 = b64;
      });
    } catch (e) {
      _snack('Could not pick photo: $e', error: true);
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
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
                      color: _C.divider,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Choose Photo',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _C.textPrimary)),
              const SizedBox(height: 16),

              // Camera option — only offered on mobile. Most desktop
              // browsers either lack a camera or image_picker's web
              // camera capture UX is unreliable, so we skip it there
              // and go straight to a file picker instead.
              if (!kIsWeb) ...[
                _sheetOption(
                    Icons.camera_alt_rounded, 'Take Photo', Colors.indigo,
                    () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                }),
                const SizedBox(height: 10),
              ],

              // On mobile this opens the gallery; on web this opens
              // the browser's native file picker — exactly what
              // "upload from computer" needs, no extra code required.
              _sheetOption(
                  kIsWeb
                      ? Icons.upload_file_rounded
                      : Icons.photo_library_rounded,
                  kIsWeb ? 'Upload from Computer' : 'Choose from Gallery',
                  _C.gradMid, () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              }),

              if (_photoBase64.isNotEmpty) ...[
                const SizedBox(height: 10),
                _sheetOption(
                    Icons.delete_rounded, 'Remove Photo', _C.error, () {
                  Navigator.pop(context);
                  setState(() {
                    _photoBase64 = '';
                    _pickedBytes = null;
                  });
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(
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

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? _C.error : _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      body: _isLoading
          ? _loader()
          : CustomScrollView(
              slivers: [
                _sliverHeader(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _photoCard(),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(children: [
                          _buildCard(
                            title: 'Identity Documents',
                            icon: Icons.badge_rounded,
                            children: [
                              _field(
                                ctrl: _aadhaarCtrl,
                                label: 'Aadhaar Number *',
                                icon: Icons.fingerprint_rounded,
                                hint: '12-digit number',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                  _AadhaarFormatter(),
                                ],
                                validator: (v) {
                                  final raw =
                                      v?.replaceAll(' ', '') ?? '';
                                  if (raw.isEmpty) {
                                    return 'Aadhaar number is required';
                                  }
                                  if (raw.length != 12) {
                                    return 'Aadhaar must be exactly 12 digits';
                                  }
                                  return null;
                                },
                                badge: _docBadge('AADHAAR', _C.gradStart),
                              ),
                              const SizedBox(height: 14),
                              _field(
                                ctrl: _panCtrl,
                                label: 'PAN Number (Optional)',
                                icon: Icons.credit_card_rounded,
                                hint: 'e.g. ABCDE1234F',
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(10),
                                  UpperCaseFormatter(),
                                ],
                                validator: (v) {
                                  final val = v?.trim().toUpperCase() ?? '';
                                  if (val.isEmpty) {
                                    // PAN is optional — nothing to validate
                                    return null;
                                  }
                                  if (val.length != 10) {
                                    return 'PAN must be exactly 10 characters';
                                  }
                                  final panRegex =
                                      RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                                  if (!panRegex.hasMatch(val)) {
                                    return 'Invalid PAN format (e.g. ABCDE1234F)';
                                  }
                                  return null;
                                },
                                badge: _docBadge('PAN', _C.gradMid),
                              ),
                              const SizedBox(height: 14),
                              _field(
                                ctrl: _passportCtrl,
                                label: 'Passport Number',
                                icon: Icons.travel_explore_rounded,
                                hint: 'Optional',
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(12),
                                  UpperCaseFormatter(),
                                ],
                                badge: _docBadge('PASSPORT', _C.gradEnd),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCard(
                            title: 'Other Documents',
                            icon: Icons.folder_special_rounded,
                            children: [
                              _field(
                                ctrl: _voterCtrl,
                                label: 'Voter ID',
                                icon: Icons.how_to_vote_rounded,
                                hint: 'Voter ID number',
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                  UpperCaseFormatter(),
                                ],
                                badge: _docBadge('VOTER', Colors.teal),
                              ),
                              const SizedBox(height: 14),
                              _field(
                                ctrl: _licenceCtrl,
                                label: 'Driving Licence (Optional)',
                                icon: Icons.directions_car_rounded,
                                hint: 'Licence number',
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                  UpperCaseFormatter(),
                                ],
                                badge: _docBadge('DL', Colors.orange),
                              ),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      _infoNote(),
                    ]),
                  ),
                ),
              ],
            ),
      floatingActionButton: _isLoading ? null : _saveFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Loader ────────────────────────────────────
  Widget _loader() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  const BoxDecoration(gradient: _grad, shape: BoxShape.circle),
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text('Loading Documents...',
                style: TextStyle(color: _C.textSecondary, fontSize: 14)),
          ],
        ),
      );

  // ── Sliver Header ─────────────────────────────
  Widget _sliverHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.gradStart,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 16),
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: _grad),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07))),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07))),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3))),
                          child: const Icon(Icons.folder_copy_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Documents & Photo',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3)),
                            Text('Sisters Directory',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 13)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        _chip(Icons.badge_rounded, 'Identity'),
                        const SizedBox(width: 8),
                        _chip(Icons.credit_card_rounded, 'PAN / Aadhaar'),
                        const SizedBox(width: 8),
                        _chip(Icons.photo_camera_rounded, 'Photo'),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );

  // ── Photo Card ────────────────────────────────
  Widget _photoCard() {
    ImageProvider? imgProvider;
    if (_pickedBytes != null) {
      imgProvider = MemoryImage(_pickedBytes!);
    } else if (_photoBase64.isNotEmpty) {
      imgProvider = MemoryImage(base64Decode(_photoBase64));
    }

    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _C.accent.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // card header
          _cardHeader('Profile Photo', Icons.photo_camera_rounded),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: imgProvider == null ? _grad : null,
                        border: Border.all(
                            color: _C.accentLight, width: 3),
                      ),
                      child: ClipOval(
                        child: imgProvider != null
                            ? Image(image: imgProvider, fit: BoxFit.cover)
                            : const Icon(Icons.person_rounded,
                                color: Colors.white, size: 52),
                      ),
                    ),
                    if (_isPickingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle),
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                // Info + button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        imgProvider != null
                            ? 'Photo added'
                            : 'No photo yet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: imgProvider != null
                                ? _C.accent
                                : _C.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        imgProvider != null
                            ? 'Saved to your profile.\nTap to change.'
                            : 'Add a profile photo.\nStored securely in your profile.',
                        style: const TextStyle(
                            fontSize: 12, color: _C.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _grad,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _C.gradMid.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  imgProvider != null
                                      ? Icons.edit_rounded
                                      : Icons.add_a_photo_rounded,
                                  color: Colors.white,
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(
                                imgProvider != null
                                    ? 'Change Photo'
                                    : 'Add Photo',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card ──────────────────────────────
  Widget _buildCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _C.accent.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(title, icon),
          Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children)),
        ],
      ),
    );
  }

  Widget _cardHeader(String title, IconData icon) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _C.gradStart.withOpacity(0.10),
            _C.gradEnd.withOpacity(0.05)
          ]),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                gradient: _grad,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _C.textPrimary)),
        ]),
      );

  // ── Field ─────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Widget? badge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              color: _C.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: _C.accent, size: 20),
            suffixIcon: badge,
            filled: true,
            fillColor: _C.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _C.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: _C.accent, width: 1.8)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _C.error)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: _C.error, width: 1.8)),
            labelStyle: const TextStyle(
                color: _C.textSecondary, fontSize: 13),
            hintStyle: const TextStyle(
                color: _C.textSecondary, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Document badge chip ───────────────────────
  Widget _docBadge(String label, Color color) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5)),
        ),
      );

  // ── Info note ─────────────────────────────────
  Widget _infoNote() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.accentLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.accent.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_rounded, color: _C.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Your data is private',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _C.accent)),
                  SizedBox(height: 4),
                  Text(
                    'All document numbers and your photo are stored '
                    'securely in your personal profile. They are never '
                    'shared without your consent.',
                    style: TextStyle(
                        fontSize: 12, color: _C.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Save FAB ──────────────────────────────────
  Widget _saveFAB() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: _isSaving ? null : _save,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: _isSaving
                  ? LinearGradient(colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade400
                    ])
                  : _grad,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: _C.gradMid.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  const Icon(Icons.save_rounded,
                      color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isSaving ? 'Saving...' : 'Save Documents',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  INPUT FORMATTERS
// ─────────────────────────────────────────────

/// Inserts spaces every 4 digits: 1234 5678 9012
class _AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

/// Forces all input to uppercase
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
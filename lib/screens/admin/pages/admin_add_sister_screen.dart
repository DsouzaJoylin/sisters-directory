import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/activity_service.dart';
import '../../../models/activity_model.dart';

// ---------------------------------------------------------------------
// Theme tokens — kept consistent with view_profile_screen.dart /
// documents_screen.dart / admin_dashboard_screen.dart.
// ---------------------------------------------------------------------
class _C {
  static const purple = Color(0xFF6A1B9A);
  static const blue = Color(0xFF00897B);
  static const green = Color(0xFF2E7D32);
  static const gold = Color(0xFFF9A825);
  static const teal = Color(0xFF6A3DE8);
  static const surface = Color(0xFFF5F0F8);
  static const textPrimary = Color(0xFF1A0A3B);
  static const textSecondary = Color(0xFF6B5E8A);
  static const divider = Color(0xFFEAE4F8);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
}

class AdminAddSisterScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const AdminAddSisterScreen({super.key, this.onSaved});

  @override
  State<AdminAddSisterScreen> createState() => _AdminAddSisterScreenState();
}

class _AdminAddSisterScreenState extends State<AdminAddSisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final Map<String, bool> _expanded = {
    'personal': true,
    'education': false,
    'formation': false,
    'religiousLife': false,
    'documents': false,
  };

  // ── Personal Information ─────────────────────────────────────────
  final _fullName = TextEditingController();
  final _baptismName = TextEditingController();
  final _dob = TextEditingController();
  final _birthPlace = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _bloodGroup = TextEditingController();
  final _fatherName = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _motherName = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _qualification = TextEditingController();
  final _address = TextEditingController();
  final List<Map<String, TextEditingController>> _siblings = [];

  String _status = 'approved';

  // ── Education ─────────────────────────────────────────────────────
  final _sslcSchool = TextEditingController();
  final _sslcYear = TextEditingController();
  final _pucCollege = TextEditingController();
  final _pucYear = TextEditingController();
  final _degree = TextEditingController();
  final _degreeCollege = TextEditingController();
  final _degreeYear = TextEditingController();
  final _pg = TextEditingController();
  final _pgCollege = TextEditingController();
  final _pgYear = TextEditingController();
  final _bed = TextEditingController();
  final _med = TextEditingController();
  final _otherQualifications = TextEditingController();
  final _talents = TextEditingController();

  // ── Formation ─────────────────────────────────────────────────────
  final _candidatePlace = TextEditingController();
  final _candidateFromYear = TextEditingController();
  final _candidateToYear = TextEditingController();
  final _candidateDirectress = TextEditingController();
  final _studentCandidatePlace = TextEditingController();
  final _studentCandidateFromYear = TextEditingController();
  final _studentCandidateToYear = TextEditingController();
  final _studentCandidateDirectress = TextEditingController();
  final _postulancyPlace = TextEditingController();
  final _postulancyFromYear = TextEditingController();
  final _postulancyToYear = TextEditingController();
  final _postulancyDirectress = TextEditingController();
  final _noviciatePlace = TextEditingController();
  final _novitiateFromYear = TextEditingController();
  final _novitiateToYear = TextEditingController();
  final _novitiateDirectress = TextEditingController();
  final _firstProfessionPlace = TextEditingController();
  final _firstProfessionYear = TextEditingController();
  final _firstProfessionDirectress = TextEditingController();
  final _finalProfessionPlace = TextEditingController();
  final _finalProfessionYear = TextEditingController();
  final _finalProfessionDirectress = TextEditingController();
  final _spiritualDirector = TextEditingController();

  // ── Religious Life ────────────────────────────────────────────────
  final _province = TextEditingController();
  final _congregation = TextEditingController();
  final _currentCommunity = TextEditingController();
  final _designation = TextEditingController();
  final _currentMission = TextEditingController();
  final List<Map<String, TextEditingController>> _communitiesServed = [];

  // ── Documents ─────────────────────────────────────────────────────
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _voterCtrl = TextEditingController();
  final _licenceCtrl = TextEditingController();
  String _photoBase64 = '';
  Uint8List? _pickedBytes;
  bool _isPickingPhoto = false;

  @override
  void dispose() {
    for (final c in [
      _fullName, _baptismName, _dob, _birthPlace, _mobile, _email,
      _bloodGroup, _fatherName, _fatherOccupation, _motherName,
      _motherOccupation, _qualification, _address,
      _sslcSchool, _sslcYear, _pucCollege, _pucYear, _degree,
      _degreeCollege, _degreeYear, _pg, _pgCollege, _pgYear, _bed, _med,
      _otherQualifications, _talents,
      _candidatePlace, _candidateFromYear, _candidateToYear,
      _candidateDirectress, _studentCandidatePlace,
      _studentCandidateFromYear, _studentCandidateToYear,
      _studentCandidateDirectress, _postulancyPlace, _postulancyFromYear,
      _postulancyToYear, _postulancyDirectress, _noviciatePlace,
      _novitiateFromYear, _novitiateToYear, _novitiateDirectress,
      _firstProfessionPlace, _firstProfessionYear,
      _firstProfessionDirectress, _finalProfessionPlace,
      _finalProfessionYear, _finalProfessionDirectress,
      _spiritualDirector,
      _province, _congregation, _currentCommunity, _designation,
      _currentMission,
      _aadhaarCtrl, _panCtrl, _passportCtrl, _voterCtrl, _licenceCtrl,
    ]) {
      c.dispose();
    }
    for (final s in _siblings) {
      for (final c in s.values) {
        c.dispose();
      }
    }
    for (final c in _communitiesServed) {
      for (final v in c.values) {
        v.dispose();
      }
    }
    super.dispose();
  }

  void _addSibling() {
    setState(() {
      _siblings.add({
        'name': TextEditingController(),
        'occupation': TextEditingController(),
        'qualification': TextEditingController(),
      });
    });
  }

  void _removeSibling(int index) {
    setState(() {
      for (final c in _siblings[index].values) {
        c.dispose();
      }
      _siblings.removeAt(index);
    });
  }

  void _addCommunity() {
    setState(() {
      _communitiesServed.add({
        'name': TextEditingController(),
        'from': TextEditingController(),
        'to': TextEditingController(),
        'ministry': TextEditingController(),
      });
    });
  }

  void _removeCommunity(int index) {
    setState(() {
      for (final c in _communitiesServed[index].values) {
        c.dispose();
      }
      _communitiesServed.removeAt(index);
    });
  }

  // ── Photo picker ──────────────────────────────────────────────────
  // Reads bytes via XFile.readAsBytes() rather than wrapping
  // picked.path in a dart:io File. dart:io has no filesystem on
  // Flutter Web, so constructing a File there throws
  // `Unsupported operation: _Namespace`. XFile.readAsBytes() works
  // identically across web, mobile, and desktop.
  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, maxWidth: 600, imageQuality: 75);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);

      if (b64.length > 900000) {
        _snack('Image too large. Please choose a smaller photo.', error: true);
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
              _sheetOption(Icons.camera_alt_rounded, 'Take Photo',
                  Colors.indigo, () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              }),
              const SizedBox(height: 10),
              _sheetOption(Icons.photo_library_rounded,
                  'Choose from Gallery', _C.teal, () {
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
                    color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
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

  ({int? day, int? month, int? year}) _parseDob() {
    final parts = _dob.text.trim().split('/');
    if (parts.length != 3) return (day: null, month: null, year: null);
    return (
      day: int.tryParse(parts[0]),
      month: int.tryParse(parts[1]),
      year: int.tryParse(parts[2]),
    );
  }

  // ── Save everything in one write ─────────────────────────────────
  Future<void> _save() async {
    if (_fullName.text.trim().isEmpty) {
      _snack('Full name is required.', error: true);
      setState(() => _expanded['personal'] = true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _snack('Please fix the errors before saving.', error: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final sisterRef = FirebaseFirestore.instance.collection('sisters').doc();
      final batch = FirebaseFirestore.instance.batch();

      final formattedMobile =
          _mobile.text.trim().isEmpty ? '' : '+91${_mobile.text.trim()}';

      final dobParsed = _parseDob();

      batch.set(sisterRef, {
        'fullName': _fullName.text.trim(),
        'baptismName': _baptismName.text.trim(),
        'dob': _dob.text.trim(),
        if (dobParsed.month != null) 'birthMonth': dobParsed.month,
        if (dobParsed.day != null) 'birthDay': dobParsed.day,
        if (dobParsed.year != null) 'birthYear': dobParsed.year,
        'birthPlace': _birthPlace.text.trim(),
        'mobileNumber': formattedMobile,
        'email': _email.text.trim(),
        // Also written at the top level (duplicating
        // religiousLife.currentCommunity below) because SisterModel and
        // the dashboard's community search both read the top-level
        // 'community' field, not the nested one inside the
        // religiousLife subcollection.
        'community': _currentCommunity.text.trim(),
        'bloodGroup': _bloodGroup.text.trim(),
        'fatherName': _fatherName.text.trim(),
        'fatherOccupation': _fatherOccupation.text.trim(),
        'motherName': _motherName.text.trim(),
        'motherOccupation': _motherOccupation.text.trim(),
        'qualification': _qualification.text.trim(),
        'address': _address.text.trim(),
        'status': _status,
        'createdAt': FieldValue.serverTimestamp(),
        'siblings': _siblings
            .map((s) => {
                  'name': s['name']!.text.trim(),
                  'occupation': s['occupation']!.text.trim(),
                  'qualification': s['qualification']!.text.trim(),
                })
            .where((s) => s['name']!.isNotEmpty)
            .toList(),
        'education': {
          'sslcSchool': _sslcSchool.text.trim(),
          'sslcYear': _sslcYear.text.trim(),
          'pucCollege': _pucCollege.text.trim(),
          'pucYear': _pucYear.text.trim(),
          'degree': _degree.text.trim(),
          'degreeCollege': _degreeCollege.text.trim(),
          'degreeYear': _degreeYear.text.trim(),
          'pg': _pg.text.trim(),
          'pgCollege': _pgCollege.text.trim(),
          'pgYear': _pgYear.text.trim(),
          'bed': _bed.text.trim(),
          'med': _med.text.trim(),
          'otherQualifications': _otherQualifications.text.trim(),
          'Talents': _talents.text.trim(),
        },
        'documents': {
          'aadhaarNumber': _aadhaarCtrl.text.trim(),
          'panNumber': _panCtrl.text.trim().toUpperCase(),
          'passportNumber': _passportCtrl.text.trim().toUpperCase(),
          'voterId': _voterCtrl.text.trim().toUpperCase(),
          'drivingLicence': _licenceCtrl.text.trim().toUpperCase(),
          'photoBase64': _photoBase64,
        },
      });

      batch.set(sisterRef.collection('formation').doc('details'), {
        'candidatePlace': _candidatePlace.text.trim(),
        'candidateFromYear': _candidateFromYear.text.trim(),
        'candidateToYear': _candidateToYear.text.trim(),
        'candidateDirectress': _candidateDirectress.text.trim(),
        'studentCandidatePlace': _studentCandidatePlace.text.trim(),
        'studentCandidateFromYear': _studentCandidateFromYear.text.trim(),
        'studentCandidateToYear': _studentCandidateToYear.text.trim(),
        'studentCandidateDirectress': _studentCandidateDirectress.text.trim(),
        'postulancyPlace': _postulancyPlace.text.trim(),
        'postulancyFromYear': _postulancyFromYear.text.trim(),
        'postulancyToYear': _postulancyToYear.text.trim(),
        'postulancyDirectress': _postulancyDirectress.text.trim(),
        'noviciatePlace': _noviciatePlace.text.trim(),
        'novitiateFromYear': _novitiateFromYear.text.trim(),
        'novitiateToYear': _novitiateToYear.text.trim(),
        'novitiateDirectress': _novitiateDirectress.text.trim(),
        'firstProfessionPlace': _firstProfessionPlace.text.trim(),
        'firstProfessionYear': _firstProfessionYear.text.trim(),
        'firstProfessionDirectress': _firstProfessionDirectress.text.trim(),
        'finalProfessionPlace': _finalProfessionPlace.text.trim(),
        'finalProfessionYear': _finalProfessionYear.text.trim(),
        'finalProfessionDirectress': _finalProfessionDirectress.text.trim(),
        'spiritualDirector': _spiritualDirector.text.trim(),
      });

      batch.set(sisterRef.collection('religiousLife').doc('details'), {
        'province': _province.text.trim(),
        'congregation': _congregation.text.trim(),
        'currentCommunity': _currentCommunity.text.trim(),
        'designation': _designation.text.trim(),
        'currentMission': _currentMission.text.trim(),
        'communitiesServed': _communitiesServed
            .map((c) => {
                  'name': c['name']!.text.trim(),
                  'from': c['from']!.text.trim(),
                  'to': c['to']!.text.trim(),
                  'ministry': c['ministry']!.text.trim(),
                })
            .where((c) => c['name']!.isNotEmpty)
            .toList(),
      });

      await batch.commit();

      try {
        await ActivityService.instance.logActivity(
          type: ActivityType.sisterRegistered,
          description: '${_fullName.text.trim()} joined the directory',
          targetSisterUid: sisterRef.id,
          targetSisterName: _fullName.text.trim(),
        );
      } catch (e) {
        debugPrint('⚠️ [AddSister] Failed to log activity: $e');
      }

      _snack('${_fullName.text.trim()} added successfully!');

      if (mounted) {
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        title: const Text('Add Sister'),
        backgroundColor: _C.purple,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _sectionCard(
              key: 'personal',
              title: 'Personal Information',
              icon: Icons.person,
              color: _C.purple,
              children: [
                _field(_fullName, 'Full Name *', required: true),
                _field(_baptismName, 'Baptismal Name'),
                _field(_dob, 'Date of Birth (e.g. 21/01/1996)'),
                _field(_birthPlace, 'Place of Birth'),
                _field(_mobile, 'Mobile Number',
                    keyboardType: TextInputType.phone),
                _statusDropdown(),
                _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
                _field(_bloodGroup, 'Blood Group'),
                _field(_fatherName, "Father's Name"),
                _field(_fatherOccupation, "Father's Occupation"),
                _field(_motherName, "Mother's Name"),
                _field(_motherOccupation, "Mother's Occupation"),
                _field(_qualification, 'Qualification'),
                _field(_address, 'Address', maxLines: 2),
                const SizedBox(height: 12),
                _listSectionHeader('Siblings', _addSibling),
                for (int i = 0; i < _siblings.length; i++)
                  _siblingRow(i),
              ],
            ),
            _sectionCard(
              key: 'education',
              title: 'Education',
              icon: Icons.school,
              color: _C.blue,
              children: [
                _field(_sslcSchool, 'SSLC / 10th School'),
                _field(_sslcYear, 'SSLC Year'),
                _field(_pucCollege, 'PUC / 12th College'),
                _field(_pucYear, 'PUC Year'),
                _field(_degree, 'Degree'),
                _field(_degreeCollege, 'Degree College'),
                _field(_degreeYear, 'Degree Year'),
                _field(_pg, 'Post Graduation'),
                _field(_pgCollege, 'PG College'),
                _field(_pgYear, 'PG Year'),
                _field(_bed, 'B.Ed'),
                _field(_med, 'M.Ed'),
                _field(_otherQualifications, 'Other Qualifications'),
                _field(_talents, 'Talents & Skills'),
              ],
            ),
            _sectionCard(
              key: 'formation',
              title: 'Formation',
              icon: Icons.auto_stories,
              color: _C.green,
              children: [
                _field(_candidatePlace, 'Candidate Place'),
                _field(_candidateFromYear, 'Candidate From Year'),
                _field(_candidateToYear, 'Candidate To Year'),
                _field(_candidateDirectress, 'Candidate Directress'),
                _field(_studentCandidatePlace, 'Student Candidate Place'),
                _field(_studentCandidateFromYear,
                    'Student Candidate From Year'),
                _field(_studentCandidateToYear, 'Student Candidate To Year'),
                _field(_studentCandidateDirectress,
                    'Student Candidate Directress'),
                _field(_postulancyPlace, 'Postulancy Place'),
                _field(_postulancyFromYear, 'Postulancy From Year'),
                _field(_postulancyToYear, 'Postulancy To Year'),
                _field(_postulancyDirectress, 'Postulancy Directress'),
                _field(_noviciatePlace, 'Novitiate Place'),
                _field(_novitiateFromYear, 'Novitiate From Year'),
                _field(_novitiateToYear, 'Novitiate To Year'),
                _field(_novitiateDirectress, 'Novitiate Directress'),
                _field(_firstProfessionPlace, 'First Profession Place'),
                _field(_firstProfessionYear, 'First Profession Year'),
                _field(_firstProfessionDirectress, 'Junior Directress'),
                _field(_finalProfessionPlace, 'Final Profession Place'),
                _field(_finalProfessionYear, 'Final Profession Year'),
                _field(_finalProfessionDirectress, 'Tertian Directress'),
                _field(_spiritualDirector, 'Spiritual Director'),
              ],
            ),
            _sectionCard(
              key: 'religiousLife',
              title: 'Religious Life & Community Service',
              icon: Icons.church,
              color: _C.gold,
              children: [
                _field(_province, 'Province'),
                _field(_congregation, 'Congregation'),
                _field(_currentCommunity, 'Current Community'),
                _field(_designation, 'Designation'),
                _field(_currentMission, 'Current Mission'),
                const SizedBox(height: 12),
                _listSectionHeader('Communities Served', _addCommunity),
                for (int i = 0; i < _communitiesServed.length; i++)
                  _communityRow(i),
              ],
            ),
            _sectionCard(
              key: 'documents',
              title: 'Documents & Photo',
              icon: Icons.badge,
              color: _C.teal,
              children: [
                _photoPicker(),
                const SizedBox(height: 14),
                _field(_aadhaarCtrl, 'Aadhaar Number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ]),
                _field(_panCtrl, 'PAN Number',
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(10)]),
                _field(_passportCtrl, 'Passport Number',
                    textCapitalization: TextCapitalization.characters),
                _field(_voterCtrl, 'Voter ID',
                    textCapitalization: TextCapitalization.characters),
                _field(_licenceCtrl, 'Driving Licence',
                    textCapitalization: TextCapitalization.characters),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _saveFAB(),
    );
  }

  Widget _statusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: InputDecoration(
          labelText: 'Profile Status',
          isDense: true,
          filled: true,
          fillColor: _C.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        items: const [
          DropdownMenuItem(value: 'approved', child: Text('Approved')),
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _status = v);
        },
      ),
    );
  }

  Widget _sectionCard({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final isOpen = _expanded[key] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded[key] = !isOpen),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      color: color),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: _C.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _listSectionHeader(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _C.textSecondary)),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _siblingRow(int index) {
    final s = _siblings[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Sibling ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _C.error),
                onPressed: () => _removeSibling(index),
              ),
            ],
          ),
          _field(s['name']!, 'Name'),
          _field(s['occupation']!, 'Occupation'),
          _field(s['qualification']!, 'Qualification'),
        ],
      ),
    );
  }

  Widget _communityRow(int index) {
    final c = _communitiesServed[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Community ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _C.error),
                onPressed: () => _removeCommunity(index),
              ),
            ],
          ),
          _field(c['name']!, 'Community Name'),
          _field(c['from']!, 'From'),
          _field(c['to']!, 'To'),
          _field(c['ministry']!, 'Ministry'),
        ],
      ),
    );
  }

  Widget _photoPicker() {
    ImageProvider? imgProvider;
    if (_pickedBytes != null) {
      imgProvider = MemoryImage(_pickedBytes!);
    } else if (_photoBase64.isNotEmpty) {
      imgProvider = MemoryImage(base64Decode(_photoBase64));
    }

    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.teal.withOpacity(0.1),
                border: Border.all(color: _C.divider, width: 2),
              ),
              child: ClipOval(
                child: imgProvider != null
                    ? Image(image: imgProvider, fit: BoxFit.cover)
                    : const Icon(Icons.person, color: _C.teal, size: 40),
              ),
            ),
            if (_isPickingPhoto)
              const Positioned.fill(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showPhotoOptions,
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: Text(imgProvider != null ? 'Change Photo' : 'Add Photo'),
            style: OutlinedButton.styleFrom(foregroundColor: _C.teal),
          ),
        ),
      ],
    );
  }

  Widget _saveFAB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Saving...' : 'Save Sister'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
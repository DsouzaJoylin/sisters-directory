import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViewProfileScreen extends StatefulWidget {
  final String sisterId;
  const ViewProfileScreen({super.key, required this.sisterId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

// ── One editable row inside a section ────────────────────────────────
class FieldSpec {
  final String key;
  final String label;
  final TextEditingController controller;
  FieldSpec(this.key, this.label, String initial)
      : controller = TextEditingController(text: initial);
}

// ── One card on the page ─────────────────────────────────────────────
class ProfileSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<FieldSpec> fields;
  bool isEditing = false;
  bool saving = false;
  // Read-only extra content (siblings / communities served)
  final List<Map<String, String>> listItems;
  final List<String> listItemFields;

  ProfileSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    this.listItems = const [],
    this.listItemFields = const [],
  });
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  bool loading = true;
  Map<String, dynamic> mainData = {};
  Map<String, dynamic> formationData = {};
  Map<String, dynamic> religiousLifeData = {};

  // Decoded profile photo, if present under documents.photoBase64.
  String _photoBase64 = '';

  late ProfileSection personalInfo;
  late ProfileSection education;
  late ProfileSection formation;
  late ProfileSection religiousLife;
  late ProfileSection documents;
  late List<ProfileSection> sections;

  static const _purple = Color(0xFF6A1B9A);
  static const _blue = Color(0xFF00897B); // matches education screen's teal
  static const _green = Color(0xFF2E7D32);
  static const _gold = Color(0xFFF9A825);
  static const _teal = Color(0xFF6A3DE8); // matches documents screen

  DocumentReference<Map<String, dynamic>> get _mainDoc =>
      FirebaseFirestore.instance.collection('sisters').doc(widget.sisterId);

  String _s(dynamic v) => v?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    for (final s in sections) {
      for (final f in s.fields) {
        f.controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final mainSnap = await _mainDoc.get();
      mainData = mainSnap.data() ?? {};

      final formationSnap =
          await _mainDoc.collection('formation').doc('details').get();
      formationData = formationSnap.data() ?? {};

      final religiousLifeSnap =
          await _mainDoc.collection('religiousLife').doc('details').get();
      religiousLifeData = religiousLifeSnap.data() ?? {};

      final education0 =
          (mainData['education'] as Map?)?.cast<String, dynamic>() ?? {};
      final documents0 =
          (mainData['documents'] as Map?)?.cast<String, dynamic>() ?? {};

      // Profile photo is stored as a base64 string under
      // documents.photoBase64 (see AdminAddSisterScreen._save()).
      _photoBase64 = _s(documents0['photoBase64']);

      // ── Personal Information (flat top-level fields) ──────────────
      personalInfo = ProfileSection(
        title: "Personal Information",
        icon: Icons.person,
        color: _purple,
        fields: [
          FieldSpec('fullName', "Full Name", _s(mainData['fullName'])),
          FieldSpec('baptismName', "Baptismal Name", _s(mainData['baptismName'])),
          FieldSpec('dob', "Date of Birth", _s(mainData['dob'])),
          FieldSpec('birthPlace', "Place of Birth", _s(mainData['birthPlace'])),
          // FIXED: AdminAddSisterScreen (and other screens) save this as
          // 'mobileNumber' in E.164 format (+91XXXXXXXXXX), not 'mobile'.
          // Reading the wrong key meant this field always showed blank
          // for any sister added through AdminAddSisterScreen.
          FieldSpec('mobileNumber', "Mobile Number", _s(mainData['mobileNumber'])),
          FieldSpec('email', "Email", _s(mainData['email'])),
          FieldSpec('bloodGroup', "Blood Group", _s(mainData['bloodGroup'])),
          FieldSpec('fatherName', "Father's Name", _s(mainData['fatherName'])),
          FieldSpec('fatherOccupation', "Father's Occupation", _s(mainData['fatherOccupation'])),
          FieldSpec('motherName', "Mother's Name", _s(mainData['motherName'])),
          FieldSpec('motherOccupation', "Mother's Occupation", _s(mainData['motherOccupation'])),
          FieldSpec('qualification', "Qualification", _s(mainData['qualification'])),
          FieldSpec('address', "Address", _s(mainData['address'])),
        ],
        listItems: ((mainData['siblings'] as List?) ?? [])
            .map<Map<String, String>>((s) => {
                  'Name': _s((s as Map)['name']),
                  'Occupation': _s(s['occupation']),
                  'Qualification': _s(s['qualification']),
                })
            .toList(),
        listItemFields: const ['Name', 'Occupation', 'Qualification'],
      );

      // ── Education (nested map: education) ─────────────────────────
      education = ProfileSection(
        title: "Education",
        icon: Icons.school,
        color: _blue,
        fields: [
          FieldSpec('sslcSchool', "SSLC / 10th School", _s(education0['sslcSchool'])),
          FieldSpec('sslcYear', "SSLC Year", _s(education0['sslcYear'])),
          FieldSpec('pucCollege', "PUC / 12th College", _s(education0['pucCollege'])),
          FieldSpec('pucYear', "PUC Year", _s(education0['pucYear'])),
          FieldSpec('degree', "Degree", _s(education0['degree'])),
          FieldSpec('degreeCollege', "Degree College", _s(education0['degreeCollege'])),
          FieldSpec('degreeYear', "Degree Year", _s(education0['degreeYear'])),
          FieldSpec('pg', "Post Graduation", _s(education0['pg'])),
          FieldSpec('pgCollege', "PG College", _s(education0['pgCollege'])),
          FieldSpec('pgYear', "PG Year", _s(education0['pgYear'])),
          FieldSpec('bed', "B.Ed", _s(education0['bed'])),
          FieldSpec('med', "M.Ed", _s(education0['med'])),
          FieldSpec('otherQualifications', "Other Qualifications", _s(education0['otherQualifications'])),
          FieldSpec('Talents', "Talents & Skills", _s(education0['Talents'])),
        ],
      );

      // ── Formation (subcollection: formation/details) ──────────────
      formation = ProfileSection(
        title: "Formation",
        icon: Icons.auto_stories,
        color: _green,
        fields: [
          FieldSpec('candidatePlace', "Candidate Place", _s(formationData['candidatePlace'])),
          FieldSpec('candidateFromYear', "Candidate From Year", _s(formationData['candidateFromYear'])),
          FieldSpec('candidateToYear', "Candidate To Year", _s(formationData['candidateToYear'])),
          FieldSpec('candidateDirectress', "Candidate Directress", _s(formationData['candidateDirectress'])),
          FieldSpec('studentCandidatePlace', "Student Candidate Place", _s(formationData['studentCandidatePlace'])),
          FieldSpec('studentCandidateFromYear', "Student Candidate From Year", _s(formationData['studentCandidateFromYear'])),
          FieldSpec('studentCandidateToYear', "Student Candidate To Year", _s(formationData['studentCandidateToYear'])),
          FieldSpec('studentCandidateDirectress', "Student Candidate Directress", _s(formationData['studentCandidateDirectress'])),
          FieldSpec('postulancyPlace', "Postulancy Place", _s(formationData['postulancyPlace'])),
          FieldSpec('postulancyFromYear', "Postulancy From Year", _s(formationData['postulancyFromYear'])),
          FieldSpec('postulancyToYear', "Postulancy To Year", _s(formationData['postulancyToYear'])),
          FieldSpec('postulancyDirectress', "Postulancy Directress", _s(formationData['postulancyDirectress'])),
          FieldSpec('noviciatePlace', "Novitiate Place", _s(formationData['noviciatePlace'])),
          FieldSpec('novitiateFromYear', "Novitiate From Year", _s(formationData['novitiateFromYear'])),
          FieldSpec('novitiateToYear', "Novitiate To Year", _s(formationData['novitiateToYear'])),
          FieldSpec('novitiateDirectress', "Novitiate Directress", _s(formationData['novitiateDirectress'])),
          FieldSpec('firstProfessionPlace', "First Profession Place", _s(formationData['firstProfessionPlace'])),
          FieldSpec('firstProfessionYear', "First Profession Year", _s(formationData['firstProfessionYear'])),
          FieldSpec('firstProfessionDirectress', "Junior Directress", _s(formationData['firstProfessionDirectress'])),
          FieldSpec('finalProfessionPlace', "Final Profession Place", _s(formationData['finalProfessionPlace'])),
          FieldSpec('finalProfessionYear', "Final Profession Year", _s(formationData['finalProfessionYear'])),
          FieldSpec('finalProfessionDirectress', "Tertian Directress", _s(formationData['finalProfessionDirectress'])),
          FieldSpec('spiritualDirector', "Spiritual Director", _s(formationData['spiritualDirector'])),
        ],
      );

      // ── Religious Life (subcollection: religiousLife/details) ─────
      religiousLife = ProfileSection(
        title: "Religious Life",
        icon: Icons.church,
        color: _gold,
        fields: [
          FieldSpec('province', "Province", _s(religiousLifeData['province'])),
          FieldSpec('congregation', "Congregation", _s(religiousLifeData['congregation'])),
          FieldSpec('currentCommunity', "Current Community", _s(religiousLifeData['currentCommunity'])),
          FieldSpec('designation', "Designation", _s(religiousLifeData['designation'])),
          FieldSpec('currentMission', "Current Mission", _s(religiousLifeData['currentMission'])),
        ],
        listItems: ((religiousLifeData['communitiesServed'] as List?) ?? [])
            .map<Map<String, String>>((c) => {
                  'Community': _s((c as Map)['name']),
                  'From': _s(c['from']),
                  'To': _s(c['to']),
                  'Ministry': _s(c['ministry']),
                })
            .toList(),
        listItemFields: const ['Community', 'From', 'To', 'Ministry'],
      );

      // ── Documents (nested map: documents) ──────────────────────────
      documents = ProfileSection(
        title: "Documents",
        icon: Icons.badge,
        color: _teal,
        fields: [
          FieldSpec('aadhaarNumber', "Aadhaar Number", _s(documents0['aadhaarNumber'])),
          FieldSpec('panNumber', "PAN Number", _s(documents0['panNumber'])),
          FieldSpec('passportNumber', "Passport Number", _s(documents0['passportNumber'])),
          FieldSpec('voterId', "Voter ID", _s(documents0['voterId'])),
          FieldSpec('drivingLicence', "Driving Licence", _s(documents0['drivingLicence'])),
        ],
      );

      sections = [personalInfo, education, formation, religiousLife, documents];

      setState(() => loading = false);
    } catch (e) {
      setState(() => loading = false);
    }
  }

  bool _sectionHasData(ProfileSection s) =>
      s.fields.any((f) => f.controller.text.trim().isNotEmpty) ||
      s.listItems.isNotEmpty;

  // ── Save ────────────────────────────────────────────────────────────
  Future<void> saveSection(ProfileSection section) async {
    setState(() => section.saving = true);
    try {
      final updates = <String, dynamic>{
        for (final f in section.fields) f.key: f.controller.text.trim(),
      };

      if (section == personalInfo) {
        await _mainDoc.set(updates, SetOptions(merge: true));
        mainData.addAll(updates);
      } else if (section == education) {
        await _mainDoc.set({'education': updates}, SetOptions(merge: true));
        (mainData['education'] as Map?)?.addAll(updates);
      } else if (section == documents) {
        await _mainDoc.set({'documents': updates}, SetOptions(merge: true));
        (mainData['documents'] as Map?)?.addAll(updates);
      } else if (section == formation) {
        await _mainDoc
            .collection('formation')
            .doc('details')
            .set(updates, SetOptions(merge: true));
        formationData.addAll(updates);
      } else if (section == religiousLife) {
        await _mainDoc
            .collection('religiousLife')
            .doc('details')
            .set(updates, SetOptions(merge: true));
        religiousLifeData.addAll(updates);

        // Keep the main doc's top-level 'community' field (used by
        // SisterModel and the dashboard's community search) in sync with
        // religiousLife.currentCommunity whenever it's edited here —
        // otherwise search would drift out of date after every edit.
        if (updates.containsKey('currentCommunity')) {
          await _mainDoc.set(
            {'community': updates['currentCommunity']},
            SetOptions(merge: true),
          );
          mainData['community'] = updates['currentCommunity'];
        }
      }

      setState(() {
        section.isEditing = false;
        section.saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${section.title} updated")),
        );
      }
    } catch (e) {
      setState(() => section.saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save ${section.title}: $e")),
        );
      }
    }
  }

  // ── PDF export ────────────────────────────────────────────────────
  Future<void> exportPdf() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text("Sister Profile",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(_s(mainData['fullName']), style: const pw.TextStyle(fontSize: 13)),
          pw.Divider(),
          pw.SizedBox(height: 8),
          for (final section in sections)
            if (_sectionHasData(section))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(section.title,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.2),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        for (final f in section.fields)
                          if (f.controller.text.trim().isNotEmpty)
                            pw.TableRow(children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Text(f.label, style: const pw.TextStyle(fontSize: 8.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Text(f.controller.text, style: const pw.TextStyle(fontSize: 8.5)),
                              ),
                            ]),
                      ],
                    ),
                    if (section.listItems.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                        children: [
                          pw.TableRow(children: [
                            for (final h in section.listItemFields)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Text(h,
                                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ),
                          ]),
                          for (final item in section.listItems)
                            pw.TableRow(children: [
                              for (final h in section.listItemFields)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(3),
                                  child: pw.Text(item[h] ?? '', style: const pw.TextStyle(fontSize: 8)),
                                ),
                            ]),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: "${_s(mainData['fullName']).isEmpty ? 'profile' : _s(mainData['fullName'])}_profile.pdf",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0F8),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        // Shows the sister's name once loaded, falling back to a generic
        // title while loading or if no name is set yet.
        title: Text(
          !loading && _s(mainData['fullName']).isNotEmpty
              ? _s(mainData['fullName'])
              : "Profile",
        ),
        actions: [
          if (!loading)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Print / Export as PDF",
              onPressed: exportPdf,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sections.every((s) => !_sectionHasData(s)) && _photoBase64.isEmpty
              ? const Center(child: Text("No profile data found yet."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _profileHeader(),
                    const SizedBox(height: 14),
                    for (final section in sections) ...[
                      sectionCard(section),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
    );
  }

  // ── Profile photo header ────────────────────────────────────────────
  Widget _profileHeader() {
    ImageProvider? photo;
    if (_photoBase64.isNotEmpty) {
      try {
        photo = MemoryImage(base64Decode(_photoBase64));
      } catch (_) {
        photo = null;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 8)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: _purple.withOpacity(0.1),
            backgroundImage: photo,
            child: photo == null
                ? Icon(Icons.person, size: 48, color: _purple.withOpacity(0.6))
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _s(mainData['fullName']).isEmpty ? 'Unnamed Sister' : _s(mainData['fullName']),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (_s(mainData['designation']).isNotEmpty ||
              _s(religiousLifeData['designation']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _s(religiousLifeData['designation']).isNotEmpty
                    ? _s(religiousLifeData['designation'])
                    : _s(mainData['designation']),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget sectionCard(ProfileSection section) {
    final hasData = _sectionHasData(section);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: section.color.withOpacity(0.15),
                child: Icon(section.icon, color: section.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              if (section.saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: () {
                    if (section.isEditing) {
                      saveSection(section);
                    } else {
                      setState(() => section.isEditing = true);
                    }
                  },
                  child: Text(section.isEditing ? "SAVE" : "EDIT"),
                ),
            ],
          ),
          const Divider(height: 20),
          if (!hasData)
            Text(
              "No ${section.title.toLowerCase()} added yet.",
              style: TextStyle(color: Colors.grey.shade600),
            )
          else ...[
            for (final f in section.fields)
              if (section.isEditing || f.controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: section.isEditing
                      // ── Editing mode: label above the input, same as before ──
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: section.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: f.controller,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        )
                      // ── View mode: single inline line, e.g. "Full Name: Joylin" ──
                      : RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87),
                            children: [
                              TextSpan(
                                text: '${f.label}: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: section.color,
                                ),
                              ),
                              TextSpan(
                                text: f.controller.text.isEmpty
                                    ? '—'
                                    : f.controller.text,
                              ),
                            ],
                          ),
                        ),
                ),
            if (section.listItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                section == personalInfo ? "Siblings" : "Communities Served",
                style: TextStyle(
                  fontSize: 12,
                  color: section.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in section.listItems)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: section.color.withOpacity(0.2)),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      for (final key in section.listItemFields)
                        if ((item[key] ?? '').isNotEmpty)
                          Text(
                            "$key: ${item[key]}",
                            style: const TextStyle(fontSize: 13),
                          ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
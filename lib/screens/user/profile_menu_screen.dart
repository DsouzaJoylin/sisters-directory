import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import 'personal_information_screen.dart';
import 'education_screen.dart';
import 'formation_screen.dart';
import 'religious_life_screen.dart';
import 'documents_screen.dart';
import 'view_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ProfileMenuScreen
// ─────────────────────────────────────────────────────────────────
// A single hub that routes to each section as its own screen —
// mirrors the five sections in AdminAddSisterScreen (Personal,
// Education, Formation, Religious Life, Documents & Photo), but
// instead of collapsible cards in one long admin form, each section
// here is its own full screen for the self-service (sister) flow.
// A green check badge shows which sections already have data saved,
// so a sister can see her profile-completion progress at a glance.
class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  static const Color _top = Color(0xFF6A1B9A);
  static const Color _bottom = Color(0xFFCE93D8);
  static const Color _accent = Color(0xFF8E24AA);

  bool _isLoading = true;
  String? _loadError;
  Map<String, dynamic>? _sisterData;
  Map<String, dynamic>? _formationData;
  Map<String, dynamic>? _religiousLifeData;

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
  }

  Future<void> _loadCompletionStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final sisterRef =
        FirebaseFirestore.instance.collection('sisters').doc(uid);

    try {
      final results = await Future.wait([
        sisterRef.get(),
        sisterRef.collection('formation').doc('details').get(),
        sisterRef.collection('religiousLife').doc('details').get(),
      ]);

      if (!mounted) return;
      setState(() {
        _sisterData = results[0].exists ? results[0].data() : null;
        _formationData = results[1].exists ? results[1].data() : null;
        _religiousLifeData = results[2].exists ? results[2].data() : null;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      // Without this catch, any failed read here (most commonly a
      // Firestore permission-denied error) left _isLoading stuck at
      // true forever with no feedback — the spinner that never stops.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  // Simple, cheap "does this section have anything filled in" checks
  // used only to show a green check badge — not a strict validator.
  bool get _personalDone =>
      (_sisterData?['fullName'] as String?)?.isNotEmpty == true &&
      (_sisterData?['mobileNumber'] as String?)?.isNotEmpty == true;

  bool get _educationDone {
    final edu = _sisterData?['education'];
    if (edu is! Map) return false;
    return edu.values.any((v) => v is String && v.isNotEmpty);
  }

  bool get _formationDone =>
      _formationData != null &&
      _formationData!.values.any((v) => v is String && v.isNotEmpty);

  bool get _religiousLifeDone =>
      (_religiousLifeData?['currentCommunity'] as String?)?.isNotEmpty ==
      true;

  bool get _documentsDone {
    final docs = _sisterData?['documents'];
    if (docs is! Map) return false;
    return (docs['aadhaarNumber'] as String?)?.isNotEmpty == true ||
        (docs['photoBase64'] as String?)?.isNotEmpty == true;
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    // Refresh completion badges after returning, in case the sister
    // just saved something on the section screen.
    if (mounted) {
      setState(() => _isLoading = true);
      _loadCompletionStatus();
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // AuthGate (at the app root) listens to authStateChanges and
      // automatically swaps to LoginScreen once this completes — same
      // pattern LoginScreen itself relies on. No manual navigation here;
      // pushing a route manually would fight with AuthGate's own rebuild.
      await AuthService.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: _top,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Log Out',
                onPressed: _confirmLogout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background photo
                  Image.asset(
                    'assets/images/jesus_calling.png',
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay so avatar + text stay readable
                  // over the photo.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _top.withOpacity(0.75),
                          _bottom.withOpacity(0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _headerAvatar(),
                            const SizedBox(height: 10),
                            Text(
                              _headerName(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontStyle: _headerName() ==
                                        'Complete your profile'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: _accent)),
                    ),
                  )
                : _loadError != null
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 40),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: SelectableText(
                                  'Could not load your profile:\n$_loadError',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() => _isLoading = true);
                                  _loadCompletionStatus();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                    delegate: SliverChildListDelegate([
                      _sectionTile(
                        title: 'Personal Information',
                        subtitle: 'Name, DOB, contact, family details',
                        icon: Icons.person_rounded,
                        color: _accent,
                        done: _personalDone,
                        onTap: () => _navigateAndRefresh(
                            const PersonalInformationScreen()),
                      ),
                      const SizedBox(height: 14),
                      _sectionTile(
                        title: 'Education',
                        subtitle: 'Schooling, degrees, qualifications',
                        icon: Icons.school_rounded,
                        color: const Color(0xFF00897B),
                        done: _educationDone,
                        onTap: () =>
                            _navigateAndRefresh(const EducationScreen()),
                      ),
                      const SizedBox(height: 14),
                      _sectionTile(
                        title: 'Formation',
                        subtitle:
                            'Candidature, novitiate, profession dates',
                        icon: Icons.auto_stories_rounded,
                        color: const Color(0xFF2E7D32),
                        done: _formationDone,
                        onTap: () =>
                            _navigateAndRefresh(const FormationScreen()),
                      ),
                      const SizedBox(height: 14),
                      _sectionTile(
                        title: 'Religious Life',
                        subtitle: 'Community, mission, apostolate',
                        icon: Icons.church_rounded,
                        color: const Color(0xFFF9A825),
                        done: _religiousLifeDone,
                        onTap: () => _navigateAndRefresh(
                            const ReligiousLifeScreen()),
                      ),
                      const SizedBox(height: 14),
                      _sectionTile(
                        title: 'Documents & Photo',
                        subtitle: 'ID numbers and profile photo',
                        icon: Icons.badge_rounded,
                        color: const Color(0xFF6A3DE8),
                        done: _documentsDone,
                        onTap: () {
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) return;
                          _navigateAndRefresh(
                              DocumentsScreen(sisterId: uid));
                        },
                      ),
                      const SizedBox(height: 24),
                      // ── Footer: View full profile ─────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            _navigateAndRefresh(
                                ViewProfileScreen(sisterId: uid));
                          },
                          icon: const Icon(Icons.visibility_rounded,
                              color: _accent),
                          label: const Text('View Full Profile',
                              style: TextStyle(
                                  color: _accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _accent, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Footer: Log out ────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _confirmLogout,
                          icon: Icon(Icons.logout_rounded,
                              color: Colors.red.shade600),
                          label: Text('Log Out',
                              style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header avatar + name (single source of truth) ──────────────────
  // Reads the same fields the Personal Information / Documents
  // screens save: fullName (top-level) and documents.photoBase64
  // (nested map) — both on the sisters/{uid} document already
  // fetched in _loadCompletionStatus, so no extra Firestore read.
  Widget _headerAvatar() {
    String photoBase64 = '';
    final docsMap = _sisterData?['documents'];
    if (docsMap is Map) {
      photoBase64 = (docsMap['photoBase64'] as String?) ?? '';
    }

    ImageProvider? imgProvider;
    if (photoBase64.isNotEmpty) {
      try {
        imgProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        imgProvider = null;
      }
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
      ),
      child: ClipOval(
        child: imgProvider != null
            ? Image(image: imgProvider, fit: BoxFit.cover)
            : const Icon(Icons.person_rounded, color: Colors.white, size: 44),
      ),
    );
  }

  String _headerName() {
    final fullName = (_sisterData?['fullName'] as String?) ?? '';
    return fullName.isNotEmpty ? fullName : 'Complete your profile';
  }

  Widget _sectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: color.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              if (done)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF43A047),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 14),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
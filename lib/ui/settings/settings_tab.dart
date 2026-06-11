import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../state/profile_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/sheet.dart';

/// Settings page — an editable, local-only profile (photo, first/last name,
/// email). Backed by [ProfileStore] over `shared_preferences`.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _picker = ImagePicker();

  String _photoPath = '';
  bool _saved = false;
  bool _initialised = false;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    // Only hydrate now if the store already loaded; otherwise build() picks it
    // up once load() completes (initState often runs before the async load).
    final store = context.read<ProfileStore>();
    if (!store.loading) _hydrate(store.profile);
  }

  void _hydrate(Profile p) {
    _first.text = p.firstName;
    _last.text = p.lastName;
    _email.text = p.email;
    _photoPath = p.photoPath;
    _initialised = true;
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _initials {
    final a = _first.text.trim();
    final b = _last.text.trim();
    final s = (a.isNotEmpty ? a[0] : '') + (b.isNotEmpty ? b[0] : '');
    return s.isEmpty ? '?' : s.toUpperCase();
  }

  Future<void> _pickPhoto() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    // Copy the picked file into the app's documents dir; persist only its path.
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path);
    final dest = p.join(
        dir.path, 'profile_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(picked.path).copy(dest);
    if (!mounted) return;
    setState(() => _photoPath = dest);
  }

  Future<void> _save() async {
    final profile = Profile(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
      photoPath: _photoPath,
    );
    await context.read<ProfileStore>().save(profile);
    if (!mounted) return;
    setState(() => _saved = true);
    _savedTimer?.cancel();
    _savedTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hydrate once the store finishes its async load (initState may run before).
    final store = context.watch<ProfileStore>();
    if (!_initialised && !store.loading) _hydrate(store.profile);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.pad),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 130),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 18),
            child: Text('Profile',
                style: AppText.display(
                    size: 34, weight: FontWeight.w700, letterSpacing: 1)),
          ),
          _Avatar(
            photoPath: _photoPath,
            initials: _initials,
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 14),
          Center(child: _ChangePhotoButton(onTap: _pickPhoto)),
          const SizedBox(height: 26),
          const SheetLabel('First name'),
          SheetInput(
            controller: _first,
            hint: 'Jane',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const SheetLabel('Last name'),
          SheetInput(
            controller: _last,
            hint: 'Doe',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const SheetLabel('Email'),
          SheetInput(
            controller: _email,
            hint: 'jane@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: _saved ? 'Saved ✓' : 'Save profile',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoPath,
    required this.initials,
    required this.onTap,
  });

  final String photoPath;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.surface2,
                  border: Border.all(color: T.line),
                  image: photoPath.isNotEmpty
                      ? DecorationImage(
                          image: FileImage(File(photoPath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: photoPath.isNotEmpty
                    ? null
                    : Text(initials,
                        style: AppText.display(
                            size: 36, weight: FontWeight.w900, color: T.textDim)),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: T.accent,
                    border: Border.all(color: T.bg, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePhotoButton extends StatelessWidget {
  const _ChangePhotoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.surface2,
      borderRadius: BorderRadius.circular(T.rChip),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rChip),
        side: const BorderSide(color: T.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rChip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text('Change photo',
              style: AppText.ui(size: 13, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}

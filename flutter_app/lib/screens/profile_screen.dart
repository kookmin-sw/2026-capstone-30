import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = UserProfile();
  bool _isLoading = true;
  bool _isSaving = false;

  final _api = ApiService();
  final _storage = StorageService();

  int? _userId;

  static const _allergies = ['견과류', '유제품', '해산물', '밀', '계란', '대두'];
  static const _dietary = ['없음', '채식', '비건', '할랄'];
  static const _cuisines = ['한식', '중식', '양식', '일식'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await _storage.getLoginInfo();
    if (info == null) return;
    _userId = info['userId'];

    try {
      final profile = await _api.getProfile(_userId!);
      if (!mounted) return;
      setState(() { _profile = profile; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = UserProfile(
          userId: _userId,
          username: info['username'] ?? '',
          nickname: info['nickname'] ?? '',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_userId == null) return;
    setState(() => _isSaving = true);

    try {
      await _api.updateProfile(
        _userId!,
        _profile.dietTypeEnglish,
        _profile.allergyIds,
        _profile.cuisineIds,
      );
      await _storage.saveProfile(_profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.'), backgroundColor: kPrimary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.logout();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('내 프로필', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Card(
                    title: '계정 정보',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.person, color: kPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text('아이디: ${_profile.username}', style: const TextStyle(fontSize: 15)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.face, color: kPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text('닉네임: ${_profile.nickname}', style: const TextStyle(fontSize: 15)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _Card(
                    title: '알레르기',
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: _allergies.map((a) {
                        final on = _profile.allergies.contains(a);
                        return FilterChip(
                          label: Text(a),
                          selected: on,
                          onSelected: (v) => setState(() {
                            v ? _profile.allergies.add(a) : _profile.allergies.remove(a);
                          }),
                          selectedColor: kPrimary.withOpacity(0.15),
                          checkmarkColor: kPrimary,
                          labelStyle: TextStyle(color: on ? kPrimary : null),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _Card(
                    title: '식이 제한',
                    child: Column(
                      children: _dietary.map((d) => RadioListTile<String>(
                        title: Text(d),
                        value: d,
                        groupValue: _profile.dietaryRestriction,
                        onChanged: (v) => setState(() => _profile.dietaryRestriction = v!),
                        activeColor: kPrimary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _Card(
                    title: '선호 요리 종류',
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: _cuisines.map((c) {
                        final on = _profile.preferredCuisines.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: on,
                          onSelected: (v) => setState(() {
                            v ? _profile.preferredCuisines.add(c) : _profile.preferredCuisines.remove(c);
                          }),
                          selectedColor: kPrimary.withOpacity(0.15),
                          checkmarkColor: kPrimary,
                          labelStyle: TextStyle(color: on ? kPrimary : null),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('로그아웃', style: TextStyle(color: Colors.red, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

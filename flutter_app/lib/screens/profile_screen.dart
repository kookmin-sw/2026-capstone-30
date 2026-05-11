import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/login_form.dart';

class ProfileScreen extends StatefulWidget {
  final bool loggedIn;
  final VoidCallback onLoginSuccess;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.loggedIn,
    required this.onLoginSuccess,
    required this.onLogout,
  });

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

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loggedIn != widget.loggedIn) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    if (widget.loggedIn) {
      final info = await _storage.getLoginInfo();
      if (info != null) {
        _userId = info['userId'];
        try {
          final profile = await _api.getProfile(_userId!);
          await _storage.saveProfile(profile);
          if (!mounted) return;
          setState(() { _profile = profile; _isLoading = false; });
          return;
        } catch (_) {
          // DB 실패하면 로컬에서 fallback 
          if (!mounted) return;
          final local = await _storage.getProfile();
          setState(() {
            _profile = UserProfile(
              userId: _userId,
              username: info['username'] ?? '',
              nickname: info['nickname'] ?? '',
              allergies: local.allergies,
              dietaryRestriction: local.dietaryRestriction,
              preferredCuisines: local.preferredCuisines,
            );
            _isLoading = false;
          });
          return;
        }
      }
    }

    // 이거 중요, 비로그인하면 로컬 프로필만 사용
    _userId = null;
    final local = await _storage.getProfile();
    if (!mounted) return;
    setState(() { _profile = local; _isLoading = false; });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // 로컬은 항상 저장하기
      await _storage.saveProfile(_profile);

      if (widget.loggedIn && _userId != null) {
        await _api.updateProfile(
          _userId!,
          _profile.dietTypeEnglish,
          _profile.allergyIds,
          _profile.cuisineIds,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.loggedIn ? '프로필이 저장되었습니다.' : '프로필이 저장되었습니다. (로그인 시 서버에 동기화됩니다)'),
          backgroundColor: kPrimary,
        ));
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
        content: const Text('로그아웃하면 이 기기의 데이터는 초기화됩니다.\n서버에 저장된 데이터는 다시 로그인하면 복구됩니다.'),
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
    if (ok == true) widget.onLogout();
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
          if (!_isLoading)
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
                  if (widget.loggedIn)
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
                    )
                  else
                    _Card(
                      title: '로그인 / 회원가입',
                      child: LoginForm(onLoginSuccess: widget.onLoginSuccess),
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

                  if (widget.loggedIn)
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

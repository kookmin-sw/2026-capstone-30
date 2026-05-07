import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _loginIdCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();
  final _regIdCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _regPwConfirmCtrl = TextEditingController();
  final _regNicknameCtrl = TextEditingController();

  final _api = ApiService();
  final _storage = StorageService();

  bool _loading = false;
  bool _idChecked = false;
  bool _idAvailable = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _regIdCtrl.addListener(() {
      if (_idChecked) setState(() { _idChecked = false; _idAvailable = false; });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _loginIdCtrl.dispose();
    _loginPwCtrl.dispose();
    _regIdCtrl.dispose();
    _regPwCtrl.dispose();
    _regPwConfirmCtrl.dispose();
    _regNicknameCtrl.dispose();
    super.dispose();
  }

  void _msg(String text, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red[400] : kPrimary),
    );
  }

  Future<void> _checkId() async {
    final id = _regIdCtrl.text.trim();
    if (id.isEmpty) { _msg('아이디를 입력해주세요.'); return; }
    if (id.length < 4) { _msg('아이디는 4자 이상이어야 합니다.'); return; }

    setState(() => _loading = true);
    try {
      final ok = await _api.checkUsername(id);
      setState(() { _idChecked = true; _idAvailable = ok; });
      _msg(ok ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.', error: !ok);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final id = _loginIdCtrl.text.trim();
    final pw = _loginPwCtrl.text;
    if (id.isEmpty || pw.isEmpty) { _msg('아이디와 비밀번호를 입력해주세요.'); return; }

    setState(() => _loading = true);
    try {
      final user = await _api.login(id, pw);
      await _storage.saveLoginInfo(user['user_id'], user['username'], user['nickname']);
      widget.onLoginSuccess();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final id = _regIdCtrl.text.trim();
    final pw = _regPwCtrl.text;
    final pwConfirm = _regPwConfirmCtrl.text;
    final nick = _regNicknameCtrl.text.trim();

    if (id.isEmpty || pw.isEmpty || nick.isEmpty) { _msg('모든 항목을 입력해주세요.'); return; }
    if (id.length < 4) { _msg('아이디는 4자 이상이어야 합니다.'); return; }
    if (!_idChecked || !_idAvailable) { _msg('아이디 중복확인을 해주세요.'); return; }
    if (pw.length < 4) { _msg('비밀번호는 4자 이상이어야 합니다.'); return; }
    if (pw != pwConfirm) { _msg('비밀번호가 일치하지 않습니다.'); return; }

    setState(() => _loading = true);
    try {
      final userId = await _api.register(id, pw, nick);
      await _storage.saveLoginInfo(userId, id, nick);
      widget.onLoginSuccess();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.kitchen, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              Text('냉집사',
                style: GoogleFonts.jua(fontSize: 32, color: kPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('AI 냉장고 관리 & 레시피 추천',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabCtrl,
                      labelColor: kPrimary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: kPrimary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: const [Tab(text: '로그인'), Tab(text: '회원가입')],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: [_buildLogin(), _buildRegister()][_tabCtrl.index],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _field(_loginIdCtrl, '아이디', Icons.person_outline),
        const SizedBox(height: 16),
        _field(_loginPwCtrl, '비밀번호', Icons.lock_outline, obscure: true, onSubmit: _login),
        const SizedBox(height: 24),
        _actionBtn('로그인', _login),
      ]),
    );
  }

  Widget _buildRegister() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          Expanded(child: _field(_regIdCtrl, '아이디', Icons.person_outline,
            suffix: _idChecked
                ? Icon(_idAvailable ? Icons.check_circle : Icons.cancel,
                    color: _idAvailable ? kPrimary : Colors.red)
                : null,
          )),
          const SizedBox(width: 8),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _loading ? null : _checkId,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('중복확인', style: TextStyle(color: kPrimary)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _field(_regPwCtrl, '비밀번호', Icons.lock_outline, obscure: true),
        const SizedBox(height: 12),
        _field(_regPwConfirmCtrl, '비밀번호 확인', Icons.lock_outline, obscure: true),
        const SizedBox(height: 12),
        _field(_regNicknameCtrl, '닉네임', Icons.face),
        const SizedBox(height: 20),
        _actionBtn('회원가입', _register),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, VoidCallback? onSubmit, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
    );
  }

  Widget _actionBtn(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: FilledButton(
        onPressed: _loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

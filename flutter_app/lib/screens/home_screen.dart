import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/chatbot_sheet.dart';
import 'recipe_detail_screen.dart';

// 서버 server.js의 분류 사전과 같이 유지
const Map<String, String> _exactCategory = {
  '깨': '양념', '꿀': '양념', '잼': '양념', '소금': '양념', '설탕': '양념',
  '김': '해산물', '게': '해산물', '굴': '해산물',
  '무': '채소', '파': '채소', '콩': '채소',
  '김치': '채소', '배추김치': '채소', '깍두기': '채소', '총각김치': '채소',
  '단무지': '채소', '장아찌': '채소', '오이지': '채소', '나박김치': '채소', '열무김치': '채소',
  '배': '과일', '감': '과일', '귤': '과일',
};

const Map<String, List<String>> _categoryKeywords = {
  '양념': ['후추', '고춧가루', '간장', '된장', '고추장', '쌈장', '참기름', '들기름', '식초', '식용유', '올리브유', '카놀라유', '미림', '맛술', '마요네즈', '케첩', '케찹', '머스타드', '굴소스', '액젓', '멸치액젓', '까나리', '다시다', '미원', '연두', '드레싱', '향신료', '계피', '바질', '오레가노', '월계수', '카레', '밀가루', '전분', '시럽', '마가린', '참깨', '들깨'],
  '고기': ['소고기', '쇠고기', '돼지고기', '삼겹살', '목살', '항정살', '갈비', '등심', '안심', '닭고기', '닭가슴살', '닭다리', '닭날개', '오리고기', '양고기', '베이컨', '소시지', '핫도그', '스팸', '다짐육', '간고기', '불고기', '제육', '족발', '곱창', '대창', '막창', '치킨', '계란', '달걀', '햄'],
  '채소': ['양파', '대파', '쪽파', '실파', '마늘', '생강', '당근', '감자', '고구마', '배추', '양배추', '상추', '깻잎', '시금치', '부추', '미나리', '쑥갓', '청경채', '브로콜리', '콜리플라워', '파프리카', '피망', '청양고추', '고추', '오이', '토마토', '방울토마토', '가지', '호박', '애호박', '단호박', '버섯', '표고', '느타리', '팽이', '양송이', '새송이', '콩나물', '숙주', '연근', '우엉', '도라지', '더덕', '아스파라거스', '셀러리', '비트', '래디시', '옥수수', '완두콩', '두부', '유부'],
  '해산물': ['고등어', '갈치', '꽁치', '삼치', '명태', '동태', '황태', '코다리', '북어', '연어', '참치', '광어', '우럭', '도미', '조기', '굴비', '멸치', '새우', '대하', '오징어', '낙지', '주꾸미', '문어', '꼴뚜기', '조개', '바지락', '홍합', '전복', '소라', '꽃게', '대게', '랍스터', '미역', '다시마', '톳', '매생이', '파래', '명란', '알탕', '어묵', '게맛살', '맛살', '생선'],
  '유제품': ['우유', '치즈', '요거트', '요구르트', '생크림', '버터', '연유', '두유', '슬라이스치즈', '체다', '모짜렐라', '모차렐라', '리코타', '크림치즈', '코티지', '플레인요거트'],
  '과일': ['사과', '바나나', '딸기', '포도', '청포도', '오렌지', '레몬', '라임', '키위', '망고', '파인애플', '복숭아', '천도복숭아', '자두', '체리', '수박', '참외', '멜론', '블루베리', '라즈베리', '크랜베리', '아보카도', '단감', '홍시', '석류', '한라봉', '천혜향', '용과', '리치', '망고스틴', '두리안', '무화과', '거봉'],
};

String classifyIngredient(String name) {
  final n = name.trim();
  if (n.isEmpty) return '기타';
  if (_exactCategory.containsKey(n)) return _exactCategory[n]!;
  for (final entry in _categoryKeywords.entries) {
    if (entry.value.any((kw) => n.contains(kw))) return entry.key;
  }
  return '기타';
}

const List<String> _categoryOrder = ['양념', '고기', '채소', '해산물', '유제품', '과일', '기타'];
const Map<String, IconData> _categoryIcons = {
  '양념': Icons.local_dining,
  '고기': Icons.set_meal,
  '채소': Icons.eco,
  '해산물': Icons.water,
  '유제품': Icons.icecream,
  '과일': Icons.local_florist,
  '기타': Icons.category,
};

// 카테고리별 보관 기한(일). 양념/기타는 추적 안 함.
const Map<String, int> _shelfLifeDays = {
  '고기': 3,
  '해산물': 2,
  '유제품': 7,
  '채소': 5,
  '과일': 5,
};

int _daysSince(DateTime created) {
  final now = DateTime.now();
  final c = DateTime(created.year, created.month, created.day);
  final t = DateTime(now.year, now.month, now.day);
  return t.difference(c).inDays;
}

// 만료 1일 전부터 '오래된' 으로 판정
bool _isStale(Map<String, dynamic> item) {
  final days = _shelfLifeDays[item['category'] as String? ?? ''];
  if (days == null) return false;
  final raw = item['created_at'] as String?;
  if (raw == null) return false;
  final created = DateTime.tryParse(raw)?.toLocal();
  if (created == null) return false;
  return _daysSince(created) >= days - 1;
}

class HomeScreen extends StatefulWidget {
  final bool loggedIn;
  final void Function(List<String> ingredients, String recipeName)? onAddToShopping;
  const HomeScreen({super.key, required this.loggedIn, this.onAddToShopping});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<File> _images = [];
  // ingredient_id로 판단하기, null이면 로컬(비로그인), 값 있으면 DB(로그인)
  List<Map<String, dynamic>> _ingredients = [];
  List<Recipe> _recipes = [];
  List<String> _prevRecipes = [];
  bool _isAnalyzing = false;
  bool _isLoadingRecipes = false;

  final _api = ApiService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  int? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loggedIn != widget.loggedIn) _init();
  }

  Future<void> reloadFromServer() => _init();

  Future<void> _init() async {
    if (widget.loggedIn) {
      final info = await _storage.getLoginInfo();
      if (info != null) {
        _userId = info['userId'];
        await _loadFromServer();
        return;
      }
    }
    _userId = null;
    await _loadFromLocal();
  }

  Future<void> _loadFromServer() async {
    if (_userId == null) return;
    try {
      final list = await _api.getIngredients(_userId!);
      if (mounted) setState(() => _ingredients = list);
    } catch (_) {
      await _loadFromLocal();
    }
  }

  Future<void> _loadFromLocal() async {
    final items = await _storage.getIngredients();
    if (mounted) {
      setState(() => _ingredients = items
          .map((e) => <String, dynamic>{
                'ingredient_id': null,
                'name': e['name'],
                'category': e['category'] ?? '기타',
                'created_at': e['created_at'],
              })
          .toList());
    }
  }

  Future<void> _persistLocal() => _storage.saveIngredients(
        _ingredients
            .map((e) => <String, dynamic>{
                  'name': e['name'],
                  'category': e['category'] ?? '기타',
                  'created_at': e['created_at'],
                })
            .toList(),
      );

  List<String> get _names => _ingredients.map((e) => e['name'] as String).toList();

  String get _catMessage {
    if (_isAnalyzing) return '재료를 열심히 분석하고 있어요! 잠깐만요';
    if (_isLoadingRecipes) return '어떤 레시피가 맛있을지 생각 중이에요...';
    if (_recipes.isNotEmpty) return '맛있는 레시피를 찾았어요!\n골라서 요리해 보세요';
    if (_ingredients.isNotEmpty) return '재료 확인 완료!\n버튼을 눌러 레시피를 추천받아 보세요';
    if (_images.isNotEmpty) return '사진 업로드 완료!\n재료를 분석했어요';
    return '냉장고 사진을 찍어 주세요!\n제가 레시피를 추천해 드릴게요';
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: kAccentLight,
                child: Icon(Icons.camera_alt, color: kPrimary),
              ),
              title: const Text('카메라로 촬영'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: kAccentLight,
                child: Icon(Icons.photo_library, color: kPrimary),
              ),
              title: const Text('갤러리에서 선택'),
              onTap: () { Navigator.pop(context); _pickMultipleImages(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (xFile == null) return;

    final newImage = File(xFile.path);
    setState(() {
      _images.add(newImage);
      _recipes = [];
      _isAnalyzing = true;
    });

    try {
      final result = await _api.analyzeImage(newImage);
      if (result.isNotEmpty) {
        final items = result
            .map((n) => <String, dynamic>{'name': n, 'category': classifyIngredient(n)})
            .toList();
        if (widget.loggedIn && _userId != null) {
          await _api.saveIngredients(_userId!, items);
          await _loadFromServer();
        } else {
          final existing = _names.toSet();
          final now = DateTime.now().toIso8601String();
          for (final item in items) {
            if (existing.add(item['name'] as String)) {
              _ingredients.add({
                'ingredient_id': null,
                'name': item['name'],
                'category': item['category'],
                'created_at': now,
              });
            }
          }
          await _persistLocal();
        }
      }
      setState(() => _isAnalyzing = false);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickMultipleImages() async {
    final xFiles = await _picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (xFiles.isEmpty) return;

    final newImages = xFiles.map((x) => File(x.path)).toList();
    setState(() {
      _images.addAll(newImages);
      _recipes = [];
      _isAnalyzing = true;
    });

    try {
      for (final img in newImages) {
        final result = await _api.analyzeImage(img);
        if (result.isNotEmpty) {
          final items = result
              .map((n) => <String, dynamic>{'name': n, 'category': classifyIngredient(n)})
              .toList();
          if (widget.loggedIn && _userId != null) {
            await _api.saveIngredients(_userId!, items);
          } else {
            final existing = _names.toSet();
            final now = DateTime.now().toIso8601String();
            for (final item in items) {
              if (existing.add(item['name'] as String)) {
                _ingredients.add({
                  'ingredient_id': null,
                  'name': item['name'],
                  'category': item['category'],
                  'created_at': now,
                });
              }
            }
          }
        }
      }
      if (widget.loggedIn && _userId != null) {
        await _loadFromServer();
      } else {
        await _persistLocal();
      }
      setState(() => _isAnalyzing = false);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _getRecipes() async {
    if (_ingredients.isEmpty) {
      _showError('재료를 먼저 추가해 주세요.');
      return;
    }
    setState(() => _isLoadingRecipes = true);
    try {
      final profile = await _storage.getProfile();
      final recipes = await _api.getRecipes(_names, _prevRecipes, profile);
      setState(() {
        _recipes = recipes;
        _prevRecipes = [..._prevRecipes, ...recipes.map((r) => r.name)].take(10).toList();
        _isLoadingRecipes = false;
      });
    } catch (e) {
      setState(() => _isLoadingRecipes = false);
      _showError('레시피 추천 실패: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _removeIngredient(Map<String, dynamic> item) async {
    final id = item['ingredient_id'];
    if (widget.loggedIn && id != null) {
      try { await _api.deleteIngredient(id); } catch (_) {}
    }
    setState(() => _ingredients.remove(item));
    if (!widget.loggedIn) await _persistLocal();
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('재료 추가'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '재료 이름'),
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final t = ctrl.text.trim();
              if (t.isNotEmpty && !_names.contains(t)) {
                final cat = classifyIngredient(t);
                if (widget.loggedIn && _userId != null) {
                  try {
                    await _api.saveIngredients(_userId!, [
                      {'name': t, 'category': cat}
                    ]);
                    await _loadFromServer();
                  } catch (_) {}
                } else {
                  setState(() => _ingredients.add({
                        'ingredient_id': null,
                        'name': t,
                        'category': cat,
                        'created_at': DateTime.now().toIso8601String(),
                      }));
                  await _persistLocal();
                }
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staleNames = _ingredients.where(_isStale).map((e) => e['name'] as String).toList();

    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 104, bottom: 14),
              title: Text(
                '냉집사',
                style: GoogleFonts.jua(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A4A35), Color(0xFF2A7D52)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 104,
                      bottom: 50,
                      child: Text(
                        '냉장고 사진으로 레시피를 찾아보세요',
                        style: GoogleFonts.jua(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ImageUploadCard(
                  images: _images,
                  isAnalyzing: _isAnalyzing,
                  onTap: _showSourceSheet,
                  onRemove: _removeImage,
                ),
                const SizedBox(height: 12),
                _CatBubble(message: _catMessage),
                const SizedBox(height: 12),

                if (staleNames.isNotEmpty) ...[
                  _StaleBanner(names: staleNames),
                  const SizedBox(height: 12),
                ],

                _IngredientsCard(
                  ingredients: _ingredients,
                  isAnalyzing: _isAnalyzing,
                  onRemove: _removeIngredient,
                  onAdd: _showAddDialog,
                ),

                if (_ingredients.isNotEmpty && !_isAnalyzing) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      onPressed: _isLoadingRecipes ? null : _getRecipes,
                      icon: _isLoadingRecipes
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.restaurant_menu),
                      label: Text(_isLoadingRecipes ? '추천 중...' : '레시피 추천받기'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                if (_recipes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('추천 레시피', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._recipes.map((r) => _RecipeCard(
                        recipe: r,
                        onAddToShopping: widget.onAddToShopping,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                              recipeName: r.name,
                              ingredients: _names,
                              missingIngredients: r.additional,
                              userId: _userId,
                              onAddToShopping: widget.onAddToShopping,
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingRecipes ? null : _getRecipes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다른 레시피 추천받기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showChatbotSheet(context, userId: _userId),
        backgroundColor: kPrimary,
        icon: const Icon(Icons.chat_rounded, color: Colors.white),
        label: const Text('AI 집사', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _CatBubble extends StatelessWidget {
  final String message;
  const _CatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ),
        const SizedBox(width: 8),
        ClipOval(
          child: Image.asset('assets/cat3.png', width: 80, height: 80, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  final List<String> names;
  const _StaleBanner({required this.names});

  String get _text {
    if (names.length <= 3) return '오래된 재료가 있어요! ${names.join(', ')}';
    return '오래된 재료가 있어요! ${names.take(2).join(', ')} 등 ${names.length}개';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE89B2A).withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.schedule, color: Color(0xFFE89B2A), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_text, style: const TextStyle(fontSize: 13.5, color: Color(0xFF8C5A10), height: 1.4)),
        ),
      ]),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final List<File> images;
  final bool isAnalyzing;
  final VoidCallback onTap;
  final void Function(int index) onRemove;

  const _ImageUploadCard({
    required this.images, required this.isAnalyzing,
    required this.onTap, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimary.withOpacity(0.3), width: 2, strokeAlign: BorderSide.strokeAlignInside),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 64, color: kPrimary.withOpacity(0.7)),
              const SizedBox(height: 12),
              const Text('냉장고 사진을 업로드하세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('카메라 촬영 또는 갤러리 선택', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: images.length + 1,
              itemBuilder: (context, index) {
                if (index == images.length) {
                  return GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: kAccentLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimary.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, color: kPrimary, size: 32),
                          SizedBox(height: 6),
                          Text('사진 추가', style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(right: 8, left: index == 0 ? 0 : 0),
                  child: SizedBox(
                    width: 160,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(images[index], fit: BoxFit.cover, width: 160, height: double.infinity),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => onRemove(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (isAnalyzing)
              Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('AI가 재료를 분석 중...', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  final List<Map<String, dynamic>> ingredients;
  final bool isAnalyzing;
  final void Function(Map<String, dynamic>) onRemove;
  final VoidCallback onAdd;

  const _IngredientsCard({
    required this.ingredients, required this.isAnalyzing,
    required this.onRemove, required this.onAdd,
  });

  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in ingredients) {
      final cat = (item['category'] as String?) ?? '기타';
      final key = _categoryOrder.contains(cat) ? cat : '기타';
      map.putIfAbsent(key, () => []).add(item);
    }
    // 각 카테고리 안에서 등록일 오름차순(먼저 들어간 게 위). null은 맨 뒤.
    for (final list in map.values) {
      list.sort((a, b) {
        final aRaw = a['created_at'] as String?;
        final bRaw = b['created_at'] as String?;
        if (aRaw == null && bRaw == null) return 0;
        if (aRaw == null) return 1;
        if (bRaw == null) return -1;
        return aRaw.compareTo(bRaw);
      });
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final isEmpty = ingredients.isEmpty && !isAnalyzing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.kitchen, color: kPrimary),
            const SizedBox(width: 8),
            Text(
              isEmpty ? '나의 냉장고' : '나의 냉장고 (${ingredients.length}개)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, color: kPrimary),
              tooltip: '재료 추가',
            ),
          ]),
          const SizedBox(height: 8),
          if (isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (isEmpty)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.kitchen_outlined, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      '냉장고가 비어 있어요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '사진을 찍거나 직접 재료를 추가해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cat in _categoryOrder)
                  if ((grouped[cat] ?? const []).isNotEmpty)
                    _CategorySection(
                      category: cat,
                      items: grouped[cat]!,
                      onRemove: onRemove,
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onRemove;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcons[category] ?? Icons.category, size: 16, color: kPrimary),
              const SizedBox(width: 6),
              Text(
                '$category (${items.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Chip(
              label: Text(item['name'] as String),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => onRemove(item),
              backgroundColor: kAccentLight,
              deleteIconColor: kPrimary,
              labelStyle: const TextStyle(color: kPrimary),
              side: const BorderSide(color: kPrimary, width: 0.5),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final void Function(List<String>, String)? onAddToShopping;
  const _RecipeCard({required this.recipe, required this.onTap, this.onAddToShopping});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(recipe.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Badge(icon: Icons.timer_outlined, text: recipe.time),
                const SizedBox(width: 8),
                _Badge(icon: Icons.bar_chart, text: recipe.difficulty),
              ]),
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(recipe.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (recipe.available.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 4, runSpacing: 4,
                  children: recipe.available.take(6).map((i) => _Tag(text: i, have: true)).toList()),
              ],
              if (recipe.additional.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4,
                  children: recipe.additional.take(3).map((i) => _Tag(text: '+$i', have: false)).toList()),
                if (onAddToShopping != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onAddToShopping!(recipe.additional, recipe.name);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${recipe.additional.length}개 재료가 쇼핑 목록에 추가되었습니다.'),
                          backgroundColor: kPrimary,
                        ));
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('쇼핑 목록에 추가', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey[600]),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final bool have;
  const _Tag({required this.text, required this.have});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: have ? kAccentLight : const Color(0xFFE8F0FE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(
      fontSize: 11,
      color: have ? const Color(0xFF2A7D52) : const Color(0xFF1A56A0),
    )),
  );
}

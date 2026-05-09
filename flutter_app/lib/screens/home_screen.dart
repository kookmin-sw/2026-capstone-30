import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'recipe_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool loggedIn;
  const HomeScreen({super.key, required this.loggedIn});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  File? _image;
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
    final names = await _storage.getIngredients();
    if (mounted) {
      setState(() => _ingredients = names
          .map((n) => <String, dynamic>{'ingredient_id': null, 'name': n})
          .toList());
    }
  }

  Future<void> _persistLocal() => _storage.saveIngredients(_names);

  List<String> get _names => _ingredients.map((e) => e['name'] as String).toList();

  String get _catMessage {
    if (_isAnalyzing) return '재료를 열심히 분석하고 있어요! 잠깐만요';
    if (_isLoadingRecipes) return '어떤 레시피가 맛있을지 생각 중이에요...';
    if (_recipes.isNotEmpty) return '맛있는 레시피를 찾았어요!\n골라서 요리해 보세요';
    if (_ingredients.isNotEmpty) return '재료 확인 완료!\n버튼을 눌러 레시피를 추천받아보세요';
    if (_image != null) return '사진 업로드 완료!\n재료를 분석했어요';
    return '냉장고 사진을 찍어주세요!\n제가 레시피를 추천해드릴게요';
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
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
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

    setState(() {
      _image = File(xFile.path);
      _recipes = [];
      _isAnalyzing = true;
    });

    try {
      final result = await _api.analyzeImage(_image!);
      if (result.isNotEmpty) {
        if (widget.loggedIn && _userId != null) {
          await _api.saveIngredients(_userId!, result);
          await _loadFromServer();
        } else {
          // 비로그인: 메모리 + 로컬에 누적 (중복 제거)
          final existing = _names.toSet();
          for (final n in result) {
            if (existing.add(n)) _ingredients.add({'ingredient_id': null, 'name': n});
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

  Future<void> _getRecipes() async {
    if (_ingredients.isEmpty) {
      _showError('재료를 먼저 추가해주세요.');
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
                if (widget.loggedIn && _userId != null) {
                  try {
                    await _api.saveIngredients(_userId!, [t]);
                    await _loadFromServer();
                  } catch (_) {}
                } else {
                  setState(() => _ingredients.add({'ingredient_id': null, 'name': t}));
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
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
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
                child: Align(
                  alignment: const Alignment(0, 0.3),
                  child: Text(
                    '냉장고 사진으로 레시피를 찾아보세요',
                    style: GoogleFonts.jua(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ImageUploadCard(
                  image: _image,
                  isAnalyzing: _isAnalyzing,
                  onTap: _showSourceSheet,
                ),
                const SizedBox(height: 12),
                _CatBubble(message: _catMessage),
                const SizedBox(height: 12),

                if (_ingredients.isNotEmpty || _isAnalyzing)
                  _IngredientsCard(
                    ingredients: _names,
                    isAnalyzing: _isAnalyzing,
                    onRemove: (name) {
                      final item = _ingredients.firstWhere(
                        (e) => e['name'] == name, orElse: () => {},
                      );
                      if (item.isNotEmpty) _removeIngredient(item);
                    },
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                              recipeName: r.name,
                              ingredients: _names,
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
        const Text('🐱', style: TextStyle(fontSize: 36)),
      ],
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final File? image;
  final bool isAnalyzing;
  final VoidCallback onTap;

  const _ImageUploadCard({
    required this.image, required this.isAnalyzing, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: image == null ? Border.all(color: kPrimary.withOpacity(0.3), width: 2, strokeAlign: BorderSide.strokeAlignInside) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image!, fit: BoxFit.cover),
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
                    Positioned(
                      right: 10, bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('재촬영', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
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
}

class _IngredientsCard extends StatelessWidget {
  final List<String> ingredients;
  final bool isAnalyzing;
  final void Function(String) onRemove;
  final VoidCallback onAdd;

  const _IngredientsCard({
    required this.ingredients, required this.isAnalyzing,
    required this.onRemove, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
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
            Text('발견된 재료 (${ingredients.length}개)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, color: kPrimary),
              tooltip: '재료 추가',
            ),
          ]),
          const SizedBox(height: 8),
          if (isAnalyzing)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ))
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ingredients.map((item) => Chip(
                label: Text(item),
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
  const _RecipeCard({required this.recipe, required this.onTap});

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

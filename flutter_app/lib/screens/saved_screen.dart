import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/storage_service.dart';
import 'saved_recipe_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  final void Function(List<String> ingredients, String recipeName)? onAddToShopping;
  const SavedScreen({super.key, this.onAddToShopping});

  @override
  State<SavedScreen> createState() => SavedScreenState();
}

class SavedScreenState extends State<SavedScreen> {
  List<RecipeDetail> _all = [];
  List<RecipeDetail> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _storage.getSavedRecipes();
    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
      _isLoading = false;
    });
  }

  void reload() => _load();

  void _onSearch(String q) {
    // 한글 조합이 끝난 다음 프레임에 검색 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _searchCtrl.text;
      setState(() => _filtered = _all.where((r) => r.name.toLowerCase().contains(current.toLowerCase())).toList());
    });
  }

  Future<void> _delete(String name) async {
    await _storage.deleteRecipe(name);
    await _load();
  }

  void _confirmDelete(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('레시피 삭제'),
        content: Text('$name\n레시피를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () { Navigator.pop(context); _delete(name); },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('저장된 레시피', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: '레시피 검색...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? _EmptyState(hasSearch: _searchCtrl.text.isNotEmpty)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final r = _filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.restaurant, color: kPrimary),
                          ),
                          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '재료 ${r.ingredients.length}가지 · 조리 ${r.steps.length}단계',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(r.name),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SavedRecipeDetailScreen(
                              recipe: r,
                              onAddToShopping: widget.onAddToShopping,
                            )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              hasSearch ? '검색 결과가 없습니다.' : '저장된 레시피가 없습니다.',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 8),
              Text('홈에서 레시피를 저장해 보세요!',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ],
        ),
      );
}

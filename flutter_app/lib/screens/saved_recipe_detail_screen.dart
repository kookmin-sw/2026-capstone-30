import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/cooking_guide_sheet.dart';
import '../widgets/recipe_rating_sheet.dart';

class SavedRecipeDetailScreen extends StatefulWidget {
  final RecipeDetail recipe;
  final void Function(List<String> ingredients, String recipeName)? onAddToShopping;

  const SavedRecipeDetailScreen({
    super.key,
    required this.recipe,
    this.onAddToShopping,
  });

  @override
  State<SavedRecipeDetailScreen> createState() => _SavedRecipeDetailScreenState();
}

class _SavedRecipeDetailScreenState extends State<SavedRecipeDetailScreen> {
  List<YoutubeLink> _resolvedLinks = [];
  bool _isLoadingVideos = false;
  bool _isLoadingGuide = false;

  List<String> _missingIngredients = [];
  final Map<String, Map<String, dynamic>> _substitutes = {};

  final _api = ApiService();
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    if (widget.recipe.youtubeLinks.isNotEmpty) _resolveVideoIds();
    _loadMissingIngredients();
  }

  Future<void> _resolveVideoIds() async {
    setState(() => _isLoadingVideos = true);
    final yt = YoutubeExplode();
    final resolved = <YoutubeLink>[];
    for (final link in widget.recipe.youtubeLinks) {
      try {
        if (link.videoId != null) {
          resolved.add(link);
        } else {
          final results = await yt.search.search(link.title);
          final video = results.firstOrNull;
          resolved.add(video != null ? link.withVideoId(video.id.value) : link);
        }
      } catch (_) {
        resolved.add(link);
      }
    }
    yt.close();
    if (mounted) setState(() { _resolvedLinks = resolved; _isLoadingVideos = false; });
  }

  Future<void> _loadMissingIngredients() async {
    try {
      final stored = await _storage.getIngredients();
      final fridgeNames = stored.map((e) => (e['name'] as String).trim().toLowerCase()).toSet();
      final missing = widget.recipe.ingredients.where((ing) {
        final clean = ing.replaceAll(RegExp(r'\(.*?\)'), '').trim().toLowerCase();
        return !fridgeNames.any((f) => clean.contains(f) || f.contains(clean));
      }).toList();
      if (mounted) setState(() => _missingIngredients = missing);

      if (missing.isNotEmpty) {
        final loginInfo = await _storage.getLoginInfo();
        final userId = loginInfo?['userId'] as int?;
        if (userId != null) _loadSubstitutes(userId, missing);
      }
    } catch (_) {}
  }

  Future<void> _loadSubstitutes(int userId, List<String> missing) async {
    await Future.wait(missing.map((ing) async {
      try {
        final result = await _api.getSubstitute(userId, ing, widget.recipe.name);
        if ((result['substitute'] as String?) != null && mounted) {
          setState(() => _substitutes[ing] = result);
        }
      } catch (_) {}
    }));
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('레시피 삭제'),
        content: Text('${widget.recipe.name}\n레시피를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService().deleteRecipe(widget.recipe.name);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openShoppingLink(String ingredient) async {
    final uri = Uri.parse(
      'https://search.shopping.naver.com/search/all?query=${Uri.encodeComponent(ingredient)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쇼핑 링크를 열 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _startCooking() async {
    setState(() => _isLoadingGuide = true);
    try {
      final rawSteps = await _api.getRecipeSteps(
        widget.recipe.name,
        widget.recipe.ingredients,
      );
      final steps = rawSteps.map((s) => CookingStep.fromJson(s)).toList();
      if (!mounted) return;
      final completed = await showCookingGuideSheet(
        context,
        steps: steps,
        recipeName: widget.recipe.name,
      );
      if (completed && mounted) {
        await showRecipeRatingSheet(context, recipeName: widget.recipe.name);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요리 가이드를 불러오지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGuide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final showYoutube = _isLoadingVideos || _resolvedLinks.isNotEmpty || r.youtubeLinks.isNotEmpty;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showYoutube) ...[
              _YoutubePlayerSection(
                links: _resolvedLinks.isNotEmpty ? _resolvedLinks : r.youtubeLinks,
                isLoading: _isLoadingVideos,
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
              icon: Icons.shopping_basket_outlined,
              title: '재료',
              child: Column(
                children: r.ingredients.map((i) => _BulletItem(text: i)).toList(),
              ),
            ),
            if (_missingIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              _MissingIngredientsCard(
                recipeName: r.name,
                missing: _missingIngredients,
                substitutes: _substitutes,
                onShoppingLink: _openShoppingLink,
                onAddToShopping: widget.onAddToShopping,
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.format_list_numbered,
              title: '조리 방법',
              child: Column(
                children: r.steps.asMap().entries.map((e) => _StepItem(number: e.key + 1, text: e.value)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoadingGuide ? null : _startCooking,
                icon: _isLoadingGuide
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_isLoadingGuide ? '가이드 준비 중...' : '요리 시작하기'),
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (r.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2FAF6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.lightbulb_outline, color: kPrimary),
                      SizedBox(width: 8),
                      Text('요리 팁', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    Text(r.tips, style: const TextStyle(height: 1.6)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── 부족한 재료 카드 ───────────────────────────────────────────
class _MissingIngredientsCard extends StatelessWidget {
  final String recipeName;
  final List<String> missing;
  final Map<String, Map<String, dynamic>> substitutes;
  final void Function(String) onShoppingLink;
  final void Function(List<String>, String)? onAddToShopping;

  const _MissingIngredientsCard({
    required this.recipeName,
    required this.missing,
    required this.substitutes,
    required this.onShoppingLink,
    this.onAddToShopping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8231A).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8231A).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.remove_shopping_cart_outlined, color: Color(0xFFE8231A), size: 20),
                SizedBox(width: 8),
                Text(
                  '부족한 재료',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFE8231A)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: missing.map((ing) {
                final sub = substitutes[ing];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 6, color: Color(0xFFE8231A)),
                  title: Text(ing, style: const TextStyle(fontSize: 15)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub != null) ...[
                        OutlinedButton(
                          onPressed: () => _showSubstituteDialog(context, ing, sub),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('대체'),
                        ),
                        const SizedBox(width: 6),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => onShoppingLink(ing),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                        label: const Text('구매', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (onAddToShopping != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAddToShopping!(missing, recipeName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${missing.length}개 재료가 쇼핑 목록에 추가되었습니다.'),
                        backgroundColor: kPrimary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('쇼핑 목록에 전체 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showSubstituteDialog(BuildContext context, String original, Map<String, dynamic> sub) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: kPrimary),
          SizedBox(width: 8),
          Text('대체 재료 추천', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8231A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(original, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kAccentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sub['substitute'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sub['reason'] as String? ?? '',
            style: const TextStyle(height: 1.55, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

// ── 유튜브 인앱 플레이어 ─────────────────────────────────────
class _YoutubePlayerSection extends StatefulWidget {
  final List<YoutubeLink> links;
  final bool isLoading;
  const _YoutubePlayerSection({required this.links, required this.isLoading});

  @override
  State<_YoutubePlayerSection> createState() => _YoutubePlayerSectionState();
}

class _YoutubePlayerSectionState extends State<_YoutubePlayerSection> {
  YoutubePlayerController? _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(_YoutubePlayerSection old) {
    super.didUpdateWidget(old);
    if (old.links != widget.links) {
      _controller?.dispose();
      _controller = null;
      _selectedIndex = 0;
      _initController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initController() {
    final id = _firstValidId();
    if (id != null) {
      setState(() {
        _controller = YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );
      });
    }
  }

  String? _firstValidId() {
    for (final link in widget.links) {
      if (link.videoId != null) return link.videoId;
    }
    return null;
  }

  Future<void> _selectVideo(int index) async {
    final link = widget.links[index];
    setState(() => _selectedIndex = index);
    if (link.videoId != null && _controller != null) {
      _controller!.load(link.videoId!);
    } else if (link.videoId == null) {
      final uri = Uri.parse(link.url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유튜브를 열 수 없습니다.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
              SizedBox(width: 8),
              Text('관련 요리 영상', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (widget.isLoading)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_controller != null)
            YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: const Color(0xFFFF0000),
              ),
              builder: (context, player) => player,
            )
          else
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('영상을 불러올 수 없습니다.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          if (!widget.isLoading && widget.links.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.links.asMap().entries.map((e) {
                  final isSelected = e.key == _selectedIndex;
                  return GestureDetector(
                    onTap: () => _selectVideo(e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFEBEE) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF0000) : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF0000) : Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${e.key + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              )),
                        ),
                        Icon(Icons.play_arrow_rounded,
                            size: 18, color: isSelected ? const Color(0xFFFF0000) : Colors.grey),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: kPrimary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            child,
          ],
        ),
      );
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: kPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ]),
      );
}

class _StepItem extends StatelessWidget {
  final int number;
  final String text;
  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            child: Center(child: Text('$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: const TextStyle(height: 1.55)),
          )),
        ]),
      );
}

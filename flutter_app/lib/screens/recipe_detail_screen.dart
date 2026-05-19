import 'package:flutter/foundation.dart' show kIsWeb;
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

class RecipeDetailScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final List<String> missingIngredients;
  final int? userId;
  final void Function(List<String> ingredients, String recipeName)? onAddToShopping;
  // 큐레이션 진입 시 서버 호출 스킵용
  final RecipeDetail? presetDetail;
  final List<Map<String, dynamic>>? presetCookingSteps;

  const RecipeDetailScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    this.missingIngredients = const [],
    this.userId,
    this.onAddToShopping,
    this.presetDetail,
    this.presetCookingSteps,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeDetail? _detail;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isLoadingGuide = false;
  final Map<String, Map<String, dynamic>> _substitutes = {};
  List<YoutubeLink> _resolvedLinks = [];
  bool _isLoadingVideos = false;

  final _api = ApiService();
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _load();
    _checkSaved();
    if (widget.userId != null && widget.missingIngredients.isNotEmpty) {
      _loadSubstitutes();
    }
  }

  Future<void> _loadSubstitutes() async {
    await Future.wait(widget.missingIngredients.map((ing) async {
      try {
        final result = await _api.getSubstitute(widget.userId!, ing, widget.recipeName);
        if ((result['substitute'] as String?) != null && mounted) {
          setState(() => _substitutes[ing] = result);
        }
      } catch (_) {}
    }));
  }

  Future<void> _load() async {
    if (widget.presetDetail != null) {
      if (mounted) setState(() { _detail = widget.presetDetail; _isLoading = false; });
      _resolveVideoIds();
      return;
    }
    try {
      final d = await _api.getRecipeDetail(widget.recipeName, widget.ingredients);
      if (mounted) setState(() { _detail = d; _isLoading = false; });
      _resolveVideoIds();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로드 실패: $e')));
      }
    }
  }

  Future<void> _resolveVideoIds() async {
    if (_detail == null || _detail!.youtubeLinks.isEmpty) return;
    if (mounted) setState(() => _isLoadingVideos = true);
    final yt = YoutubeExplode();
    final resolved = <YoutubeLink>[];
    for (final link in _detail!.youtubeLinks) {
      try {
        final results = await yt.search.search(link.title);
        final video = results.firstOrNull;
        resolved.add(video != null ? link.withVideoId(video.id.value) : link);
      } catch (_) {
        resolved.add(link);
      }
    }
    yt.close();
    if (mounted) setState(() { _resolvedLinks = resolved; _isLoadingVideos = false; });
  }

  Future<void> _checkSaved() async {
    final saved = await _storage.getSavedRecipes();
    if (mounted) setState(() => _isSaved = saved.any((r) => r.name == widget.recipeName));
  }

  Future<void> _toggleSave() async {
    if (_detail == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await _storage.deleteRecipe(_detail!.name);
      } else {
        await _storage.saveRecipe(_detail!);
      }
      setState(() { _isSaved = !_isSaved; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSaved ? '레시피가 저장되었습니다.' : '저장이 취소되었습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(widget.recipeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          if (_detail != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
              onPressed: _toggleSave,
              tooltip: _isSaved ? '저장 취소' : '레시피 저장',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('레시피를 불러올 수 없습니다.'))
              : _buildBody(),
    );
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
      final rawSteps = widget.presetCookingSteps ??
          await _api.getRecipeSteps(widget.recipeName, widget.ingredients);
      final steps = rawSteps.map((s) => CookingStep.fromJson(s)).toList();
      if (!mounted) return;
      final completed = await showCookingGuideSheet(
        context,
        steps: steps,
        recipeName: widget.recipeName,
      );
      if (completed && mounted) {
        final rating = await showRecipeRatingSheet(context, recipeName: widget.recipeName);
        if (rating == 5 && _detail != null && !_isSaved && mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('만족하셨나요?'),
              content: const Text('다음에 또 만나보실 수 있도록\n레시피에 저장해드릴까요?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('괜찮아')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('좋아')),
              ],
            ),
          );
          if (ok == true && mounted) {
            await _storage.saveRecipe(_detail!);
            if (mounted) setState(() => _isSaved = true);
          }
        }
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

  Widget _buildBody() {
    final d = _detail!;
    final missing = widget.missingIngredients;
    final showYoutube = _isLoadingVideos || _resolvedLinks.isNotEmpty || d.youtubeLinks.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showYoutube) ...[
            _YoutubePlayerSection(
              links: _resolvedLinks.isNotEmpty ? _resolvedLinks : d.youtubeLinks,
              isLoading: _isLoadingVideos,
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            icon: Icons.shopping_basket_outlined,
            title: '재료',
            child: Column(
              children: d.ingredients.map((i) => _BulletItem(text: i)).toList(),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MissingIngredientsCard(
              recipeName: widget.recipeName,
              missing: missing,
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
              children: d.steps.asMap().entries.map((e) => _StepItem(number: e.key + 1, text: e.value)).toList(),
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
          if (d.tips.isNotEmpty) ...[
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
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: kPrimary),
                      SizedBox(width: 8),
                      Text('요리 팁', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(d.tips, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kPrimary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 6, color: kPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
          ],
        ),
      );
}

class _StepItem extends StatelessWidget {
  final int number;
  final String text;
  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: Center(
                child: Text('$number',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text, style: const TextStyle(height: 1.55)),
              ),
            ),
          ],
        ),
      );
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

// 유튜브 인앱 플레이어 섹션
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildWebYoutubePlayer() {
    final link = widget.links[_selectedIndex < widget.links.length ? _selectedIndex : 0];
    final videoId = link.videoId;
    final thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
        : null;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(thumbnailUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 60),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(link.title, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  void _selectVideo(int index) async {
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
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
                SizedBox(width: 8),
                Text('관련 요리 영상', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (widget.isLoading)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (kIsWeb && widget.links.isNotEmpty)
            _buildWebYoutubePlayer()
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
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
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
                  final hasId = e.value.videoId != null;
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
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.play_circle : Icons.play_circle_outline,
                            color: isSelected ? const Color(0xFFFF0000) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xFFFF0000) : Colors.black87,
                              ),
                            ),
                          ),
                          if (!hasId)
                            const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
                        ],
                      ),
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

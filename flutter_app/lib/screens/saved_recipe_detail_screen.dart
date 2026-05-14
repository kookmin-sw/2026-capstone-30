import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/storage_service.dart';

class SavedRecipeDetailScreen extends StatefulWidget {
  final RecipeDetail recipe;
  const SavedRecipeDetailScreen({super.key, required this.recipe});

  @override
  State<SavedRecipeDetailScreen> createState() => _SavedRecipeDetailScreenState();
}

class _SavedRecipeDetailScreenState extends State<SavedRecipeDetailScreen> {
  List<YoutubeLink> _resolvedLinks = [];
  bool _isLoadingVideos = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipe.youtubeLinks.isNotEmpty) _resolveVideoIds();
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
            // 유튜브 영상 (상단)
            if (showYoutube) ...[
              _YoutubePlayerSection(
                links: _resolvedLinks.isNotEmpty ? _resolvedLinks : r.youtubeLinks,
                isLoading: _isLoadingVideos,
              ),
              const SizedBox(height: 16),
            ],
            _Card(
              icon: Icons.shopping_basket_outlined,
              title: '재료',
              child: Column(
                children: r.ingredients.map((i) => _Bullet(text: i)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              icon: Icons.format_list_numbered,
              title: '조리 방법',
              child: Column(
                children: r.steps.asMap().entries.map((e) => _Step(n: e.key + 1, text: e.value)).toList(),
              ),
            ),
            if (r.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2FAF6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.4)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
          ],
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
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

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

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

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            child: Center(child: Text('$n',
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

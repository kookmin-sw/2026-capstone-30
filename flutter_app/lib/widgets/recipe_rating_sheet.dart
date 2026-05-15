import 'package:flutter/material.dart';
import '../constants.dart';

Future<void> showRecipeRatingSheet(
  BuildContext context, {
  required String recipeName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecipeRatingSheet(recipeName: recipeName),
  );
}

class RecipeRatingSheet extends StatefulWidget {
  final String recipeName;
  const RecipeRatingSheet({super.key, required this.recipeName});

  @override
  State<RecipeRatingSheet> createState() => _RecipeRatingSheetState();
}

class _RecipeRatingSheetState extends State<RecipeRatingSheet>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  int _hovered = 0;
  final _memoController = TextEditingController();
  bool _submitted = false;
  late AnimationController _checkCtrl;
  late Animation<double> _checkAnim;

  static const _labels = ['', '별로예요', '아쉬워요', '괜찮아요', '맛있어요', '최고예요!'];
  static const _emojis = ['', '😞', '😕', '🙂', '😋', '🤩'];

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점을 선택해 주세요.')),
      );
      return;
    }
    setState(() => _submitted = true);
    await _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _submitted ? _buildThanks() : _buildRatingForm(),
    );
  }

  Widget _buildThanks() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _checkAnim,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: kAccentLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: kPrimary, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '소중한 별점 감사해요!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '다음 요리도 냉집사가 도와드릴게요 😊',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingForm() {
    final active = _hovered > 0 ? _hovered : _rating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          // 제목
          Text(
            widget.recipeName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            '요리가 만족스러우셨나요?',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          // 이모지
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              active > 0 ? _emojis[active] : '⭐',
              key: ValueKey(active),
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              active > 0 ? _labels[active] : '별점을 선택해 주세요',
              key: ValueKey(active),
              style: TextStyle(
                fontSize: 14,
                color: active > 0 ? kPrimary : Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 별점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < active;
              return GestureDetector(
                onTap: () => setState(() { _rating = i + 1; _hovered = 0; }),
                onTapDown: (_) => setState(() => _hovered = i + 1),
                onTapCancel: () => setState(() => _hovered = 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: filled ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: filled ? const Color(0xFFFFC107) : Colors.grey[300],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // 메모
          TextField(
            controller: _memoController,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '한 줄 메모 남기기 (선택)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          // 제출 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _rating == 0 ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('별점 남기기'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('건너뛰기', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

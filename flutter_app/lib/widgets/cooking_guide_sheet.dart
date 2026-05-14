import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../constants.dart';

class CookingStep {
  final int step;
  final String title;
  final String description;
  final String tip;

  CookingStep({
    required this.step,
    required this.title,
    required this.description,
    required this.tip,
  });

  factory CookingStep.fromJson(Map<String, dynamic> json) => CookingStep(
        step: json['step'] as int,
        title: json['title'] as String,
        description: json['description'] as String,
        tip: (json['tip'] as String?) ?? '',
      );
}

Future<bool> showCookingGuideSheet(
  BuildContext context, {
  required List<CookingStep> steps,
  required String recipeName,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => CookingGuideSheet(steps: steps, recipeName: recipeName),
  );
  return result == true;
}

class CookingGuideSheet extends StatefulWidget {
  final List<CookingStep> steps;
  final String recipeName;

  const CookingGuideSheet({
    super.key,
    required this.steps,
    required this.recipeName,
  });

  @override
  State<CookingGuideSheet> createState() => _CookingGuideSheetState();
}

class _CookingGuideSheetState extends State<CookingGuideSheet>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  bool get _isLast => _current == widget.steps.length - 1;
  bool get _isDone => _current >= widget.steps.length;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _setupAnimation(forward: true);
    _animCtrl.forward();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    // 첫 단계 자동 읽기
    _speakCurrentStep();
  }

  Future<void> _speakCurrentStep() async {
    if (_isDone) return;
    final step = widget.steps[_current];
    await _tts.stop();
    await _tts.speak('${step.title}. ${step.description}');
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
  }

  @override
  void dispose() {
    _tts.stop();
    _animCtrl.dispose();
    super.dispose();
  }

  void _setupAnimation({required bool forward}) {
    _slideAnim = Tween<Offset>(
      begin: Offset(forward ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  void _next() {
    if (_isDone) return;
    _setupAnimation(forward: true);
    _animCtrl.reset();
    setState(() => _current++);
    _animCtrl.forward();
    _speakCurrentStep();
  }

  void _prev() {
    if (_current == 0) return;
    _setupAnimation(forward: false);
    _animCtrl.reset();
    setState(() => _current--);
    _animCtrl.forward();
    _speakCurrentStep();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          if (!_isDone) _buildProgressBar(),
          const Divider(height: 1),
          Expanded(
            child: _isDone ? _buildComplete() : _buildStepContent(),
          ),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: kAccentLight, shape: BoxShape.circle),
            child: const Icon(Icons.restaurant, color: kPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('요리 가이드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  widget.recipeName,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // TTS 재생/정지 버튼
          if (!_isDone)
            IconButton(
              onPressed: _isSpeaking ? _stopSpeaking : _speakCurrentStep,
              icon: Icon(
                _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                color: _isSpeaking ? Colors.red : kPrimary,
              ),
              tooltip: _isSpeaking ? '읽기 중지' : '다시 듣기',
            ),
          if (!_isDone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: kAccentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_current + 1} / ${widget.steps.length}',
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_current + 1) / widget.steps.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final step = widget.steps[_current];
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${step.step}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    step.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  // 읽는 중 표시
                  if (_isSpeaking) ...[
                    const SizedBox(width: 8),
                    const _SpeakingIndicator(),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: kAccentLight, shape: BoxShape.circle),
                    child: const Icon(Icons.kitchen, color: kPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text(
                        step.description,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
              if (step.tip.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          step.tip,
                          style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF5D4037)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (!_isLast)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '다음: ${widget.steps[_current + 1].title}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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

  Widget _buildComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: kAccentLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: kPrimary, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              '완성!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.recipeName} 완성을\n축하드려요! 맛있게 드세요 🍽️',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (_isDone) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('별점 남기기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (_current > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('이전'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (_current > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _next,
              icon: Icon(_isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
              label: Text(_isLast ? '완료' : '다음 단계'),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 읽는 중 애니메이션 인디케이터
class _SpeakingIndicator extends StatefulWidget {
  const _SpeakingIndicator();

  @override
  State<_SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<_SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, size: 14, color: kPrimary),
          SizedBox(width: 3),
          Text('읽는 중', style: TextStyle(fontSize: 11, color: kPrimary)),
        ],
      ),
    );
  }
}

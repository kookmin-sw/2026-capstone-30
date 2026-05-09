import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

class ShoppingItem {
  final String ingredient;
  final String recipeName;
  bool checked;

  ShoppingItem({
    required this.ingredient,
    required this.recipeName,
    this.checked = false,
  });
}

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => ShoppingScreenState();
}

class ShoppingScreenState extends State<ShoppingScreen> {
  final List<ShoppingItem> _items = [];

  void addItems(List<String> ingredients, String recipeName) {
    setState(() {
      for (final ing in ingredients) {
        final exists = _items.any(
          (e) => e.ingredient == ing && e.recipeName == recipeName,
        );
        if (!exists) {
          _items.add(ShoppingItem(ingredient: ing, recipeName: recipeName));
        }
      }
    });
  }

  void _clearItems() {
    setState(() => _items.clear());
  }

  Future<void> _openCoupang(String ingredient) async {
    final uri = Uri.parse(
      'https://www.coupang.com/np/search?q=${Uri.encodeComponent(ingredient)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쿠팡을 열 수 없습니다.')),
        );
      }
    }
  }

  Map<String, List<ShoppingItem>> get _grouped {
    final map = <String, List<ShoppingItem>>{};
    for (final item in _items) {
      map.putIfAbsent(item.recipeName, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('쇼핑 목록', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '목록 초기화',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('목록 초기화'),
                  content: const Text('쇼핑 목록을 모두 지울까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearItems();
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _items.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '쇼핑 목록이 비어있어요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '레시피를 추천받으면\n부족한 재료가 여기에 표시돼요',
            style: TextStyle(fontSize: 14, color: Colors.grey[400], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _grouped;
    final unchecked = _items.where((e) => !e.checked).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: kAccentLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: kPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                '구매 필요 재료 $unchecked개',
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        ...grouped.entries.map(
          (entry) => _RecipeGroup(
            recipeName: entry.key,
            items: entry.value,
            onCoupang: _openCoupang,
            onToggle: (item) => setState(() => item.checked = !item.checked),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _RecipeGroup extends StatelessWidget {
  final String recipeName;
  final List<ShoppingItem> items;
  final void Function(String) onCoupang;
  final void Function(ShoppingItem) onToggle;

  const _RecipeGroup({
    required this.recipeName,
    required this.items,
    required this.onCoupang,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${items.length}개',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => _IngredientTile(
              item: item,
              onCoupang: () => onCoupang(item.ingredient),
              onToggle: () => onToggle(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onCoupang;
  final VoidCallback onToggle;

  const _IngredientTile({
    required this.item,
    required this.onCoupang,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: item.checked,
        onChanged: (_) => onToggle(),
        activeColor: kPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        item.ingredient,
        style: TextStyle(
          fontSize: 15,
          decoration: item.checked ? TextDecoration.lineThrough : null,
          color: item.checked ? Colors.grey[400] : null,
        ),
      ),
      trailing: item.checked
          ? const Icon(Icons.check_circle, color: kPrimary, size: 22)
          : ElevatedButton.icon(
              onPressed: onCoupang,
              icon: const Icon(Icons.shopping_bag_outlined, size: 15),
              label: const Text('쿠팡', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8231A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}

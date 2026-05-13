import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _savedKey = 'saved_recipes';
  static const _profileKey = 'user_profile';
  static const _ingredientsKey = 'ingredients';
  static const _loginKey = 'login_info';

  Future<void> saveLoginInfo(int userId, String username, String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginKey, jsonEncode({
      'userId': userId,
      'username': username,
      'nickname': nickname,
    }));
  }

  Future<Map<String, dynamic>?> getLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_loginKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginKey);
  }

  Future<List<RecipeDetail>> getSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => RecipeDetail.fromJson(e)).toList();
  }

  Future<void> saveRecipe(RecipeDetail recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedRecipes();
    if (!list.any((r) => r.name == recipe.name)) {
      list.insert(0, recipe);
      await prefs.setString(_savedKey, jsonEncode(list.map((r) => r.toJson()).toList()));
    }
  }

  Future<void> deleteRecipe(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedRecipes();
    list.removeWhere((r) => r.name == name);
    await prefs.setString(_savedKey, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<List<Map<String, dynamic>>> getIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ingredientsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    if (decoded.isEmpty) return [];
    // 구 포맷(List<String>) 하위 호환: 문자열이면 {name, category:'기타'}로 변환
    if (decoded.first is String) {
      return decoded
          .map((e) => <String, dynamic>{'name': e as String, 'category': '기타'})
          .toList();
    }
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveIngredients(List<Map<String, dynamic>> ingredients) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ingredientsKey, jsonEncode(ingredients));
  }
}

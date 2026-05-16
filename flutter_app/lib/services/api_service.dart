import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';

class ApiService {
  static const _timeout = Duration(seconds: 60);

  static String hashPassword(String pw) =>
      sha256.convert(utf8.encode(pw)).toString();

  Future<void> checkConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$kBaseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) throw Exception('서버 응답 오류');
    } catch (_) {
      throw Exception('서버에 연결할 수 없습니다.\n서버가 실행 중인지 확인하세요.\n(URL: $kBaseUrl)');
    }
  }

  Future<List<String>> analyzeImage(File image) async {
    await checkConnection();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/api/analyze'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['ingredients'] ?? []);
    }
    throw Exception(_errorMsg(response));
  }

  Future<List<Recipe>> getRecipes(
    List<String> ingredients,
    List<String> previousRecipes,
    UserProfile profile,
  ) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ingredients': ingredients,
            'previousRecipes': previousRecipes,
            'profile': profile.toJson(),
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['recipes'] as List).map((r) => Recipe.fromJson(r)).toList();
    }
    throw Exception(_errorMsg(response));
  }

  Future<RecipeDetail> getRecipeDetail(
    String recipeName,
    List<String> ingredients,
  ) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipe-detail'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipeName': recipeName,
            'ingredients': ingredients,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return RecipeDetail.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMsg(response));
  }

  Future<bool> checkUsername(String username) async {
    final res = await http
        .get(Uri.parse('$kBaseUrl/api/check-username/$username'))
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return jsonDecode(res.body)['available'] == true;
    }
    throw Exception(_errorMsg(res));
  }

  Future<int> register(String username, String password, String nickname) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password_hash': hashPassword(password),
            'nickname': nickname,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) return jsonDecode(res.body)['user_id'];
    throw Exception(_errorMsg(res));
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password_hash': hashPassword(password),
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorMsg(res));
  }

  Future<UserProfile> getProfile(int userId) async {
    final res = await http
        .get(Uri.parse('$kBaseUrl/api/users/$userId/profile'))
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return UserProfile.fromServerJson(jsonDecode(res.body));
    }
    throw Exception(_errorMsg(res));
  }

  Future<void> updateProfile(
    int userId, String dietType, List<int> allergyIds, List<int> cuisineIds,
  ) async {
    final res = await http
        .put(
          Uri.parse('$kBaseUrl/api/users/$userId/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'diet_type': dietType,
            'allergy_ids': allergyIds,
            'cuisine_ids': cuisineIds,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw Exception(_errorMsg(res));
  }

  Future<Map<String, dynamic>> saveIngredients(
    int userId,
    List<Map<String, dynamic>> items,
  ) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/ingredients'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'ingredients': items,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(_errorMsg(res));
  }

  Future<List<Map<String, dynamic>>> getIngredients(int userId) async {
    final res = await http
        .get(Uri.parse('$kBaseUrl/api/ingredients/$userId'))
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw Exception(_errorMsg(res));
  }

  Future<void> deleteIngredient(int ingredientId) async {
    final res = await http
        .delete(Uri.parse('$kBaseUrl/api/ingredients/$ingredientId'))
        .timeout(_timeout);

    if (res.statusCode != 200) throw Exception(_errorMsg(res));
  }

  Future<void> clearIngredients(int userId) async {
    final res = await http
        .delete(Uri.parse('$kBaseUrl/api/ingredients/user/$userId'))
        .timeout(_timeout);

    if (res.statusCode != 200) throw Exception(_errorMsg(res));
  }

  Future<Map<String, dynamic>> getSubstitute(
    int userId,
    String missingIngredient,
    String recipeName, {
    String recipeContext = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipes/substitute'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'missingIngredient': missingIngredient,
            'recipeName': recipeName,
            'recipeContext': recipeContext,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body)['data']);
    }
    throw Exception(_errorMsg(res));
  }

  Future<void> saveFcmToken(int userId, String token) async {
    await http
        .post(
          Uri.parse('$kBaseUrl/api/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'token': token}),
        )
        .timeout(_timeout);
  }

  Future<void> deleteFcmToken(int userId, String token) async {
    await http
        .delete(
          Uri.parse('$kBaseUrl/api/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'token': token}),
        )
        .timeout(_timeout);
  }

  Future<List<Map<String, dynamic>>> getRecipeSteps(
    String recipeName,
    List<String> ingredients,
  ) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipe/steps'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipeName': recipeName,
            'ingredients': ingredients,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['steps'] as List).map((s) => Map<String, dynamic>.from(s)).toList();
    }
    throw Exception(_errorMsg(res));
  }

  Future<String> sendChat(
    List<Map<String, dynamic>> messages, {
    int? userId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$kBaseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': messages,
            if (userId != null) 'userId': userId,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return jsonDecode(res.body)['reply'] as String;
    }
    throw Exception(_errorMsg(res));
  }

  Future<List<CuratedTrend>> getCuratedTrends() async {
    final res = await http
        .get(Uri.parse('$kBaseUrl/api/curated-trends'))
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => CuratedTrend.fromJson(e))
          .toList();
    }
    throw Exception(_errorMsg(res));
  }

  Future<String> getChatSuggestion() async {
    try {
      final res = await http
          .get(Uri.parse('$kBaseUrl/api/chat/suggest'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body)['suggest'] as String;
      }
    } catch (_) {}
    return '오늘 뭐 먹을까? 추천받기';
  }

  String _errorMsg(http.Response res) {
    try {
      return jsonDecode(res.body)['error'] ?? '서버 오류 (${res.statusCode})';
    } catch (_) {
      return '서버 오류 (${res.statusCode})';
    }
  }
}

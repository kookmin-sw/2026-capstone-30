class UserProfile {
  int? userId;
  String username;
  String nickname;
  List<String> allergies;
  String dietaryRestriction;
  List<String> preferredCuisines;

  UserProfile({
    this.userId,
    this.username = '',
    this.nickname = '',
    List<String>? allergies,
    this.dietaryRestriction = '없음',
    List<String>? preferredCuisines,
  })  : allergies = allergies ?? [],
        preferredCuisines = preferredCuisines ?? [];

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'],
        username: json['username'] ?? '',
        nickname: json['nickname'] ?? '',
        allergies: List<String>.from(json['allergies'] ?? []),
        dietaryRestriction: json['dietaryRestriction'] ?? '없음',
        preferredCuisines: List<String>.from(json['preferredCuisines'] ?? []),
      );

  factory UserProfile.fromServerJson(Map<String, dynamic> json) {
    final aList = (json['allergies'] as List?)
            ?.map((a) => a['name'] as String)
            .toList() ??
        [];
    final cList = (json['preferred_cuisines'] as List?)
            ?.map((c) => c['name'] as String)
            .toList() ??
        [];
    return UserProfile(
      userId: json['user_id'],
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      allergies: aList,
      dietaryRestriction: _dietToKr[json['diet_type'] ?? 'normal'] ?? '없음',
      preferredCuisines: cList,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'nickname': nickname,
        'allergies': allergies,
        'dietaryRestriction': dietaryRestriction,
        'preferredCuisines': preferredCuisines,
      };

  static const _dietToKr = {
    'normal': '없음',
    'vegetarian': '채식',
    'vegan': '비건',
    'halal': '할랄',
  };

  static const _dietToEn = {
    '없음': 'normal',
    '채식': 'vegetarian',
    '비건': 'vegan',
    '할랄': 'halal',
  };

  static const allergyIdMap = {
    '견과류': 1, '유제품': 2, '해산물': 3,
    '밀': 4, '계란': 5, '대두': 6,
  };

  static const cuisineIdMap = {
    '한식': 1, '중식': 2, '양식': 3, '일식': 4,
  };

  List<int> get allergyIds =>
      allergies.map((a) => allergyIdMap[a]).whereType<int>().toList();

  List<int> get cuisineIds =>
      preferredCuisines.map((c) => cuisineIdMap[c]).whereType<int>().toList();

  String get dietTypeEnglish => _dietToEn[dietaryRestriction] ?? 'normal';
}

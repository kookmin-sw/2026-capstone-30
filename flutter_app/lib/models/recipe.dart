class Recipe {
  final String name;
  final String difficulty;
  final String time;
  final String description;
  final List<String> available;
  final List<String> additional;

  Recipe({
    required this.name,
    required this.difficulty,
    required this.time,
    required this.description,
    required this.available,
    required this.additional,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'] ?? '',
      difficulty: json['difficulty'] ?? '',
      time: json['time'] ?? '',
      description: json['description'] ?? '',
      available: List<String>.from(json['available'] ?? []),
      additional: List<String>.from(json['additional'] ?? []),
    );
  }
}

class YoutubeLink {
  final String title;
  final String url;
  final String? videoId;

  YoutubeLink({required this.title, required this.url, this.videoId});

  factory YoutubeLink.fromJson(Map<String, dynamic> json) => YoutubeLink(
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        videoId: json['videoId'],
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        if (videoId != null) 'videoId': videoId,
      };

  YoutubeLink withVideoId(String id) =>
      YoutubeLink(title: title, url: url, videoId: id);
}

class RecipeDetail {
  final String name;
  final List<String> ingredients;
  final List<String> steps;
  final String tips;
  final List<YoutubeLink> youtubeLinks;

  RecipeDetail({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.tips,
    this.youtubeLinks = const [],
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    return RecipeDetail(
      name: json['name'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      tips: json['tips'] ?? '',
      youtubeLinks: (json['youtubeLinks'] as List? ?? [])
          .map((e) => YoutubeLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ingredients': ingredients,
        'steps': steps,
        'tips': tips,
        'youtubeLinks': youtubeLinks.map((e) => e.toJson()).toList(),
      };
}

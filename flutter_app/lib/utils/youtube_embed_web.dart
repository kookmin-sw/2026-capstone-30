// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';

final _registered = <String>{};

class YoutubeEmbedWidget extends StatelessWidget {
  final String videoId;
  const YoutubeEmbedWidget({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final viewType = 'yt-embed-$videoId';
    if (!_registered.contains(viewType)) {
      _registered.add(viewType);
      ui.platformViewRegistry.registerViewFactory(viewType, (int id) {
        return html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/$videoId'
          ..setAttribute('frameborder', '0')
          ..setAttribute(
            'allow',
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
          )
          ..setAttribute('allowfullscreen', 'true')
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }
    return HtmlElementView(viewType: viewType);
  }
}

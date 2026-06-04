import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/subtitle.dart';

class ExternalSubtitleRepository {
  final Dio _dio;
  
  ExternalSubtitleRepository(this._dio);

  Future<List<SubtitleTrack>> getSubtitles(String rawId, {int? season, int? episode}) async {
    try {
      String imdbId = rawId;
      if (rawId.contains('/')) {
        imdbId = rawId.split('/').last;
      }
      
      if (!imdbId.startsWith('tt')) {
        debugPrint('Stremio addons usually require IMDb ID starting with tt. Got: $imdbId');
        return [];
      }
      
      String url;
      if (season != null && episode != null) {
        url = 'https://opensubtitles-v3.strem.io/subtitles/series/$imdbId:$season:$episode.json';
      } else {
        url = 'https://opensubtitles-v3.strem.io/subtitles/movie/$imdbId.json';
      }
      
      debugPrint('Fetching external subs from: $url');
      final response = await _dio.get(url);
      
      if (response.statusCode == 200 && response.data['subtitles'] != null) {
        final List<SubtitleTrack> tracks = [];
        final results = response.data['subtitles'] as List;
        final Map<String, int> langCounts = {};
        
        for (var i = 0; i < results.length; i++) {
          final sub = results[i];
          final rawLang = sub['lang']?.toString().toLowerCase() ?? 'unknown';
          final langName = _getLanguageName(rawLang);
          final link = sub['url'];
          
          if (link != null) {
            langCounts[langName] = (langCounts[langName] ?? 0) + 1;
            final count = langCounts[langName]!;
            
            tracks.add(SubtitleTrack(
              id: 2000 + i, // Offset to avoid ID collision
              label: count == 1 ? langName : '$langName $count',
              src: link,
            ));
          }
        }
        
        // Optionally sort so that English and Vietnamese are at the top, or just keep original order
        return tracks;
      }
    } catch (e) {
      debugPrint('Error fetching external subtitles: $e');
    }
    
    return [];
  }

  String _getLanguageName(String code) {
    const map = {
      'eng': 'English',
      'vie': 'Vietnamese',
      'spa': 'Spanish',
      'ind': 'Indonesian',
      'fre': 'French',
      'fra': 'French',
      'ger': 'German',
      'deu': 'German',
      'por': 'Portuguese',
      'rus': 'Russian',
      'ita': 'Italian',
      'chi': 'Chinese',
      'zho': 'Chinese',
      'zht': 'Chinese (Traditional)',
      'jpn': 'Japanese',
      'kor': 'Korean',
      'tha': 'Thai',
      'ara': 'Arabic',
      'hin': 'Hindi',
      'tur': 'Turkish',
      'pol': 'Polish',
      'dut': 'Dutch',
      'nld': 'Dutch',
      'swe': 'Swedish',
      'dan': 'Danish',
      'fin': 'Finnish',
      'nor': 'Norwegian',
      'ell': 'Greek',
      'gre': 'Greek',
      'heb': 'Hebrew',
      'rum': 'Romanian',
      'ron': 'Romanian',
      'cze': 'Czech',
      'ces': 'Czech',
      'hrv': 'Croatian',
      'srp': 'Serbian',
      'slv': 'Slovenian',
      'bul': 'Bulgarian',
      'hun': 'Hungarian',
      'may': 'Malay',
      'msa': 'Malay',
      'fil': 'Filipino',
    };
    
    return map[code] ?? code.toUpperCase();
  }
}


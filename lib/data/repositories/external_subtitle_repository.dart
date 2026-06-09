import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
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

      final isTv = season != null && episode != null;
      final path = isTv ? 'series/$imdbId:$season:$episode.json' : 'movie/$imdbId.json';

      // Fallback list of Stremio Subtitle Addon APIs
      final sources = [
        'https://opensubtitles-v3.strem.io/subtitles/$path',
        'https://opensubtitles.strem.io/subtitles/$path', // v2 API fallback
        if (!isTv) 'https://yifysubtitles.strem.io/subtitles/$path', // YTS (movies only)
      ];

      for (final url in sources) {
        try {
          debugPrint('Fetching external subs from: $url');
          final response = await _dio.get(
            url,
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
          
          if (response.statusCode == 200 && response.data != null) {
            dynamic data = response.data;
            if (data is String) {
               data = jsonDecode(data);
            }
            
            if (data is Map && data['subtitles'] != null) {
              final List<SubtitleTrack> tracks = [];
              final results = data['subtitles'] as List;
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
              
              if (tracks.isNotEmpty) {
                debugPrint('Found ${tracks.length} subtitles from $url');
                return tracks;
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching external subtitles from $url: $e');
          // Ignore error and try the next source
        }
      }
    } catch (e) {
      debugPrint('Error in getSubtitles: $e');
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

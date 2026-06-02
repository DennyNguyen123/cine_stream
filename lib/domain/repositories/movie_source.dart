import '../entities/movie.dart';
import '../entities/movie_detail.dart';
import '../entities/stream_info.dart';
import '../entities/filter.dart';
import '../entities/home_section.dart';

abstract class MovieSource {
  String get sourceName;
  String get sourceIcon;

  Future<List<HomeSection>> getHomeSections();
  Future<FilterConfig> getFilterConfig();
  
  Future<List<Movie>> searchMovies(String query);
  Future<List<Movie>> advancedSearch(Map<String, dynamic> filters, {int page = 1, String query = ''});
  
  Future<MovieDetail?> getMovieDetail(int id);
  Future<StreamInfo?> getStreamInfo(int movieId, int episodeId);
}

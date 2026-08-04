import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/movie.dart';
import '../../../../domain/repositories/source_manager.dart';
import '../../../../domain/entities/filter.dart';

abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {
  final FilterConfig? filterConfig;
  final Map<String, dynamic> currentFilters;
  SearchLoading({this.filterConfig, required this.currentFilters});
}

class SearchLoaded extends SearchState {
  final FilterConfig filterConfig;
  final Map<String, dynamic> currentFilters;
  final List<Movie> movies;
  final String query;
  final bool hasReachedMax;

  SearchLoaded({
    required this.filterConfig,
    required this.currentFilters,
    required this.movies,
    required this.query,
    this.hasReachedMax = false,
  });
}

class SearchError extends SearchState {
  final String message;
  final FilterConfig? filterConfig;
  final Map<String, dynamic> currentFilters;
  SearchError(this.message, {this.filterConfig, required this.currentFilters});
}

class SearchCubit extends Cubit<SearchState> {
  final SourceManager _sourceManager;
  FilterConfig? _filterConfig;
  final Map<String, dynamic> _currentFilters = {};
  String _currentQuery = '';

  int _currentPage = 1;
  List<Movie> _currentMovies = [];
  bool _isFetchingMore = false;
  bool _hasReachedMax = false;

  SearchCubit(this._sourceManager) : super(SearchInitial());

  Future<void> initSearch() async {
    emit(SearchLoading(currentFilters: _currentFilters));
    try {
      _filterConfig = await _sourceManager.activeSource.getFilterConfig();
      // Initialize default values
      for (var field in _filterConfig!.fields) {
        _currentFilters[field.key] = field.defaultValue;
      }

      _currentPage = 1;
      _currentMovies = await _sourceManager.activeSource.advancedSearch(
        _currentFilters,
        page: _currentPage,
        query: _currentQuery,
      );
      _hasReachedMax = _currentMovies.isEmpty;

      emit(
        SearchLoaded(
          filterConfig: _filterConfig!,
          currentFilters: Map.from(_currentFilters),
          movies: _currentMovies,
          query: _currentQuery,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(
        SearchError(
          'Failed to initialize search: $e',
          currentFilters: _currentFilters,
          filterConfig: _filterConfig,
        ),
      );
    }
  }

  Future<void> updateFilter(String key, dynamic value) async {
    if (_filterConfig == null) return;

    _currentFilters[key] = value;
    _currentPage = 1;
    _hasReachedMax = false;

    emit(
      SearchLoading(
        filterConfig: _filterConfig,
        currentFilters: _currentFilters,
      ),
    );

    try {
      _currentMovies = await _sourceManager.activeSource.advancedSearch(
        _currentFilters,
        page: _currentPage,
        query: _currentQuery,
      );
      _hasReachedMax = _currentMovies.isEmpty;

      emit(
        SearchLoaded(
          filterConfig: _filterConfig!,
          currentFilters: Map.from(_currentFilters),
          movies: _currentMovies,
          query: _currentQuery,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(
        SearchError(
          'Failed to search: $e',
          currentFilters: _currentFilters,
          filterConfig: _filterConfig,
        ),
      );
    }
  }

  Future<void> updateQuery(String query) async {
    if (_filterConfig == null) return;

    _currentQuery = query;
    _currentPage = 1;
    _hasReachedMax = false;

    emit(
      SearchLoading(
        filterConfig: _filterConfig,
        currentFilters: _currentFilters,
      ),
    );

    try {
      _currentMovies = await _sourceManager.activeSource.advancedSearch(
        _currentFilters,
        page: _currentPage,
        query: _currentQuery,
      );
      _hasReachedMax = _currentMovies.isEmpty;

      emit(
        SearchLoaded(
          filterConfig: _filterConfig!,
          currentFilters: Map.from(_currentFilters),
          movies: _currentMovies,
          query: _currentQuery,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      emit(
        SearchError(
          'Failed to search: $e',
          currentFilters: _currentFilters,
          filterConfig: _filterConfig,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (_filterConfig == null || _isFetchingMore || _hasReachedMax) return;

    _isFetchingMore = true;
    _currentPage++;

    try {
      final newMovies = await _sourceManager.activeSource.advancedSearch(
        _currentFilters,
        page: _currentPage,
        query: _currentQuery,
      );

      if (newMovies.isEmpty) {
        _hasReachedMax = true;
      } else {
        _currentMovies.addAll(newMovies);
      }

      emit(
        SearchLoaded(
          filterConfig: _filterConfig!,
          currentFilters: Map.from(_currentFilters),
          movies: _currentMovies,
          query: _currentQuery,
          hasReachedMax: _hasReachedMax,
        ),
      );
    } catch (e) {
      // Don't emit error on pagination failure to avoid breaking current view, just reset flag
      _currentPage--;
    } finally {
      _isFetchingMore = false;
    }
  }
}

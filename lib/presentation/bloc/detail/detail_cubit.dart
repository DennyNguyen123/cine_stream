import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/movie_detail.dart';
import '../../../../domain/repositories/source_manager.dart';

abstract class DetailState {}

class DetailInitial extends DetailState {}

class DetailLoading extends DetailState {}

class DetailLoaded extends DetailState {
  final MovieDetail detail;
  DetailLoaded(this.detail);
}

class DetailError extends DetailState {
  final String message;
  DetailError(this.message);
}

class DetailCubit extends Cubit<DetailState> {
  final SourceManager _sourceManager;

  DetailCubit(this._sourceManager) : super(DetailInitial());

  Future<void> loadDetail(String movieId) async {
    emit(DetailLoading());
    try {
      final detail = await _sourceManager.activeSource.getMovieDetail(movieId);
      if (detail != null) {
        emit(DetailLoaded(detail));
      } else {
        emit(DetailError('Movie not found'));
      }
    } catch (e) {
      if (e.toString().contains('429')) {
        emit(
          DetailError(
            'Server KissKH đang quá tải (Rate Limit 429). Vui lòng đợi 1 phút rồi thử lại.',
          ),
        );
      } else {
        emit(DetailError('Failed to load detail: $e'));
      }
    }
  }
}

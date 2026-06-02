import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/movie_detail.dart';
import '../../../../domain/repositories/movie_source.dart';

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
  final MovieSource _movieSource;

  DetailCubit(this._movieSource) : super(DetailInitial());

  Future<void> loadDetail(int movieId) async {
    emit(DetailLoading());
    try {
      final detail = await _movieSource.getMovieDetail(movieId);
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

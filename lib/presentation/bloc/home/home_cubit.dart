import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/home_section.dart';
import '../../../../domain/repositories/source_manager.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<HomeSection> sections;
  HomeLoaded({required this.sections});
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}

class HomeCubit extends Cubit<HomeState> {
  final SourceManager _sourceManager;

  HomeCubit(this._sourceManager) : super(HomeInitial());

  Future<void> loadData() async {
    emit(HomeLoading());
    try {
      final sections = await _sourceManager.activeSource.getHomeSections();

      emit(HomeLoaded(sections: sections));
    } catch (e) {
      if (e.toString().contains('429')) {
        emit(
          HomeError(
            'Server KissKH đang chặn truy cập vì quá nhiều Request (Lỗi 429). Bạn vui lòng đợi 1 phút rồi thử lại.',
          ),
        );
      } else {
        emit(HomeError('Failed to load data: $e'));
      }
    }
  }
}

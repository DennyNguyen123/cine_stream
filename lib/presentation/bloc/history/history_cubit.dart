import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/entities/history_item.dart';
import '../../../../data/repositories/history_repository.dart';

abstract class HistoryState {}

class HistoryInitial extends HistoryState {}
class HistoryLoading extends HistoryState {}
class HistoryLoaded extends HistoryState {
  final List<HistoryItem> items;
  HistoryLoaded(this.items);
}
class HistoryError extends HistoryState {
  final String message;
  HistoryError(this.message);
}

class HistoryCubit extends Cubit<HistoryState> {
  final HistoryRepository _repository;

  HistoryCubit(this._repository) : super(HistoryInitial());

  Future<void> loadHistory() async {
    emit(HistoryLoading());
    try {
      final items = await _repository.getHistory();
      emit(HistoryLoaded(items));
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }

  Future<void> removeHistory(int movieId, String sourceId) async {
    try {
      await _repository.removeHistory(movieId, sourceId);
      loadHistory(); // Reload after deletion
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }
}

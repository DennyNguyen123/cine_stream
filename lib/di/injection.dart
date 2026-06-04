import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/history_repository.dart';

import '../data/repositories/subtitle_repository_impl.dart';
import '../data/repositories/translation_service.dart';
import '../data/repositories/external_subtitle_repository.dart';
import '../data/sources/kisskh/kisskh_api.dart';
import '../data/sources/kisskh/kisskh_source.dart';
import '../data/sources/cinemeta/cinemeta_source.dart';
import '../data/sources/phimmoichill/phimmoichill_api.dart';
import '../data/sources/phimmoichill/phimmoichill_source.dart';

import '../domain/repositories/movie_source.dart';
import '../domain/repositories/source_manager.dart';
import '../domain/repositories/subtitle_repository.dart';
import '../presentation/bloc/detail/detail_cubit.dart';
import '../presentation/bloc/home/home_cubit.dart';
import '../presentation/bloc/search/search_cubit.dart';
import '../presentation/bloc/history/history_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  // Network
  getIt.registerLazySingleton<Dio>(() => Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  )));

  // Repositories
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => prefs);
  getIt.registerLazySingleton<HistoryRepository>(() => HistoryRepositoryImpl(getIt()));
  getIt.registerLazySingleton<SubtitleRepository>(() => SubtitleRepositoryImpl(getIt()));
  getIt.registerLazySingleton<ExternalSubtitleRepository>(() => ExternalSubtitleRepository(getIt()));
  getIt.registerLazySingleton<TranslationService>(() => TranslationService(getIt()));
  
  // Sources
  getIt.registerLazySingleton(() => KissKhApi(getIt()));
  getIt.registerLazySingleton(() => PhimMoiChillApi(getIt()));
  
  final kissKhSource = KissKhSource(getIt());
  final cinemetaSource = CinemetaSource(getIt());
  final phimMoiChillSource = PhimMoiChillSource(getIt());


  final sourceManager = SourceManager(
    prefs: prefs,
    sources: {
      'cinemeta': cinemetaSource,
      'phimmoichill': phimMoiChillSource,
      'kisskh': kissKhSource,
    },
    defaultSourceId: 'cinemeta',
  );
  getIt.registerLazySingleton<SourceManager>(() => sourceManager);

  // Provide the active source dynamically
  getIt.registerFactory<MovieSource>(() => getIt<SourceManager>().activeSource);

  // UseCases & Blocs
  getIt.registerFactory(() => HomeCubit(getIt()));
  getIt.registerFactory(() => DetailCubit(getIt()));
  getIt.registerFactory(() => SearchCubit(getIt()));
  getIt.registerFactory(() => HistoryCubit(getIt()));
}

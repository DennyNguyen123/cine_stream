import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../data/repositories/subtitle_repository_impl.dart';
import '../data/sources/kisskh/kisskh_api.dart';
import '../data/sources/kisskh/kisskh_source.dart';
import '../domain/repositories/movie_source.dart';
import '../domain/repositories/subtitle_repository.dart';
import '../presentation/bloc/detail/detail_cubit.dart';
import '../presentation/bloc/home/home_cubit.dart';
import '../presentation/bloc/search/search_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  // Network
  getIt.registerLazySingleton<Dio>(() => Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  )));

  // Repositories
  getIt.registerLazySingleton<SubtitleRepository>(() => SubtitleRepositoryImpl(getIt()));
  
  // Sources
  getIt.registerLazySingleton(() => KissKhApi(getIt()));
  getIt.registerLazySingleton<MovieSource>(() => KissKhSource(getIt()));

  // UseCases & Blocs
  getIt.registerFactory(() => HomeCubit(getIt()));
  getIt.registerFactory(() => DetailCubit(getIt()));
  getIt.registerFactory(() => SearchCubit(getIt()));
}

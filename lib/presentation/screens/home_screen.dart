import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/movie.dart';
import '../bloc/home/home_cubit.dart';
import '../../di/injection.dart';
import '../widgets/movie_card.dart';
import '../widgets/featured_banner.dart';
import '../../core/theme/app_colors.dart';
import 'detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HomeCubit>()..loadData(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading || state is HomeInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is HomeError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
            } else if (state is HomeLoaded) {
              final sections = state.sections;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Button at the top right
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, right: 48.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white, size: 32),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchScreen()),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    if (sections.isNotEmpty && sections.first.movies.isNotEmpty)
                      FeaturedBanner(
                        movie: sections.first.movies.first,
                        onWatchClick: (movie) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)),
                          );
                        },
                      ),
                    
                    const SizedBox(height: 24),
                    
                    ...sections.map((section) {
                      if (section.movies.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: _buildMovieRow(section.title, section.movies),
                      );
                    }),
                    
                    const SizedBox(height: 48),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildMovieRow(String title, List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 58.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 50.0),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: MovieCard(
                  movie: movies[index],
                  onFocused: () {
                    // Cập nhật banner nếu muốn
                  },
                  onClick: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailScreen(movie: movies[index])),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PhimMoiMovieJson {
  final int id;
  final String name;
  final String originName;
  final String slug;
  final String posterUrl;
  final String thumbUrl;
  final int year;
  final String status;
  final String displayStatus;

  PhimMoiMovieJson({
    required this.id,
    required this.name,
    required this.originName,
    required this.slug,
    required this.posterUrl,
    required this.thumbUrl,
    required this.year,
    required this.status,
    required this.displayStatus,
  });

  factory PhimMoiMovieJson.fromJson(Map<String, dynamic> json) {
    return PhimMoiMovieJson(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      originName: json['origin_name'] ?? '',
      slug: json['slug'] ?? '',
      posterUrl: json['poster_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      year: json['year'] ?? 0,
      status: json['status'] ?? '',
      displayStatus: json['display_status'] ?? '',
    );
  }
}

class PhimMoiSearchResponse {
  final bool success;
  final List<PhimMoiMovieJson> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  PhimMoiSearchResponse({
    required this.success,
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory PhimMoiSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final itemsList = (data['items'] as List?) ?? (data['results'] as List?);
    
    return PhimMoiSearchResponse(
      success: json['success'] ?? false,
      items: itemsList?.map((e) => PhimMoiMovieJson.fromJson(e)).toList() ?? [],
      total: data['total'] ?? 0,
      page: data['page'] ?? 1,
      limit: data['limit'] ?? 10,
      hasMore: data['hasMore'] ?? false,
    );
  }
}

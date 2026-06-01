class Review {
  final String id;
  final String category; // 'ride' | 'stay'
  final String subjectId; // entity being reviewed (stayId / driver-or-passenger phone)
  final String subjectName;
  final String authorRole; // 'Guest' | 'Host' | 'Driver' | 'Passenger'
  final String authorName;
  final double rating; // 1-5
  final String comment;
  final List<String> tags;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.category,
    required this.subjectId,
    required this.subjectName,
    required this.authorRole,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.tags = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'authorRole': authorRole,
        'authorName': authorName,
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] ?? '',
        category: json['category'] ?? 'stay',
        subjectId: json['subjectId'] ?? '',
        subjectName: json['subjectName'] ?? '',
        authorRole: json['authorRole'] ?? 'Guest',
        authorName: json['authorName'] ?? 'Anonymous',
        rating: (json['rating'] ?? 5.0).toDouble(),
        comment: json['comment'] ?? '',
        tags: List<String>.from(json['tags'] ?? const []),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

/// Quick-pick positive tags shown when writing a review.
const List<String> kReviewTags = [
  'Clean',
  'Friendly',
  'Good Value',
  'Comfortable',
  'As Described',
  'Safe',
  'Punctual',
  'Would Recommend',
];

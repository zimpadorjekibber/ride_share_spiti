import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/review_model.dart';
import '../services/local_storage_service.dart';

/// Opens a sheet that lists existing reviews for [subjectId] and lets the
/// current user add a new one (in the [writeRole], e.g. 'Guest' or 'Host').
/// Used for both rides and stays so providers AND seekers can review each other.
Future<void> showReviewsSheet(
  BuildContext context, {
  required String category,
  required String subjectId,
  required String subjectName,
  required String writeRole,
  Color accent = const Color(0xFF6366F1),
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isDark ? const Color(0xFF111827) : Colors.white;
      final primary = isDark ? Colors.white : Colors.black87;
      final sub = isDark ? Colors.grey[400] : Colors.grey[600];

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: FutureBuilder<List<Review>>(
                  future: LocalStorageService.getReviews(category, subjectId),
                  builder: (ctx, snap) {
                    final reviews = snap.data ?? [];
                    final avg = reviews.isEmpty
                        ? 0.0
                        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.reviews_outlined, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Reviews · $subjectName",
                                style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              return Icon(
                                i < avg.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                            const SizedBox(width: 8),
                            Text(
                              reviews.isEmpty ? "No reviews yet" : "${avg.toStringAsFixed(1)} · ${reviews.length} review(s)",
                              style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final added = await _showWriteReviewSheet(
                                context,
                                category: category,
                                subjectId: subjectId,
                                subjectName: subjectName,
                                authorRole: writeRole,
                                accent: accent,
                              );
                              if (added == true) setSheetState(() {});
                            },
                            icon: const Icon(Icons.rate_review, size: 16, color: Colors.white),
                            label: Text("Write a review as $writeRole",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: reviews.isEmpty
                              ? Center(
                                  child: Text(
                                    "Be the first to leave a review!",
                                    style: TextStyle(color: sub, fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: reviews.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) => _reviewTile(reviews[i], isDark, primary, sub, accent),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      );
    },
  );
}

Widget _reviewTile(Review r, bool isDark, Color primary, Color? sub, Color accent) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: accent.withValues(alpha: 0.18),
              child: Text(
                r.authorName.isNotEmpty ? r.authorName[0].toUpperCase() : '?',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.authorName,
                      style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text("${r.authorRole} · ${_timeAgo(r.createdAt)}",
                      style: TextStyle(color: sub, fontSize: 10)),
                ],
              ),
            ),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < r.rating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 13,
                );
              }),
            ),
          ],
        ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(r.comment, style: TextStyle(color: sub, fontSize: 12, height: 1.4)),
        ],
        if (r.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t, style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
                    ))
                .toList(),
          ),
        ],
      ],
    ),
  );
}

/// Convenience: directly open the write-review form (used when a "Rate X"
/// button should jump straight to writing instead of the list).
Future<void> showWriteReviewSheet(
  BuildContext context, {
  required String category,
  required String subjectId,
  required String subjectName,
  required String authorRole,
  Color accent = const Color(0xFF6366F1),
}) async {
  await _showWriteReviewSheet(
    context,
    category: category,
    subjectId: subjectId,
    subjectName: subjectName,
    authorRole: authorRole,
    accent: accent,
  );
}

Future<bool?> _showWriteReviewSheet(
  BuildContext context, {
  required String category,
  required String subjectId,
  required String subjectName,
  required String authorRole,
  Color accent = const Color(0xFF6366F1),
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isDark ? const Color(0xFF111827) : Colors.white;
      final primary = isDark ? Colors.white : Colors.black87;
      final sub = isDark ? Colors.grey[400] : Colors.grey[600];

      int rating = 5;
      final Set<String> selectedTags = {};
      final commentController = TextEditingController();

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Rate $subjectName",
                        style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text("Reviewing as $authorRole",
                        style: TextStyle(color: sub, fontSize: 11)),
                    const SizedBox(height: 16),
                    // Star picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() => rating = i + 1);
                          },
                          icon: Icon(
                            i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 38,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text("Quick tags", style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kReviewTags.map((tag) {
                        final selected = selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            selected ? selectedTags.remove(tag) : selectedTags.add(tag);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? accent : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? accent : Colors.transparent),
                            ),
                            child: Text(tag,
                                style: TextStyle(
                                    color: selected ? Colors.white : sub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      style: TextStyle(color: primary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Share your experience (optional)...",
                        hintStyle: TextStyle(color: sub, fontSize: 12),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final profile = await LocalStorageService.getProfile();
                          final authorName = profile.isRegistered && profile.name.isNotEmpty
                              ? profile.name
                              : 'A $authorRole';
                          await LocalStorageService.addReview(Review(
                            id: 'rv_${DateTime.now().millisecondsSinceEpoch}',
                            category: category,
                            subjectId: subjectId,
                            subjectName: subjectName,
                            authorRole: authorRole,
                            authorName: authorName,
                            rating: rating.toDouble(),
                            comment: commentController.text.trim(),
                            tags: selectedTags.toList(),
                            createdAt: DateTime.now(),
                          ));
                          navigator.pop(true);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Review submitted. Dhanyavaad! 🙏'),
                              backgroundColor: accent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Submit Review",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Small inline badge showing a subject's average rating + review count,
/// loaded from the saved reviews. Tappable to open the full reviews sheet.
class RatingBadge extends StatelessWidget {
  final String category;
  final String subjectId;
  final String subjectName;
  final String writeRole;
  final Color accent;

  const RatingBadge({
    super.key,
    required this.category,
    required this.subjectId,
    required this.subjectName,
    required this.writeRole,
    this.accent = const Color(0xFF6366F1),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: LocalStorageService.getReviews(category, subjectId),
      builder: (context, snap) {
        final reviews = snap.data ?? [];
        final avg = reviews.isEmpty
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        return GestureDetector(
          onTap: () => showReviewsSheet(
            context,
            category: category,
            subjectId: subjectId,
            subjectName: subjectName,
            writeRole: writeRole,
            accent: accent,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 3),
                Text(
                  reviews.isEmpty ? "New" : avg.toStringAsFixed(1),
                  style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 3),
                Text(
                  reviews.isEmpty ? "· no reviews" : "· ${reviews.length} review${reviews.length == 1 ? '' : 's'}",
                  style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 9),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

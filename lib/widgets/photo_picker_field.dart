import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pick up to [max] photos (camera or gallery), shown as a thumbnail strip with
/// remove buttons. Reports the current list (local paths and/or existing URLs).
class MultiPhotoPickerField extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final Color accent;
  final int max;

  const MultiPhotoPickerField({
    super.key,
    required this.paths,
    required this.onChanged,
    required this.accent,
    this.max = 10,
  });

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(maxWidth: 1280, imageQuality: 80);
      if (files.isEmpty) return;
      final remaining = max - paths.length;
      final added = files.take(remaining).map((f) => f.path);
      onChanged([...paths, ...added]);
    } catch (_) {}
  }

  Future<void> _takePhoto(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
      if (f != null && paths.length < max) onChanged([...paths, f.path]);
    } catch (_) {}
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_library, color: accent),
              title: const Text('Choose from gallery (multiple)'),
              onTap: () { Navigator.pop(ctx); _pickFromGallery(context); },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera, color: accent),
              title: const Text('Take a photo'),
              onTap: () { Navigator.pop(ctx); _takePhoto(context); },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String p, VoidCallback onRemove) {
    final isUrl = p.startsWith('http');
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isUrl
              ? Image.network(p, width: 90, height: 90, fit: BoxFit.cover)
              : Image.file(File(p), width: 90, height: 90, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < paths.length; i++) ...[
                _thumb(paths[i], () {
                  final next = [...paths]..removeAt(i);
                  onChanged(next);
                }),
                const SizedBox(width: 8),
              ],
              if (paths.length < max)
                GestureDetector(
                  onTap: () => _showAddSheet(context),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: accent, size: 24),
                        const SizedBox(height: 4),
                        Text('Add', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('${paths.length}/$max photos',
            style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 11)),
      ],
    );
  }
}

/// Read-only horizontal strip of photos (URLs and/or local paths) with
/// tap-to-zoom. Used to show seating-area / table-view photos to hosts and
/// seekers. Renders nothing when [photos] is empty.
class SeatingPhotoStrip extends StatelessWidget {
  final List<String> photos;
  final double height;
  const SeatingPhotoStrip({super.key, required this.photos, this.height = 76});

  static ImageProvider _provider(String p) =>
      p.startsWith('http') ? NetworkImage(p) : FileImage(File(p));

  void _openViewer(BuildContext context, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _SeatingPhotoViewer(photos: photos, initialIndex: startIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _openViewer(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image(
              image: _provider(photos[i]),
              width: height,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: height,
                height: height,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom viewer for [SeatingPhotoStrip].
class _SeatingPhotoViewer extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;
  const _SeatingPhotoViewer({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialIndex);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(
                  image: SeatingPhotoStrip._provider(photos[i]),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable box that lets a host add ONE property/food photo from the
/// camera or gallery, shows a live thumbnail, and reports the file path back.
class PhotoPickerField extends StatelessWidget {
  final String path;
  final ValueChanged<String> onPicked;
  final Color accent;
  final String label;

  const PhotoPickerField({
    super.key,
    required this.path,
    required this.onPicked,
    required this.accent,
    this.label = 'Add Property Photo',
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, maxWidth: 1280, imageQuality: 80);
      if (file != null) onPicked(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${source == ImageSource.camera ? "camera" : "gallery"}.')),
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_camera, color: accent),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: accent),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(context, ImageSource.gallery);
              },
            ),
            if (path.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Remove photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPicked('');
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = path.isNotEmpty && File(path).existsSync();
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () => _showSourceSheet(context),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPhoto ? accent : accent.withValues(alpha: 0.35),
            width: hasPhoto ? 2 : 1.5,
          ),
        ),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: accent, size: 34),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Tap to take or upload a photo',
                      style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
      ),
    );
  }
}

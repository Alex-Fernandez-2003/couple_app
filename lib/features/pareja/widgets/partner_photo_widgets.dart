part of '../screens/pareja_screen.dart';

class _PartnerPhotoAvatar extends StatelessWidget {
  const _PartnerPhotoAvatar({
    required this.photoPath,
    required this.onChangePhoto,
  });

  static const _heroTag = 'partner_photo_hero';

  final String? photoPath;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    return Semantics(
      button: true,
      label: hasPhoto ? 'Ver foto de pareja' : 'Agregar foto de pareja',
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: InkWell(
                onTap: hasPhoto
                    ? () => _openPartnerPhotoViewer(context, path)
                    : onChangePhoto,
                customBorder: const CircleBorder(),
                child: Hero(
                  tag: _heroTag,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPhoto
                          ? null
                          : LinearGradient(
                              colors: [
                                const Color(0xFFFD8392).withValues(alpha: 0.7),
                                const Color(0xFFF7C0C9).withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasPhoto
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Material(
                color: const Color(0xFFFD8392),
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  onPressed: onChangePhoto,
                  icon: Icon(
                    hasPhoto ? Icons.edit : Icons.photo_camera,
                    color: Colors.white,
                  ),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: hasPhoto ? 'Cambiar foto' : 'Agregar foto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPartnerPhotoViewer(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _PartnerPhotoViewer(photoPath: path, heroTag: _heroTag),
          );
        },
      ),
    );
  }
}

class _PartnerPhotoViewer extends StatelessWidget {
  const _PartnerPhotoViewer({required this.photoPath, required this.heroTag});

  final String photoPath;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(File(photoPath), fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cerrar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

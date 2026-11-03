import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'meta_config.dart';
import 'meta_share.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetaShareApp());
}

class MetaShareApp extends StatelessWidget {
  const MetaShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meta Share',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6B4A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ShareHomePage(),
    );
  }
}

class ShareHomePage extends StatefulWidget {
  const ShareHomePage({super.key});

  @override
  State<ShareHomePage> createState() => _ShareHomePageState();
}

class _ShareHomePageState extends State<ShareHomePage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _image;
  Uint8List? _previewBytes;
  ShareDestination? _busyDestination;
  String? _status;
  bool _statusIsError = false;

  bool get _sharingSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 92);
      if (!mounted || image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = image;
        _previewBytes = bytes;
        _status = null;
      });
    } on PlatformException catch (error) {
      _showStatus(
        error.message ?? 'Could not open the photo picker.',
        error: true,
      );
    }
  }

  Future<void> _share(ShareDestination destination) async {
    final image = _image;
    if (image == null || _busyDestination != null) return;

    setState(() {
      _busyDestination = destination;
      _status = null;
    });

    try {
      await MetaShare.share(
        destination: destination,
        filePath: image.path,
        facebookAppId: facebookAppId,
      );
      if (!mounted) return;
      _showStatus(_successMessage(destination));
    } on PlatformException catch (error) {
      _showStatus(
        error.message ?? 'Could not open the share target.',
        error: true,
      );
    } on MissingPluginException {
      _showStatus(
        'Direct sharing is available in the Android and iOS builds.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busyDestination = null);
    }
  }

  void _showStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusIsError = error;
    });
  }

  String _successMessage(ShareDestination destination) {
    return switch (destination) {
      ShareDestination.instagramStory =>
        'Instagram Stories is open. Publish the photo when you are ready.',
      ShareDestination.instagramFeed =>
        'Instagram is open with this photo. Choose Feed if Instagram asks, then publish.',
      ShareDestination.facebookStory =>
        'Facebook Stories is open. Publish the photo when you are ready.',
      ShareDestination.facebookFeed =>
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'Choose Facebook in the share sheet to post this photo.'
            : 'Facebook is open. Publish the photo when you are ready.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = _image;
    final previewBytes = _previewBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Share to Meta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a photo, then send it straight to Instagram or Facebook.',
                style: theme.textTheme.bodyLarge,
              ),
              if (!_sharingSupported) ...[
                const SizedBox(height: 16),
                const _Notice(
                  message:
                      'Run this on an Android phone or iPhone with Instagram and Facebook installed. Sharing uses those apps directly.',
                ),
              ],
              const SizedBox(height: 20),
              _ImagePreview(bytes: previewBytes, name: image?.name),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busyDestination == null
                          ? () => _pick(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busyDestination == null
                          ? () => _pick(ImageSource.camera)
                          : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Share', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ShareButton(
                label: 'Instagram Story',
                detail:
                    'Opens the story composer with this photo as the background.',
                icon: Icons.amp_stories_outlined,
                enabled: image != null && _busyDestination == null,
                busy: _busyDestination == ShareDestination.instagramStory,
                onPressed: () => _share(ShareDestination.instagramStory),
              ),
              _ShareButton(
                label: 'Instagram Feed',
                detail: 'Sends the photo into Instagram’s post composer.',
                icon: Icons.grid_on_outlined,
                enabled: image != null && _busyDestination == null,
                busy: _busyDestination == ShareDestination.instagramFeed,
                onPressed: () => _share(ShareDestination.instagramFeed),
              ),
              _ShareButton(
                label: 'Facebook Story',
                detail: 'Opens the Facebook story composer with this photo.',
                icon: Icons.auto_stories_outlined,
                enabled: image != null && _busyDestination == null,
                busy: _busyDestination == ShareDestination.facebookStory,
                onPressed: () => _share(ShareDestination.facebookStory),
              ),
              _ShareButton(
                label: 'Facebook Feed',
                detail: defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Opens the share sheet so you can post it with Facebook.'
                    : 'Sends the photo into the Facebook composer.',
                icon: Icons.public,
                enabled: image != null && _busyDestination == null,
                busy: _busyDestination == ShareDestination.facebookFeed,
                onPressed: () => _share(ShareDestination.facebookFeed),
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                _Notice(message: _status!, isError: _statusIsError),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.name});

  final Uint8List? bytes;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = this.bytes;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No photo selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          name ?? 'Selected photo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.label,
    required this.detail,
    required this.icon,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.tonal(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          children: [
            busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: foreground)),
      ),
    );
  }
}

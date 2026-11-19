import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/app_exception.dart';

/// Origem suportada para captura de foto/print de conquista.
enum MediaSourceType { camera, gallery }

/// Serviço nativo para captura segura de imagens com compressão e privacidade.
class MediaService {
  final ImagePicker _picker;
  final Future<PermissionStatus> Function(Permission permission)
  _requestPermission;

  MediaService({
    ImagePicker? picker,
    Future<PermissionStatus> Function(Permission permission)? requestPermission,
  }) : _picker = picker ?? ImagePicker(),
       _requestPermission =
           requestPermission ?? ((permission) => permission.request());

  /// Captura ou seleciona uma imagem aplicando compressão e bloqueio de EXIF.
  ///
  /// Retorna o caminho do arquivo local selecionado ou `null` caso o usuário
  /// cancele a seleção. Lança [PermissionDeniedAppException] se a permissão
  /// for negada. Nenhum caminho absoluto é registrado em logs.
  Future<String?> pickCompressedImage(MediaSourceType source) async {
    final granted = await _ensurePermission(source);
    if (!granted) {
      throw const PermissionDeniedAppException(
        'Permissão negada para acessar a câmera ou galeria.',
      );
    }

    final imageSource = source == MediaSourceType.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final XFile? pickedFile = await _picker.pickImage(
      source: imageSource,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
      requestFullMetadata: false,
    );

    if (pickedFile == null || pickedFile.path.trim().isEmpty) {
      return null;
    }

    return pickedFile.path;
  }

  Future<bool> _ensurePermission(MediaSourceType source) async {
    if (source == MediaSourceType.camera) {
      final status = await _requestPermission(Permission.camera);
      return status.isGranted || status.isLimited;
    }

    final photosStatus = await _requestPermission(Permission.photos);
    if (photosStatus.isGranted || photosStatus.isLimited) {
      return true;
    }

    // Fallback para versões do Android que utilizam permissão de armazenamento.
    final storageStatus = await _requestPermission(Permission.storage);
    return storageStatus.isGranted || storageStatus.isLimited;
  }
}

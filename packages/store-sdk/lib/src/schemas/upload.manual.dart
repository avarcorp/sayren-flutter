// 손으로 쓴 부분 — upload.ts의 함수 구현.
part of 'upload.dart';

const _mb = 1024 * 1024;

/// 파일명의 소문자 확장자를 돌려줍니다. 확장자가 없으면 `''`입니다.
String uploadExtensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return '';
  return filename.substring(dot + 1).toLowerCase();
}

/// 용도 제한([UPLOAD_PURPOSE_LIMITS]) 위반을 검사합니다. 통과하면 null입니다.
///
/// 서버가 던지는 오류와 화면이 먼저 띄우는 안내가 갈리지 않도록 한 함수로 판정합니다. [size]는 파일 바이트 크기입니다.
UploadRejection? uploadRejection(UploadPurpose purpose, String filename, [num? size]) {
  final limit = UPLOAD_PURPOSE_LIMITS[purpose]!;
  final extensions = limit['extensions']! as List<String>;
  final maxBytes = limit['maxBytes']! as int;
  if (!extensions.contains(uploadExtensionOf(filename))) {
    return UploadRejection(
      status: 400,
      code: 'UNSUPPORTED_FILE_TYPE',
      message: '지원하지 않는 파일 형식입니다. ${extensions.join(', ')}만 올릴 수 있습니다',
    );
  }
  if (size != null && size > maxBytes) {
    return UploadRejection(
      status: 413,
      code: 'FILE_TOO_LARGE',
      message: '파일이 너무 큽니다. ${maxBytes ~/ _mb}MB까지 올릴 수 있습니다',
    );
  }
  return null;
}

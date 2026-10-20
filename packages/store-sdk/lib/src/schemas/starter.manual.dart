// 손으로 쓴 부분 — starter.ts의 참고 주소 검사(brandBriefReferenceSchema refine).
part of 'starter.dart';

/// `new URL(value)`이 http·https 주소로 읽히는가
bool _isHttpUrl(String value) => parseHttpUrl(value) != null;

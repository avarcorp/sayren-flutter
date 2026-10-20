// 손으로 쓴 파일 — WHATWG URL 파서 중 http(s) 주소 판정에 필요한 부분(SDK 내부용, 엔트리포인트가 공개하지 않는다).
// Node 스키마 함수가 `new URL(value)`로 판정하는 자리(isWebOrigin·http 주소 검사·호스트 이름 읽기·IDNA)를 Dart에서 같게 맞춘다.
//
// 차이: IDNA(UTS #46) 매핑은 소문자 + NFKC + 전각 마침표 치환으로 근사한다. IPv6 호스트는 문자 검사만 하고 정규 표기로 줄이지 않는다.
import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// http(s) 주소를 읽은 결과 — WHATWG `URL`의 같은 이름 속성이다
class HttpUrl {
  const HttpUrl._(
      this.protocol, this.username, this.password, this.hostname, this.port, this.pathname, this.search, this.hash);

  /// `https:`·`http:`
  final String protocol;

  /// 사용자 이름(없으면 빈 문자열)
  final String username;

  /// 비밀번호(없으면 빈 문자열)
  final String password;

  /// ASCII 호스트 이름(소문자, 국제화 도메인은 punycode)
  final String hostname;

  /// 포트(기본 포트·없음은 빈 문자열)
  final String port;

  /// 정규화한 경로(빈 경로는 `/`)
  final String pathname;

  /// `?`를 포함한 쿼리. 비어 있으면 빈 문자열
  final String search;

  /// `#`를 포함한 조각. 비어 있으면 빈 문자열
  final String hash;
}

/// `new URL(input)`이 http·https 주소로 성공하면 그 결과, 실패하거나 다른 스킴이면 null이다
HttpUrl? parseHttpUrl(String input) {
  // 앞뒤 C0 제어 문자·공백을 떼고, 탭·줄바꿈은 어디서든 지운다
  var s = input.replaceFirst(RegExp(r'^[\u0000- ]+'), '').replaceFirst(RegExp(r'[\u0000- ]+$'), '');
  s = s.replaceAll(RegExp('[\t\n\r]'), '');
  final scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):').firstMatch(s);
  if (scheme == null) return null;
  final protocol = scheme.group(1)!.toLowerCase();
  if (protocol != 'http' && protocol != 'https') return null;
  var rest = s.substring(scheme.end).replaceFirst(RegExp(r'^[/\\]+'), '');

  final authorityEnd = rest.indexOf(RegExp(r'[/\\?#]'));
  final authority = authorityEnd < 0 ? rest : rest.substring(0, authorityEnd);
  rest = authorityEnd < 0 ? '' : rest.substring(authorityEnd);

  var username = '';
  var password = '';
  var hostPort = authority;
  final at = authority.lastIndexOf('@');
  if (at >= 0) {
    final userinfo = authority.substring(0, at);
    hostPort = authority.substring(at + 1);
    if (hostPort.isEmpty) return null;
    final colon = userinfo.indexOf(':');
    username = colon < 0 ? userinfo : userinfo.substring(0, colon);
    password = colon < 0 ? '' : userinfo.substring(colon + 1);
  }

  String rawHost;
  String? rawPort;
  if (hostPort.startsWith('[')) {
    final close = hostPort.indexOf(']');
    if (close < 0) return null;
    rawHost = hostPort.substring(0, close + 1);
    final after = hostPort.substring(close + 1);
    if (after.isNotEmpty && !after.startsWith(':')) return null;
    rawPort = after.isEmpty ? null : after.substring(1);
  } else {
    final colon = hostPort.indexOf(':');
    rawHost = colon < 0 ? hostPort : hostPort.substring(0, colon);
    rawPort = colon < 0 ? null : hostPort.substring(colon + 1);
  }
  if (rawHost.isEmpty) return null;
  final hostname = _parseHost(rawHost);
  if (hostname == null) return null;

  var port = '';
  if (rawPort != null && rawPort.isNotEmpty) {
    if (!RegExp(r'^[0-9]+$').hasMatch(rawPort)) return null;
    final n = int.parse(rawPort.length > 6 ? '999999' : rawPort);
    if (n > 65535) return null;
    final isDefault = (protocol == 'http' && n == 80) || (protocol == 'https' && n == 443);
    port = isDefault ? '' : '$n';
  }

  var path = rest;
  var search = '';
  var hash = '';
  final hashAt = path.indexOf('#');
  if (hashAt >= 0) {
    final h = path.substring(hashAt + 1);
    hash = h.isEmpty ? '' : '#$h';
    path = path.substring(0, hashAt);
  }
  final queryAt = path.indexOf('?');
  if (queryAt >= 0) {
    final q = path.substring(queryAt + 1);
    search = q.isEmpty ? '' : '?$q';
    path = path.substring(0, queryAt);
  }
  return HttpUrl._('$protocol:', username, password, hostname, port, _normalizePath(path), search, hash);
}

/// 특수 스킴의 경로 정규화(`.`·`..`·`%2e` 조각)
String _normalizePath(String raw) {
  final segments = <String>[];
  final parts = raw.isEmpty ? <String>[''] : raw.split(RegExp(r'[/\\]'));
  // 경로는 `/`로 시작하므로 첫 조각(빈 문자열)은 건너뛴다
  final input = raw.isEmpty ? <String>[] : parts.sublist(1);
  for (var i = 0; i < input.length; i++) {
    final seg = input[i];
    final last = i == input.length - 1;
    final lower = seg.toLowerCase();
    final doubleDot = lower == '..' || lower == '.%2e' || lower == '%2e.' || lower == '%2e%2e';
    final singleDot = lower == '.' || lower == '%2e';
    if (doubleDot) {
      if (segments.isNotEmpty) segments.removeLast();
      if (last) segments.add('');
    } else if (singleDot) {
      if (last) segments.add('');
    } else {
      segments.add(seg);
    }
  }
  return '/${segments.join('/')}';
}

const _forbiddenDomain = '\u0000\t\n\r #/:<>?@[\\]^|%\u007f';

String? _parseHost(String raw) {
  if (raw.startsWith('[')) {
    if (!raw.endsWith(']')) return null;
    final inner = raw.substring(1, raw.length - 1);
    if (inner.isEmpty || !inner.contains(':') || !RegExp(r'^[0-9A-Fa-f:.]+$').hasMatch(inner)) return null;
    return '[${inner.toLowerCase()}]';
  }
  final decoded = _percentDecode(raw);
  final ascii = domainToAscii(decoded);
  if (ascii == null || ascii.isEmpty) return null;
  for (final c in ascii.codeUnits) {
    if (c < 0x20 || _forbiddenDomain.codeUnits.contains(c)) return null;
  }
  if (_endsInNumber(ascii)) return _parseIpv4(ascii);
  return ascii;
}

String _percentDecode(String s) {
  final bytes = <int>[];
  final units = utf8.encode(s);
  for (var i = 0; i < units.length; i++) {
    final b = units[i];
    if (b == 0x25 && i + 2 < units.length) {
      final hex = String.fromCharCodes(units.sublist(i + 1, i + 3));
      final v = int.tryParse(hex, radix: 16);
      if (v != null && RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(hex)) {
        bytes.add(v);
        i += 2;
        continue;
      }
    }
    bytes.add(b);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// UTS #46 domainToASCII 근사 — 소문자·NFKC·전각 마침표를 맞추고 ASCII가 아닌 라벨은 punycode(`xn--`)로 바꾼다. 실패하면 null
String? domainToAscii(String domain) {
  var d = domain.replaceAll(RegExp('[\u3002\uFF0E\uFF61]'), '.');
  // JS toLowerCase는 U+0130(İ)을 i + U+0307로 바꾼다(Dart는 i 하나)
  if (RegExp(r'[^\x00-\x7f]').hasMatch(d)) {
    d = unorm.nfkc(d.replaceAll('\u0130', 'i\u0307').toLowerCase()).toLowerCase();
  }
  final labels = d.split('.');
  final out = <String>[];
  for (final label in labels) {
    final lower = label.toLowerCase();
    if (RegExp(r'^[\x00-\x7f]*$').hasMatch(lower)) {
      if (lower.startsWith('xn--') && _punycodeDecode(lower.substring(4)) == null) return null;
      out.add(lower);
    } else {
      final encoded = _punycodeEncode(lower);
      if (encoded == null) return null;
      out.add('xn--$encoded');
    }
  }
  return out.join('.');
}

bool _endsInNumber(String host) {
  final parts = host.split('.');
  if (parts.last.isEmpty) {
    if (parts.length == 1) return false;
    parts.removeLast();
  }
  final last = parts.last;
  if (last.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(last)) return true;
  return _ipv4Number(last) != null;
}

int? _ipv4Number(String s) {
  if (s.isEmpty) return null;
  var radix = 10;
  var t = s;
  if (t.length >= 2 && (t.startsWith('0x') || t.startsWith('0X'))) {
    radix = 16;
    t = t.substring(2);
  } else if (t.length >= 2 && t.startsWith('0')) {
    radix = 8;
    t = t.substring(1);
  }
  if (t.isEmpty) return 0;
  final pattern = radix == 16
      ? RegExp(r'^[0-9A-Fa-f]+$')
      : radix == 8
          ? RegExp(r'^[0-7]+$')
          : RegExp(r'^[0-9]+$');
  if (!pattern.hasMatch(t)) return null;
  return BigInt.parse(t, radix: radix) > BigInt.from(0xFFFFFFFFFFFF) ? 0x1000000000000 : int.parse(t, radix: radix);
}

String? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.last.isEmpty && parts.length > 1) parts.removeLast();
  if (parts.length > 4) return null;
  final numbers = <int>[];
  for (final p in parts) {
    final n = _ipv4Number(p);
    if (n == null) return null;
    numbers.add(n);
  }
  for (var i = 0; i < numbers.length - 1; i++) {
    if (numbers[i] > 255) return null;
  }
  var limit = 1;
  for (var i = 0; i < 5 - numbers.length; i++) {
    limit *= 256;
  }
  if (numbers.last >= limit) return null;
  var ipv4 = numbers.last;
  for (var i = 0; i < numbers.length - 1; i++) {
    var weight = 1;
    for (var k = 0; k < 3 - i; k++) {
      weight *= 256;
    }
    ipv4 += numbers[i] * weight;
  }
  return [for (var k = 3; k >= 0; k--) (ipv4 >> (8 * k)) & 0xff].join('.');
}

// ── punycode(RFC 3492) ──

const _base = 36, _tMin = 1, _tMax = 26, _skew = 38, _damp = 700, _initialBias = 72, _initialN = 128;

int _adapt(int delta, int numPoints, bool first) {
  var d = first ? delta ~/ _damp : delta ~/ 2;
  d += d ~/ numPoints;
  var k = 0;
  while (d > ((_base - _tMin) * _tMax) ~/ 2) {
    d ~/= _base - _tMin;
    k += _base;
  }
  return k + ((_base - _tMin + 1) * d) ~/ (d + _skew);
}

String _digit(int d) => String.fromCharCode(d < 26 ? 0x61 + d : 0x30 + d - 26);

String? _punycodeEncode(String input) {
  final cps = input.runes.toList();
  final out = StringBuffer();
  for (final c in cps) {
    if (c < 0x80) out.writeCharCode(c);
  }
  final basic = out.length;
  var h = basic;
  if (basic > 0) out.write('-');
  var n = _initialN, delta = 0, bias = _initialBias;
  while (h < cps.length) {
    var m = 0x7fffffff;
    for (final c in cps) {
      if (c >= n && c < m) m = c;
    }
    delta += (m - n) * (h + 1);
    n = m;
    for (final c in cps) {
      if (c < n) delta++;
      if (c == n) {
        var q = delta;
        for (var k = _base;; k += _base) {
          final t = k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);
          if (q < t) break;
          out.write(_digit(t + (q - t) % (_base - t)));
          q = (q - t) ~/ (_base - t);
        }
        out.write(_digit(q));
        bias = _adapt(delta, h + 1, h == basic);
        delta = 0;
        h++;
      }
    }
    delta++;
    n++;
  }
  return out.toString();
}

String? _punycodeDecode(String input) {
  final b = input.lastIndexOf('-');
  final output = <int>[];
  for (var j = 0; j < (b < 0 ? 0 : b); j++) {
    final c = input.codeUnitAt(j);
    if (c >= 0x80) return null;
    output.add(c);
  }
  var n = _initialN, i = 0, bias = _initialBias;
  var idx = b < 0 ? 0 : b + 1;
  while (idx < input.length) {
    final oldi = i;
    var w = 1;
    for (var k = _base;; k += _base) {
      if (idx >= input.length) return null;
      final c = input.codeUnitAt(idx++);
      final digit = c >= 0x30 && c <= 0x39
          ? c - 22
          : c >= 0x61 && c <= 0x7a
              ? c - 0x61
              : c >= 0x41 && c <= 0x5a
                  ? c - 0x41
                  : -1;
      if (digit < 0) return null;
      i += digit * w;
      final t = k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);
      if (digit < t) break;
      w *= _base - t;
    }
    bias = _adapt(i - oldi, output.length + 1, oldi == 0);
    n += i ~/ (output.length + 1);
    i %= output.length + 1;
    if (n > 0x10ffff) return null;
    output.insert(i, n);
    i++;
  }
  return String.fromCharCodes(output);
}

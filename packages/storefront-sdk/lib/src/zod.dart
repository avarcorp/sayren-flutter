// zod 대응 스키마 — Node SDK의 zod 스키마와 같은 규칙으로 입력을 검증하고 출력을 만든다.
// 공개 이름은 ZodError·ZodIssue·SafeParseResult와 각 스키마 상수의 parse·safeParse·options·shape다.

/// 객체에 키가 없음(JS `undefined`). 객체 출력에서 이 값이면 키를 싣지 않는다.
const Object absent = _Absent();

final class _Absent {
  const _Absent();
}

/// 검증 실패 한 건입니다. [ZodError.issues]에 담깁니다.
class ZodIssue {
  /// 이슈를 만듭니다.
  const ZodIssue({required this.code, required this.path, required this.message});

  /// 이슈 코드입니다. zod와 같은 값을 사용합니다.
  ///
  /// `invalid_type`(타입 불일치·필수 값 없음), `invalid_value`(허용하지 않는 값), `invalid_format`(주소 형식 등),
  /// `too_small`·`too_big`(범위 밖), `custom`(그 밖의 규칙)입니다.
  final String code;

  /// 문제가 된 값의 위치입니다. 객체 키는 문자열, 배열 위치는 정수입니다. 예: `['loginMethods', 0]`
  final List<Object> path;

  /// 사람이 읽는 설명입니다.
  final String message;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson() => {'code': code, 'path': path, 'message': message};
}

/// 값이 스키마에 맞지 않을 때 던지는 예외입니다.
///
/// 두 경우에 던집니다.
/// - 요청 본문이 계약에 맞지 않을 때. 요청을 보내기 전에 던지므로 서버에는 아무것도 바뀌지 않습니다.
/// - 서버 응답이 계약에 맞지 않을 때. SDK 버전이 서버보다 오래됐을 수 있습니다.
class ZodError implements Exception {
  /// 예외를 만듭니다.
  const ZodError(this.issues);

  /// 실패한 항목입니다. 한 번에 여러 건을 담습니다.
  final List<ZodIssue> issues;

  /// 모든 이슈를 `경로: 설명` 줄로 이은 문장입니다.
  String get message => issues.map((i) => '${i.path.join('.')}: ${i.message}').join('\n');

  @override
  String toString() => 'ZodError: $message';
}

/// [ZodType.safeParse]의 결과입니다. 예외를 던지지 않고 성공 여부를 담습니다.
class SafeParseResult<T> {
  const SafeParseResult._(this.success, this.data, this.error);

  /// 검증에 성공했는지입니다.
  final bool success;

  /// 검증한 값입니다. 실패하면 null입니다.
  final T? data;

  /// 실패 내용입니다. 성공하면 null입니다.
  final ZodError? error;
}

/// 스키마 하나. `run`은 출력 값을 돌려주고, 실패는 `issues`에 쌓는다.
abstract class ZodType<T> {
  /// 스키마를 만듭니다.
  const ZodType();

  /// [input]을 검증해 출력 값을 돌려줍니다. 실패는 [issues]에 쌓고, [path]는 현재 값의 위치입니다.
  ///
  /// SDK 내부용입니다. 검증은 [parse]·[safeParse]를 사용하십시오.
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues);

  /// [input]을 검증하고 출력 값을 돌려줍니다. 맞지 않으면 [ZodError]를 던집니다.
  ///
  /// 선언하지 않은 키는 버리고, 없는 키에 기본값이 있으면 채웁니다.
  T parse(Object? input) {
    final issues = <ZodIssue>[];
    final value = run(input, const [], issues);
    if (issues.isNotEmpty) throw ZodError(List.unmodifiable(issues));
    return value as T;
  }

  /// [parse]와 같지만 예외 대신 [SafeParseResult]를 돌려줍니다.
  SafeParseResult<T> safeParse(Object? input) {
    try {
      return SafeParseResult._(true, parse(input), null);
    } on ZodError catch (error) {
      return SafeParseResult._(false, null, error);
    }
  }

  /// null도 허용하는 스키마를 돌려줍니다(zod `.nullable()`).
  ZodType<T?> nullable() => _Nullable<T>(this);

  /// 키가 없어도 되는 스키마를 돌려줍니다(zod `.optional()`).
  ZodType<T?> optional() => _Optional<T>(this);

  /// zod `.default(value)` — 키가 없으면 검증 없이 `value`다
  ZodType<T> withDefault(T value) => _Default<T>(this, value);

  /// zod `.catch(value)` — 검증에 실패하면 이슈 없이 `value`다(`absent`면 키를 싣지 않는다)
  ZodType<T?> catchValue(Object? value) => _Catch<T>(this, value);
}

void _typeIssue(List<Object> path, List<ZodIssue> issues, String expected, Object? input) {
  issues.add(ZodIssue(
    code: 'invalid_type',
    path: List.unmodifiable(path),
    message: 'Invalid input: expected $expected, received ${input == absent ? 'undefined' : _typeName(input)}',
  ));
}

String _typeName(Object? v) => switch (v) {
      null => 'null',
      String() => 'string',
      num() => 'number',
      bool() => 'boolean',
      List() => 'array',
      Map() => 'object',
      _ => v.runtimeType.toString(),
    };

/// 문자열 스키마입니다(zod `z.string()`).
class ZodString extends ZodType<String> {
  /// 문자열 스키마를 만듭니다.
  const ZodString({this.isUrl = false});

  /// 주소 형식을 검사하는지입니다.
  final bool isUrl;

  /// 주소 형식을 검사하는 스키마를 돌려줍니다(zod `z.url()`).
  ZodString url() => const ZodString(isUrl: true);

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! String) {
      _typeIssue(path, issues, 'string', input);
      return null;
    }
    if (isUrl && !_isUrl(input)) {
      issues.add(ZodIssue(code: 'invalid_format', path: List.unmodifiable(path), message: 'Invalid URL'));
    }
    return input;
  }

  /// zod v4 `z.url()` — WHATWG URL로 읽히고 호스트가 있어야 한다
  static bool _isUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

/// 숫자 스키마입니다(zod `z.number()`).
class ZodNumber extends ZodType<num> {
  /// 숫자 스키마를 만듭니다.
  const ZodNumber({this.isInt = false, this.min, this.max});

  /// 정수만 허용하는지입니다.
  final bool isInt;

  /// 허용하는 최솟값입니다.
  final num? min;

  /// 허용하는 최댓값입니다.
  final num? max;

  /// 정수만 허용하는 스키마를 돌려줍니다(zod `.int()`).
  ZodNumber int_() => ZodNumber(isInt: true, min: min, max: max);

  /// 최솟값을 정한 스키마를 돌려줍니다(zod `.min()`).
  ZodNumber gte(num value) => ZodNumber(isInt: isInt, min: value, max: max);

  /// 최댓값을 정한 스키마를 돌려줍니다(zod `.max()`).
  ZodNumber lte(num value) => ZodNumber(isInt: isInt, min: min, max: value);

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! num || input.isNaN || input.isInfinite) {
      _typeIssue(path, issues, isInt ? 'int' : 'number', input);
      return null;
    }
    if (isInt && input != input.truncate()) {
      _typeIssue(path, issues, 'int', input);
      return null;
    }
    if (min != null && input < min!) {
      issues.add(ZodIssue(
          code: 'too_small', path: List.unmodifiable(path), message: 'Too small: expected number to be >=$min'));
    }
    if (max != null && input > max!) {
      issues.add(
          ZodIssue(code: 'too_big', path: List.unmodifiable(path), message: 'Too big: expected number to be <=$max'));
    }
    return isInt ? input.toInt() : input;
  }
}

/// 불리언 스키마입니다(zod `z.boolean()`).
class ZodBoolean extends ZodType<bool> {
  /// 불리언 스키마를 만듭니다.
  const ZodBoolean();

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! bool) _typeIssue(path, issues, 'boolean', input);
    return input;
  }
}

/// 어떤 값이든 그대로 받는 스키마입니다(zod `z.unknown()`).
class ZodUnknown extends ZodType<Object?> {
  /// 스키마를 만듭니다.
  const ZodUnknown();

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) => input == absent ? absent : input;
}

/// zod `z.enum([...])` — 값은 문자열 그대로다(ROADMAP 「타입」)
class ZodEnum extends ZodType<String> {
  /// 허용 값 목록으로 스키마를 만듭니다.
  const ZodEnum(this.options);

  /// 허용하는 값 목록입니다. 선택 메뉴를 그릴 때 사용합니다.
  final List<String> options;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! String || !options.contains(input)) {
      issues.add(ZodIssue(
        code: 'invalid_value',
        path: List.unmodifiable(path),
        message: 'Invalid option: expected one of ${options.map((o) => '"$o"').join('|')}',
      ));
    }
    return input;
  }
}

/// 한 값만 허용하는 스키마입니다(zod `z.literal()`).
class ZodLiteral<T> extends ZodType<T> {
  /// 허용할 값으로 스키마를 만듭니다.
  const ZodLiteral(this.value);

  /// 허용하는 값입니다.
  final T value;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input != value) {
      issues.add(
          ZodIssue(code: 'invalid_value', path: List.unmodifiable(path), message: 'Invalid input: expected $value'));
    }
    return input;
  }
}

/// 배열 스키마입니다(zod `z.array()`).
class ZodArray<T> extends ZodType<List<T>> {
  /// 항목 스키마로 배열 스키마를 만듭니다.
  const ZodArray(this.element);

  /// 항목 스키마입니다.
  final ZodType<T> element;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! List) {
      _typeIssue(path, issues, 'array', input);
      return null;
    }
    final before = issues.length;
    final out = [
      for (var i = 0; i < input.length; i++) element.run(input[i], [...path, i], issues)
    ];
    return issues.length > before ? null : List<T>.unmodifiable(out.cast<T>());
  }
}

/// 문자열 키 객체를 그대로 받는 스키마입니다(zod `z.record(z.string(), z.unknown())`).
class ZodRecord extends ZodType<Map<String, Object?>> {
  /// 스키마를 만듭니다.
  const ZodRecord();

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! Map) {
      _typeIssue(path, issues, 'record', input);
      return null;
    }
    return Map<String, Object?>.unmodifiable(input.cast<String, Object?>());
  }
}

/// zod `z.object(shape)` — 선언한 키만 남기고(모르는 키는 버린다) `create`로 모델을 만든다
class ZodObject<T> extends ZodType<T> {
  /// 필드 스키마와 모델 생성 함수로 객체 스키마를 만듭니다.
  const ZodObject(this.shape, this.create, {this.refinements = const []});

  /// 필드 이름별 스키마입니다.
  final Map<String, ZodType<Object?>> shape;

  /// 검증을 마친 JSON으로 모델을 만드는 함수입니다.
  final T Function(Map<String, Object?> json) create;

  /// 객체 전체에 거는 추가 규칙입니다.
  final List<({bool Function(Map<String, Object?> value) check, String message})> refinements;

  /// 필드를 더한 객체 스키마를 돌려줍니다(zod `.extend()`).
  ZodObject<R> extend<R>(Map<String, ZodType<Object?>> more, R Function(Map<String, Object?> json) create) =>
      ZodObject<R>({...shape, ...more}, create);

  /// 객체 전체 규칙을 더한 스키마를 돌려줍니다(zod `.refine()`). 규칙이 false면 `custom` 이슈입니다.
  ZodObject<T> refine(bool Function(Map<String, Object?> value) check, {required String message}) =>
      ZodObject<T>(shape, create, refinements: [...refinements, (check: check, message: message)]);

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is ParsedObject) input = input.toJson();
    if (input is! Map) {
      _typeIssue(path, issues, 'object', input);
      return null;
    }
    final before = issues.length;
    final out = <String, Object?>{};
    shape.forEach((key, schema) {
      final value = schema.run(input is Map && input.containsKey(key) ? input[key] : absent, [...path, key], issues);
      if (value != absent) out[key] = value;
    });
    if (issues.length > before) return null;
    for (final r in refinements) {
      if (!r.check(out)) issues.add(ZodIssue(code: 'custom', path: List.unmodifiable(path), message: r.message));
    }
    return issues.length > before ? null : create(Map.unmodifiable(out));
  }
}

/// 재귀 구조를 위해 스키마를 늦게 읽는 스키마입니다(zod `z.lazy()`).
class ZodLazy<T> extends ZodType<T> {
  /// 스키마를 돌려주는 함수로 만듭니다.
  const ZodLazy(this.getter);

  /// 스키마를 돌려주는 함수입니다.
  final ZodType<T> Function() getter;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) => getter().run(input, path, issues);
}

class _Nullable<T> extends ZodType<T?> {
  const _Nullable(this.inner);

  final ZodType<T> inner;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == null ? null : inner.run(input, path, issues);
}

class _Optional<T> extends ZodType<T?> {
  const _Optional(this.inner);

  final ZodType<T> inner;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == absent ? absent : inner.run(input, path, issues);
}

class _Default<T> extends ZodType<T> {
  const _Default(this.inner, this.value);

  final ZodType<Object?> inner;
  final T value;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == absent ? value : inner.run(input, path, issues);
}

class _Catch<T> extends ZodType<T?> {
  const _Catch(this.inner, this.value);

  final ZodType<Object?> inner;
  final Object? value;

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    final local = <ZodIssue>[];
    final out = inner.run(input, path, local);
    return local.isEmpty ? out : value;
  }
}

/// zod 생성자 모음 — 스키마 파일이 Node 소스와 같은 모양으로 읽히게 한다
abstract final class z {
  /// zod `z.string()`입니다.
  static ZodString string() => const ZodString();

  /// zod `z.url()`입니다.
  static ZodString url() => const ZodString(isUrl: true);

  /// zod `z.number()`입니다.
  static ZodNumber number() => const ZodNumber();

  /// zod `z.boolean()`입니다.
  static ZodBoolean boolean() => const ZodBoolean();

  /// zod `z.unknown()`입니다.
  static ZodUnknown unknown() => const ZodUnknown();

  /// zod `z.enum()`입니다.
  static ZodEnum enum_(List<String> options) => ZodEnum(options);

  /// zod `z.literal()`입니다.
  static ZodLiteral<T> literal<T>(T value) => ZodLiteral<T>(value);

  /// zod `z.array()`입니다.
  static ZodArray<T> array<T>(ZodType<T> element) => ZodArray<T>(element);

  /// zod `z.record(z.string(), z.unknown())`입니다.
  static ZodRecord record() => const ZodRecord();

  /// zod `z.object()`입니다. 출력은 `create`로 만든 모델입니다.
  static ZodObject<T> object<T>(Map<String, ZodType<Object?>> shape, T Function(Map<String, Object?> json) create) =>
      ZodObject<T>(shape, create);

  /// zod `z.object()`입니다. 출력은 JSON 맵 그대로입니다.
  static ZodObject<Map<String, Object?>> plainObject(Map<String, ZodType<Object?>> shape) =>
      ZodObject<Map<String, Object?>>(shape, (json) => json);

  /// zod `z.lazy()`입니다.
  static ZodLazy<T> lazy<T>(ZodType<T> Function() getter) => ZodLazy<T>(getter);
}

/// 객체 스키마의 출력 모델의 기반 클래스입니다(SDK 내부용, export하지 않는다).
///
/// 검증을 마친 JSON을 비공개로 들고, 모델 클래스는 [jsonOf]로 읽어 필드 getter를 둔다.
/// 키가 있고 없음이 Node 결과와 같게 유지된다(없는 선택 필드는 `toJson`에도 없다).
abstract class ParsedObject {
  /// JSON으로 만든다. 검증하지 않는다.
  ParsedObject(Map<String, Object?> json) : _json = Map.unmodifiable(json);

  final Map<String, Object?> _json;

  /// JSON으로 바꿉니다. 중첩 모델도 JSON으로 바꿉니다.
  Map<String, Object?> toJson() => {for (final e in _json.entries) e.key: _encode(e.value)};

  static Object? _encode(Object? value) => switch (value) {
        ParsedObject() => value.toJson(),
        Nullable() => _encode(value.value),
        List() => [for (final v in value) _encode(v)],
        Map() => {for (final e in value.entries) e.key as String: _encode(e.value)},
        _ => value,
      };

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && other is ParsedObject && _deepEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(_json.keys);

  @override
  String toString() => '$runtimeType${toJson()}';
}

/// 모델 getter가 읽는 JSON이다(SDK 내부용).
Map<String, Object?> jsonOf(ParsedObject object) => object._json;

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _deepEquals(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// 요청 본문에서 생략과 null을 구분하는 값입니다.
///
/// nullable이면서 선택인 요청 필드(예: 「null을 주면 지운다」)에 사용합니다.
///
/// - 인자를 생략하면 그 필드를 보내지 않습니다(그대로 둡니다).
/// - `Nullable(null)`이면 null을 보냅니다(지웁니다).
/// - `Nullable('02-000-0000')`이면 그 값을 보냅니다(바꿉니다).
final class Nullable<T> {
  /// [value]를 보낼 값으로 만듭니다. null이면 null을 보냅니다.
  const Nullable(this.value);

  /// 보낼 값입니다.
  final T? value;
}

/// 선택 필드를 JSON에 담는다 — null이면 키를 싣지 않고(JS `undefined`와 같다), [Nullable]이면 그 값을 싣는다
Map<String, Object?> compact(Map<String, Object?> fields) => {
      for (final e in fields.entries)
        if (e.value is Nullable) e.key: (e.value as Nullable).value else if (e.value != null) e.key: e.value,
    };

// zod 대응 스키마 — Node SDK의 zod 스키마와 같은 규칙으로 입력을 검증하고 출력을 만든다.
// 공개 이름은 ZodError·ZodIssue·SafeParseResult와 각 스키마 상수의 parse·safeParse·options·shape다.

/// 객체에 키가 없음(JS `undefined`). 객체 출력에서 이 값이면 키를 싣지 않는다.
const Object absent = _Absent();

final class _Absent {
  const _Absent();
}

class ZodIssue {
  const ZodIssue({required this.code, required this.path, required this.message});

  /// zod v4 이슈 코드 — `invalid_type`·`invalid_value`·`invalid_format`·`too_small`·`too_big`·`custom`
  final String code;
  final List<Object> path;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'path': path, 'message': message};
}

class ZodError implements Exception {
  const ZodError(this.issues);

  final List<ZodIssue> issues;

  String get message => issues.map((i) => '${i.path.join('.')}: ${i.message}').join('\n');

  @override
  String toString() => 'ZodError: $message';
}

class SafeParseResult<T> {
  const SafeParseResult._(this.success, this.data, this.error);

  final bool success;
  final T? data;
  final ZodError? error;
}

/// 스키마 하나. `run`은 출력 값을 돌려주고, 실패는 `issues`에 쌓는다.
abstract class ZodType<T> {
  const ZodType();

  Object? run(Object? input, List<Object> path, List<ZodIssue> issues);

  T parse(Object? input) {
    final issues = <ZodIssue>[];
    final value = run(input, const [], issues);
    if (issues.isNotEmpty) throw ZodError(List.unmodifiable(issues));
    return value as T;
  }

  SafeParseResult<T> safeParse(Object? input) {
    try {
      return SafeParseResult._(true, parse(input), null);
    } on ZodError catch (error) {
      return SafeParseResult._(false, null, error);
    }
  }

  ZodType<T?> nullable() => _Nullable<T>(this);
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

class ZodString extends ZodType<String> {
  const ZodString({this.isUrl = false});

  final bool isUrl;

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

class ZodNumber extends ZodType<num> {
  const ZodNumber({this.isInt = false, this.min, this.max});

  final bool isInt;
  final num? min;
  final num? max;

  ZodNumber int_() => ZodNumber(isInt: true, min: min, max: max);
  ZodNumber gte(num value) => ZodNumber(isInt: isInt, min: value, max: max);
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

class ZodBoolean extends ZodType<bool> {
  const ZodBoolean();

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! bool) _typeIssue(path, issues, 'boolean', input);
    return input;
  }
}

class ZodUnknown extends ZodType<Object?> {
  const ZodUnknown();

  @override
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) => input == absent ? absent : input;
}

/// zod `z.enum([...])` — 값은 문자열 그대로다(ROADMAP 「타입」)
class ZodEnum extends ZodType<String> {
  const ZodEnum(this.options);

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

class ZodLiteral<T> extends ZodType<T> {
  const ZodLiteral(this.value);

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

class ZodArray<T> extends ZodType<List<T>> {
  const ZodArray(this.element);

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

class ZodRecord extends ZodType<Map<String, Object?>> {
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
  const ZodObject(this.shape, this.create, {this.refinements = const []});

  final Map<String, ZodType<Object?>> shape;
  final T Function(Map<String, Object?> json) create;
  final List<({bool Function(Map<String, Object?> value) check, String message})> refinements;

  ZodObject<R> extend<R>(Map<String, ZodType<Object?>> more, R Function(Map<String, Object?> json) create) =>
      ZodObject<R>({...shape, ...more}, create);

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

class ZodLazy<T> extends ZodType<T> {
  const ZodLazy(this.getter);

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
  static ZodString string() => const ZodString();
  static ZodString url() => const ZodString(isUrl: true);
  static ZodNumber number() => const ZodNumber();
  static ZodBoolean boolean() => const ZodBoolean();
  static ZodUnknown unknown() => const ZodUnknown();
  static ZodEnum enum_(List<String> options) => ZodEnum(options);
  static ZodLiteral<T> literal<T>(T value) => ZodLiteral<T>(value);
  static ZodArray<T> array<T>(ZodType<T> element) => ZodArray<T>(element);
  static ZodRecord record() => const ZodRecord();
  static ZodObject<T> object<T>(Map<String, ZodType<Object?>> shape, T Function(Map<String, Object?> json) create) =>
      ZodObject<T>(shape, create);
  static ZodObject<Map<String, Object?>> plainObject(Map<String, ZodType<Object?>> shape) =>
      ZodObject<Map<String, Object?>>(shape, (json) => json);
  static ZodLazy<T> lazy<T>(ZodType<T> Function() getter) => ZodLazy<T>(getter);
}

/// 객체 스키마의 출력 — 검증을 지난 JSON을 그대로 들고, 모델 클래스가 필드 getter를 둔다.
/// 키가 있고 없음이 Node 결과와 같게 유지된다(없는 선택 필드는 `toJson`에도 없다).
abstract class ParsedObject {
  ParsedObject.fromJson(Map<String, Object?> json) : json = Map.unmodifiable(json);

  final Map<String, Object?> json;

  Map<String, Object?> toJson() => {for (final e in json.entries) e.key: _encode(e.value)};

  static Object? _encode(Object? value) => switch (value) {
        ParsedObject() => value.toJson(),
        List() => [for (final v in value) _encode(v)],
        Map() => {for (final e in value.entries) e.key as String: _encode(e.value)},
        _ => value,
      };

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && other is ParsedObject && _deepEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(json.keys);

  @override
  String toString() => '$runtimeType${toJson()}';
}

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

/// 선택 필드를 JSON에 담는다 — null이면 키를 싣지 않는다(JS에서 `undefined`를 넘긴 것과 같다)
Map<String, Object?> compact(Map<String, Object?> fields) => {
      for (final e in fields.entries)
        if (e.value != null) e.key: e.value
    };

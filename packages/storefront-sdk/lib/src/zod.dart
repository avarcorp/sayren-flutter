// zod 대응 스키마 — Node SDK의 zod(v4) 스키마와 같은 규칙으로 입력을 검증하고 출력을 만든다.
// 공개 이름은 ZodError·ZodIssue·SafeParseResult·Nullable과 스키마 타입(ZodType·ZodObject·ZodEnum·ZodArray)이다.

import 'dart:math' as math;

/// 객체에 키가 없음(JS `undefined`). 객체 출력에서 이 값이면 키를 싣지 않는다.
const Object absent = _Absent();

final class _Absent {
  const _Absent();
}

/// 검증 실패 한 건입니다. [ZodError.issues]에 담깁니다.
class ZodIssue {
  /// 이슈를 만듭니다.
  const ZodIssue({required this.code, required this.path, required this.message, this.continuable = false});

  /// 이슈 코드입니다. zod와 같은 값을 사용합니다.
  ///
  /// `invalid_type`(타입 불일치·필수 값 없음), `invalid_value`(허용하지 않는 값), `invalid_format`(형식 불일치),
  /// `invalid_union`(어느 형태에도 맞지 않음), `too_small`·`too_big`(범위 밖), `custom`(그 밖의 규칙)입니다.
  final String code;

  /// 문제가 된 값의 위치입니다. 객체 키는 문자열, 배열 위치는 정수입니다. 예: `['loginMethods', 0]`
  final List<Object> path;

  /// 사람이 읽는 설명입니다.
  final String message;

  /// 이 이슈가 난 뒤에도 같은 값의 다른 검사를 이어 하는지입니다(zod `continue`). SDK 내부용입니다.
  final bool continuable;

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

/// 사용자 검사([ZodType.check])가 이슈를 더하는 자리입니다(zod `superRefine`의 `ctx`).
class ZodCheckContext {
  ZodCheckContext._(this._path, this._issues);

  final List<Object> _path;
  final List<ZodIssue> _issues;

  /// `custom` 이슈를 더합니다. [path]는 검사하는 값 기준의 상대 경로입니다.
  void addIssue(String message, {List<Object> path = const []}) => _issues
      .add(ZodIssue(code: 'custom', path: List.unmodifiable([..._path, ...path]), message: message, continuable: true));
}

/// 값 하나에 거는 검사입니다. 값을 바꿔 돌려줄 수 있습니다(zod `overwrite`). SDK 내부용입니다.
typedef ZodCheckFn = Object? Function(Object? value, List<Object> path, List<ZodIssue> issues);

bool _aborted(List<ZodIssue> issues, int from) {
  for (var i = from; i < issues.length; i++) {
    if (!issues[i].continuable) return true;
  }
  return false;
}

ZodIssue _issue(String code, List<Object> path, String message, {bool continuable = false}) =>
    ZodIssue(code: code, path: List.unmodifiable(path), message: message, continuable: continuable);

/// 스키마 하나입니다. 같은 이름의 Node SDK zod 스키마와 같은 규칙으로 검증합니다.
abstract class ZodType<T> {
  /// 스키마를 만듭니다.
  const ZodType([this.checks = const []]);

  /// 타입 검사를 지난 값에 차례로 거는 검사입니다. SDK 내부용입니다.
  final List<ZodCheckFn> checks;

  /// 타입을 검사해 출력 값을 돌려줍니다. 실패는 [issues]에 쌓습니다. SDK 내부용입니다.
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues);

  /// 검사를 더한 같은 종류의 스키마를 돌려줍니다. SDK 내부용입니다.
  ZodType<T> withChecks(List<ZodCheckFn> checks);

  /// [input]을 검증해 출력 값을 돌려줍니다. 실패는 [issues]에 쌓고, [path]는 현재 값의 위치입니다.
  ///
  /// SDK 내부용입니다. 검증은 [parse]·[safeParse]를 사용하십시오.
  Object? run(Object? input, List<Object> path, List<ZodIssue> issues) {
    final from = issues.length;
    var value = parseType(input, path, issues);
    if (checks.isEmpty || _aborted(issues, from)) return value;
    for (final check in checks) {
      value = check(value, path, issues);
    }
    return value;
  }

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

  /// zod `.refine(predicate, message)` — [predicate]가 false면 `custom` 이슈다
  ZodType<T> refine(bool Function(T value) predicate,
          {String message = 'Invalid input', List<Object> path = const []}) =>
      withChecks([
        ...checks,
        (value, at, issues) {
          if (!predicate(value as T)) issues.add(_issue('custom', [...at, ...path], message, continuable: true));
          return value;
        },
      ]);

  /// zod `.superRefine((value, ctx) => …)` — [check]가 [ZodCheckContext.addIssue]로 이슈를 더한다
  ZodType<T> check(void Function(T value, ZodCheckContext ctx) check) => withChecks([
        ...checks,
        (value, at, issues) {
          check(value as T, ZodCheckContext._(at, issues));
          return value;
        },
      ]);
}

/// 문자열 스키마입니다(zod `z.string()`).
class ZodString extends ZodType<String> {
  /// 문자열 스키마를 만듭니다.
  const ZodString([super.checks]);

  @override
  ZodString withChecks(List<ZodCheckFn> checks) => ZodString(checks);

  ZodString _add(ZodCheckFn check) => ZodString([...checks, check]);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is String) return input;
    issues.add(_issue('invalid_type', path, 'Invalid input: expected string, received ${_typeName(input)}'));
    return null;
  }

  /// 최소 길이입니다(zod `.min()`).
  ZodString min(int length) => _add((v, p, i) {
        if ((v as String).length < length) {
          i.add(_issue('too_small', p, 'Too small: expected string to have >=$length characters', continuable: true));
        }
        return v;
      });

  /// 최대 길이입니다(zod `.max()`).
  ZodString max(int length) => _add((v, p, i) {
        if ((v as String).length > length) {
          i.add(_issue('too_big', p, 'Too big: expected string to have <=$length characters', continuable: true));
        }
        return v;
      });

  /// 정규식 형식입니다(zod `.regex()`·`z.email()`·`z.iso.datetime()`). [format]은 이슈의 형식 이름입니다.
  ZodString pattern(RegExp regex, {String format = 'regex', String? message}) => _add((v, p, i) {
        if (!regex.hasMatch(v as String)) {
          i.add(_issue('invalid_format', p, message ?? 'Invalid $format', continuable: true));
        }
        return v;
      });

  /// 주소 형식입니다(zod `z.url()`). WHATWG `URL`로 읽히는 절대 주소여야 합니다.
  ZodString url() => _add((v, p, i) {
        if (!_isUrl(v as String)) i.add(_issue('invalid_format', p, 'Invalid URL', continuable: true));
        return v;
      });

  /// 앞뒤 공백을 지웁니다(zod `.trim()`).
  ZodString trim() => _add((v, p, i) => (v as String).trim());

  static const _specialSchemes = {'http', 'https', 'ws', 'wss', 'ftp'};

  static bool _isUrl(String value) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*:').hasMatch(value.trimLeft())) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return false;
    if (_specialSchemes.contains(uri.scheme.toLowerCase())) return uri.host.isNotEmpty;
    return true;
  }
}

/// 숫자 스키마입니다(zod `z.number()`).
class ZodNumber<T extends num> extends ZodType<T> {
  /// 숫자 스키마를 만듭니다.
  const ZodNumber([super.checks, this.isInt = false, this.coerce = false]);

  /// 정수만 허용하는지입니다. 출력이 `int`가 됩니다.
  final bool isInt;

  /// 검사 전에 JS `Number(value)`로 바꾸는지입니다(zod `z.coerce.number()`).
  final bool coerce;

  @override
  ZodNumber<T> withChecks(List<ZodCheckFn> checks) => ZodNumber<T>(checks, isInt, coerce);

  ZodNumber<T> _add(ZodCheckFn check) => ZodNumber<T>([...checks, check], isInt, coerce);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (coerce) input = _jsNumber(input);
    if (input is num && !input.isNaN && input.isFinite) return input;
    issues.add(_issue('invalid_type', path, 'Invalid input: expected number, received ${_typeName(input)}'));
    return null;
  }

  static const _maxSafe = 9007199254740991;

  /// 안전한 정수만 허용합니다(zod `.int()`).
  ZodNumber<int> int_() => ZodNumber<int>([
        ...checks,
        (v, p, i) {
          final n = v as num;
          if (n != n.truncate()) {
            i.add(_issue('invalid_type', p, 'Invalid input: expected int, received number', continuable: true));
            return n;
          }
          if (n > _maxSafe) i.add(_issue('too_big', p, 'Too big: expected int to be <=$_maxSafe', continuable: true));
          if (n < -_maxSafe)
            i.add(_issue('too_small', p, 'Too small: expected int to be >=-$_maxSafe', continuable: true));
          return n.toInt();
        },
      ], true, coerce);

  /// 최솟값입니다. [inclusive]가 false면 초과(zod `.gt()`), true면 이상(zod `.min()`)입니다.
  ZodNumber<T> greaterThan(num value, {required bool inclusive}) => _add((v, p, i) {
        final n = v as num;
        if (inclusive ? n < value : n <= value) {
          i.add(_issue('too_small', p, 'Too small: expected number to be ${inclusive ? '>=' : '>'}$value',
              continuable: true));
        }
        return n;
      });

  /// [divisor]의 배수만 허용합니다(zod `.multipleOf()`). 소수 오차는 zod와 같은 허용 범위로 무시합니다.
  ZodNumber<T> multipleOf(num divisor) => _add((v, p, i) {
        final n = v as num;
        final ratio = n / divisor;
        final rounded = (ratio + 0.5).floorToDouble(); // JS Math.round
        final tolerance = 4 * 2.220446049250313e-16 * math.max(ratio.abs(), 1);
        if (!((ratio - rounded).abs() < tolerance)) {
          i.add(_issue('not_multiple_of', p, 'Invalid number: must be a multiple of $divisor', continuable: true));
        }
        return n;
      });

  /// 최댓값입니다. [inclusive]가 false면 미만(zod `.lt()`), true면 이하(zod `.max()`)입니다.
  ZodNumber<T> lessThan(num value, {required bool inclusive}) => _add((v, p, i) {
        final n = v as num;
        if (inclusive ? n > value : n >= value) {
          i.add(_issue('too_big', p, 'Too big: expected number to be ${inclusive ? '<=' : '<'}$value',
              continuable: true));
        }
        return n;
      });
}

/// 불리언 스키마입니다(zod `z.boolean()`).
class ZodBoolean extends ZodType<bool> {
  /// 불리언 스키마를 만듭니다.
  const ZodBoolean([super.checks]);

  @override
  ZodBoolean withChecks(List<ZodCheckFn> checks) => ZodBoolean(checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is bool) return input;
    issues.add(_issue('invalid_type', path, 'Invalid input: expected boolean, received ${_typeName(input)}'));
    return null;
  }
}

/// null만 허용하는 스키마입니다(zod `z.null()`).
class ZodNull extends ZodType<Null> {
  /// 스키마를 만듭니다.
  const ZodNull([super.checks]);

  @override
  ZodNull withChecks(List<ZodCheckFn> checks) => ZodNull(checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input == null) return null;
    issues.add(_issue('invalid_type', path, 'Invalid input: expected null, received ${_typeName(input)}'));
    return null;
  }
}

/// 어떤 값이든 그대로 받는 스키마입니다(zod `z.unknown()`).
class ZodUnknown extends ZodType<Object?> {
  /// 스키마를 만듭니다.
  const ZodUnknown([super.checks]);

  @override
  ZodUnknown withChecks(List<ZodCheckFn> checks) => ZodUnknown(checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) => input;
}

/// 정해진 문자열 값만 허용하는 스키마입니다(zod `z.enum()`). 값은 문자열 그대로입니다.
class ZodEnum extends ZodType<String> {
  /// 허용 값 목록으로 스키마를 만듭니다.
  const ZodEnum(this.options, [super.checks]);

  /// 허용하는 값 목록입니다. 선택 메뉴를 그릴 때 사용합니다.
  final List<String> options;

  @override
  ZodEnum withChecks(List<ZodCheckFn> checks) => ZodEnum(options, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is String && options.contains(input)) return input;
    issues
        .add(_issue('invalid_value', path, 'Invalid option: expected one of ${options.map((o) => '"$o"').join('|')}'));
    return input;
  }
}

/// 정해진 값만 허용하는 스키마입니다(zod `z.literal()`).
class ZodLiteral<T> extends ZodType<T> {
  /// 허용할 값 목록으로 스키마를 만듭니다.
  const ZodLiteral(this.values, [super.checks]);

  /// 허용하는 값입니다.
  final List<Object?> values;

  @override
  ZodLiteral<T> withChecks(List<ZodCheckFn> checks) => ZodLiteral<T>(values, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (values.contains(input)) return input;
    issues.add(_issue('invalid_value', path, 'Invalid input: expected ${values.join('|')}'));
    return input;
  }
}

/// 배열 스키마입니다(zod `z.array()`).
class ZodArray<T> extends ZodType<List<T>> {
  /// 항목 스키마로 배열 스키마를 만듭니다.
  const ZodArray(this.element, [super.checks]);

  /// 항목 스키마입니다.
  final ZodType<T> element;

  @override
  ZodArray<T> withChecks(List<ZodCheckFn> checks) => ZodArray<T>(element, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! List) {
      issues.add(_issue('invalid_type', path, 'Invalid input: expected array, received ${_typeName(input)}'));
      return null;
    }
    final from = issues.length;
    final out = [
      for (var i = 0; i < input.length; i++) element.run(input[i], [...path, i], issues)
    ];
    return _aborted(issues, from) ? out : List<T>.unmodifiable(out.cast<T>());
  }

  /// 최소 항목 수입니다(zod `.min()`).
  ZodArray<T> min(int length) => ZodArray<T>(element, [
        ...checks,
        (v, p, i) {
          if ((v as List).length < length) {
            i.add(_issue('too_small', p, 'Too small: expected array to have >=$length items', continuable: true));
          }
          return v;
        },
      ]);

  /// 최대 항목 수입니다(zod `.max()`).
  ZodArray<T> max(int length) => ZodArray<T>(element, [
        ...checks,
        (v, p, i) {
          if ((v as List).length > length) {
            i.add(_issue('too_big', p, 'Too big: expected array to have <=$length items', continuable: true));
          }
          return v;
        },
      ]);
}

/// 문자열 키 객체 스키마입니다(zod `z.record(z.string(), value)`).
class ZodRecord<T> extends ZodType<Map<String, T>> {
  /// 값 스키마로 만듭니다.
  const ZodRecord(this.value, [super.checks]);

  /// 값 스키마입니다.
  final ZodType<T> value;

  @override
  ZodRecord<T> withChecks(List<ZodCheckFn> checks) => ZodRecord<T>(value, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is! Map) {
      issues.add(_issue('invalid_type', path, 'Invalid input: expected record, received ${_typeName(input)}'));
      return null;
    }
    final from = issues.length;
    final out = <String, Object?>{};
    for (final e in input.entries) {
      final v = value.run(e.value, [...path, e.key as String], issues);
      if (v != absent) out[e.key as String] = v;
    }
    // 값 타입으로 만들어 둔다 — 뒤의 검사(refine 등)가 출력 타입(Map<String, T>)으로 읽는다
    return _aborted(issues, from) ? out : Map<String, T>.unmodifiable(out.cast<String, T>());
  }
}

/// 객체 스키마입니다(zod `z.object()`). 선언한 키만 남기고(모르는 키는 버린다) 모델을 만듭니다.
class ZodObject<T> extends ZodType<T> {
  /// 필드 스키마와 모델 생성 함수로 객체 스키마를 만듭니다.
  const ZodObject(this.shape, this.create, {this.loose = false, List<ZodCheckFn> checks = const []}) : super(checks);

  /// 필드 이름별 스키마입니다.
  final Map<String, ZodType<Object?>> shape;

  /// 검증을 마친 JSON으로 모델을 만드는 함수입니다.
  final T Function(Map<String, Object?> json) create;

  /// 모르는 키도 남기는지입니다(zod `z.looseObject()`).
  final bool loose;

  @override
  ZodObject<T> withChecks(List<ZodCheckFn> checks) => ZodObject<T>(shape, create, loose: loose, checks: checks);

  /// 필드를 더한 객체 스키마를 돌려줍니다(zod `.extend()`).
  ZodObject<R> extend<R>(Map<String, ZodType<Object?>> more, R Function(Map<String, Object?> json) create) =>
      ZodObject<R>({...shape, ...more}, create, loose: loose);

  @override
  ZodObject<T> refine(bool Function(T value) predicate,
          {String message = 'Invalid input', List<Object> path = const []}) =>
      super.refine(predicate, message: message, path: path) as ZodObject<T>;

  @override
  ZodObject<T> check(void Function(T value, ZodCheckContext ctx) check) => super.check(check) as ZodObject<T>;

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    if (input is ParsedObject) input = input.toJson();
    if (input is! Map) {
      issues.add(_issue('invalid_type', path, 'Invalid input: expected object, received ${_typeName(input)}'));
      return null;
    }
    final from = issues.length;
    final out = <String, Object?>{};
    shape.forEach((key, schema) {
      final present = input is Map && input.containsKey(key);
      final before = issues.length;
      final value = schema.run(present ? input[key] : absent, [...path, key], issues);
      // zod v4는 선택이 아닌 키가 없으면, 없음을 받아 주는 스키마(unknown·unknown.nullable 등)여도 실패한다
      if (!present && value == absent && schema is! _Optional && schema is! _Catch && issues.length == before) {
        issues.add(_issue('invalid_type', [...path, key], 'Invalid input: expected nonoptional, received undefined'));
      }
      if (value != absent) out[key] = value;
    });
    if (loose) {
      for (final e in input.entries) {
        if (!shape.containsKey(e.key)) out[e.key as String] = e.value;
      }
    }
    // 이어서 해도 되는 이슈(형식 검사 등)만 있으면 zod처럼 값을 만들어 객체 검사(refine)를 이어 간다
    if (_aborted(issues, from)) return out;
    return create(Map.unmodifiable(out));
  }
}

/// 여러 형태 중 하나를 허용하는 스키마입니다(zod `z.union()`·`z.discriminatedUnion()`).
class ZodUnion<T> extends ZodType<T> {
  /// 형태 목록으로 만듭니다. [discriminator]가 있으면 그 필드 값으로 형태를 고릅니다.
  const ZodUnion(this.options, {this.discriminator, List<ZodCheckFn> checks = const []}) : super(checks);

  /// 허용하는 형태입니다.
  final List<ZodType<Object?>> options;

  /// 형태를 고르는 필드 이름입니다(zod `z.discriminatedUnion()`).
  final String? discriminator;

  @override
  ZodUnion<T> withChecks(List<ZodCheckFn> checks) => ZodUnion<T>(options, discriminator: discriminator, checks: checks);

  static List<Object?> _literalsOf(ZodType<Object?> schema, String key) {
    var s = schema;
    while (s is ZodLazy<Object?>) {
      s = s.getter();
    }
    final field = s is ZodObject ? s.shape[key] : null;
    return switch (field) {
      ZodLiteral() => field.values,
      ZodEnum() => field.options,
      _ => const [],
    };
  }

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    final key = discriminator;
    if (key != null) {
      if (input is ParsedObject) input = input.toJson();
      if (input is! Map) {
        issues.add(_issue('invalid_type', path, 'Invalid input: expected object, received ${_typeName(input)}'));
        return null;
      }
      for (final option in options) {
        if (_literalsOf(option, key).contains(input[key])) return option.run(input, path, issues);
      }
      issues.add(_issue('invalid_union', [...path, key], 'No matching discriminator'));
      return null;
    }
    final results = <(Object?, List<ZodIssue>)>[];
    for (final option in options) {
      final local = <ZodIssue>[];
      final value = option.run(input, path, local);
      if (local.isEmpty) return value;
      results.add((value, local));
    }
    final nonAborted = results.where((r) => !_aborted(r.$2, 0)).toList();
    if (nonAborted.length == 1) {
      issues.addAll(nonAborted.single.$2);
      return nonAborted.single.$1;
    }
    issues.add(_issue('invalid_union', path, 'Invalid input'));
    return null;
  }
}

/// 두 스키마를 모두 만족해야 하는 스키마입니다(zod `.and()`·`z.intersection()`).
///
/// 검증은 zod처럼 양쪽을 따로 하고, 출력은 양쪽 JSON을 합쳐 [merged]로 만든 모델입니다.
class ZodIntersection<T> extends ZodType<T> {
  /// 두 스키마와 합친 출력을 만드는 스키마로 만듭니다.
  const ZodIntersection(this.left, this.right, this.merged, [super.checks]);

  /// 왼쪽 스키마입니다.
  final ZodType<Object?> left;

  /// 오른쪽 스키마입니다.
  final ZodType<Object?> right;

  /// 양쪽 출력을 합친 JSON으로 모델을 만드는 스키마입니다.
  final ZodType<T> merged;

  @override
  ZodIntersection<T> withChecks(List<ZodCheckFn> checks) => ZodIntersection<T>(left, right, merged, checks);

  static Object? _json(Object? v) => v is ParsedObject ? v.toJson() : v;

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    final from = issues.length;
    final a = _json(left.run(input, path, issues));
    final b = _json(right.run(input, path, issues));
    if (_aborted(issues, from)) return null;
    if (a is Map && b is Map) return merged.run({...a, ...b}, path, issues);
    return a;
  }
}

/// 앞 스키마의 출력을 뒤 스키마로 다시 검증합니다(zod `.pipe()`·`z.preprocess()`).
class ZodPipe<T> extends ZodType<T> {
  /// 두 스키마로 만듭니다.
  const ZodPipe(this.input, this.output, [super.checks]);

  /// 먼저 거치는 스키마입니다.
  final ZodType<Object?> input;

  /// 나중에 거치는 스키마입니다.
  final ZodType<Object?> output;

  @override
  ZodPipe<T> withChecks(List<ZodCheckFn> checks) => ZodPipe<T>(input, output, checks);

  @override
  Object? parseType(Object? value, List<Object> path, List<ZodIssue> issues) {
    final from = issues.length;
    final mid = input.run(value, path, issues);
    if (issues.length > from) return mid;
    return output.run(mid, path, issues);
  }
}

/// 값을 함수로 바꾸는 스키마입니다(zod `z.transform()`).
class ZodTransform<T> extends ZodType<T> {
  /// 바꾸는 함수로 만듭니다.
  const ZodTransform(this.transform, [super.checks]) : _raw = null;

  const ZodTransform._raw(ZodCheckFn raw, [super.checks])
      : _raw = raw,
        transform = _never;

  static Object? _never(Object? value) => value;

  /// 값을 바꾸는 함수입니다.
  final Object? Function(Object? value) transform;

  /// 이슈를 더할 수 있는 변환(zod `ctx.addIssue`). 더한 이슈는 검증을 멈춘다
  final ZodCheckFn? _raw;

  @override
  ZodTransform<T> withChecks(List<ZodCheckFn> checks) =>
      _raw == null ? ZodTransform<T>(transform, checks) : ZodTransform<T>._raw(_raw, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) =>
      _raw == null ? transform(input) : _raw(input, path, issues);
}

/// 재귀 구조를 위해 스키마를 늦게 읽는 스키마입니다(zod `z.lazy()`).
class ZodLazy<T> extends ZodType<T> {
  /// 스키마를 돌려주는 함수로 만듭니다.
  const ZodLazy(this.getter, [super.checks]);

  /// 스키마를 돌려주는 함수입니다.
  final ZodType<T> Function() getter;

  @override
  ZodLazy<T> withChecks(List<ZodCheckFn> checks) => ZodLazy<T>(getter, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) => getter().run(input, path, issues);
}

class _Nullable<T> extends ZodType<T?> {
  const _Nullable(this.inner, [super.checks]);

  final ZodType<T> inner;

  @override
  _Nullable<T> withChecks(List<ZodCheckFn> checks) => _Nullable<T>(inner, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == null ? null : inner.run(input, path, issues);
}

class _Optional<T> extends ZodType<T?> {
  const _Optional(this.inner, [super.checks]);

  final ZodType<T> inner;

  @override
  _Optional<T> withChecks(List<ZodCheckFn> checks) => _Optional<T>(inner, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == absent ? absent : inner.run(input, path, issues);
}

class _Default<T> extends ZodType<T> {
  const _Default(this.inner, this.value, [super.checks]);

  final ZodType<Object?> inner;
  final T value;

  @override
  _Default<T> withChecks(List<ZodCheckFn> checks) => _Default<T>(inner, value, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) =>
      input == absent ? value : inner.run(input, path, issues);
}

class _Catch<T> extends ZodType<T?> {
  const _Catch(this.inner, this.value, [super.checks]);

  final ZodType<Object?> inner;
  final Object? value;

  @override
  _Catch<T> withChecks(List<ZodCheckFn> checks) => _Catch<T>(inner, value, checks);

  @override
  Object? parseType(Object? input, List<Object> path, List<ZodIssue> issues) {
    final local = <ZodIssue>[];
    final out = inner.run(input, path, local);
    return local.isEmpty ? out : value;
  }
}

String _typeName(Object? v) => switch (v) {
      _Absent() => 'undefined',
      null => 'null',
      String() => 'string',
      num() => 'number',
      bool() => 'boolean',
      List() => 'array',
      Map() => 'object',
      _ => v.runtimeType.toString(),
    };

/// zod 생성자 모음 — 생성한 스키마 코드가 Node 소스와 같은 모양으로 읽히게 한다(SDK 내부용)
abstract final class z {
  /// zod `z.string()`입니다.
  static ZodString string() => const ZodString();

  /// zod `z.number()`입니다.
  static ZodNumber<num> number({bool coerce = false}) => ZodNumber<num>(const [], false, coerce);

  /// zod `z.boolean()`입니다.
  static ZodBoolean boolean() => const ZodBoolean();

  /// zod `z.null()`입니다.
  static ZodNull null_() => const ZodNull();

  /// zod `z.unknown()`입니다.
  static ZodUnknown unknown() => const ZodUnknown();

  /// zod `z.enum()`입니다.
  static ZodEnum enum_(List<String> options) => ZodEnum(options);

  /// zod `z.literal()`입니다.
  static ZodLiteral<T> literal<T>(T value) => ZodLiteral<T>([value]);

  /// 여러 값의 zod `z.literal([...])`입니다.
  static ZodLiteral<T> literals<T>(List<T> values) => ZodLiteral<T>(values);

  /// zod `z.array()`입니다.
  static ZodArray<T> array<T>(ZodType<T> element) => ZodArray<T>(element);

  /// zod `z.record(z.string(), value)`입니다.
  static ZodRecord<T> record<T>(ZodType<T> value) => ZodRecord<T>(value);

  /// zod `z.object()`입니다. 출력은 `create`로 만든 모델입니다.
  static ZodObject<T> object<T>(Map<String, ZodType<Object?>> shape, T Function(Map<String, Object?> json) create,
          {bool loose = false}) =>
      ZodObject<T>(shape, create, loose: loose);

  /// zod `z.object()`입니다. 출력은 JSON 맵 그대로입니다.
  static ZodObject<Map<String, Object?>> plainObject(Map<String, ZodType<Object?>> shape, {bool loose = false}) =>
      ZodObject<Map<String, Object?>>(shape, (json) => json, loose: loose);

  /// zod `z.union()`입니다.
  static ZodUnion<T> union<T>(List<ZodType<Object?>> options) => ZodUnion<T>(options);

  /// zod `z.discriminatedUnion()`입니다.
  static ZodUnion<T> discriminatedUnion<T>(String discriminator, List<ZodType<Object?>> options) =>
      ZodUnion<T>(options, discriminator: discriminator);

  /// zod `.and()`입니다. [merged]는 합친 출력을 만드는 스키마입니다.
  static ZodIntersection<T> intersection<T>(ZodType<Object?> left, ZodType<Object?> right, ZodType<T> merged) =>
      ZodIntersection<T>(left, right, merged);

  /// zod `.pipe()`입니다.
  static ZodPipe<T> pipe<T>(ZodType<Object?> input, ZodType<Object?> output) => ZodPipe<T>(input, output);

  /// zod `z.transform()`입니다.
  static ZodTransform<T> transform<T>(Object? Function(Object? value) fn) => ZodTransform<T>(fn);

  /// 이슈를 더할 수 있는 zod `z.transform((value, ctx) => …)`입니다. [fn]은 `issues`에 이슈를 더하고 아무 값이나 돌려줍니다.
  static ZodTransform<T> transformWithIssues<T>(ZodCheckFn fn) => ZodTransform<T>._raw(fn);

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

/// JS 참·거짓 판정(`!!value`)이다(SDK 내부용) — null·false·0·빈 문자열이 거짓이다
bool truthy(Object? value) => !(value == null || value == false || value == 0 || value == '' || value == absent);

/// 모델이면 그 JSON, 맵이면 그 맵이다(SDK 내부용) — JS에서 객체를 맵처럼 읽는 검사(`Object.keys`·`in`)에 쓴다
Map<String, Object?> jsMap(Object? value) =>
    value is ParsedObject ? value._json : (value as Map).cast<String, Object?>();

/// JS `Object.keys(value).length`다(SDK 내부용)
int keyCount(Object? value) => jsMap(value).length;

/// JS `Date.parse(value)`다(SDK 내부용). 읽을 수 없으면 NaN이다
double jsDateParse(String value) => DateTime.tryParse(value)?.millisecondsSinceEpoch.toDouble() ?? double.nan;

/// JS `Number(value)`다 — 문자열은 앞뒤 공백을 지우고 읽고(빈 문자열은 0), 참거짓은 1·0, null은 0, 읽을 수 없으면 NaN이다
num _jsNumber(Object? value) {
  if (value is num) return value;
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is List)
    return value.isEmpty
        ? 0
        : (value.length == 1 ? _jsNumber(value.first is List ? value.first : '${value.first ?? ''}') : double.nan);
  if (value is! String) return double.nan;
  final t = value.trim();
  if (t.isEmpty) return 0;
  final radix = RegExp(r'^0([xob])([0-9a-f]+)$', caseSensitive: false).firstMatch(t);
  if (radix != null) {
    final base = switch (radix.group(1)!.toLowerCase()) { 'x' => 16, 'o' => 8, _ => 2 };
    return int.tryParse(radix.group(2)!, radix: base) ?? double.nan;
  }
  if (RegExp(r'^[+-]?Infinity$').hasMatch(t)) return t.startsWith('-') ? double.negativeInfinity : double.infinity;
  if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?$', caseSensitive: false).hasMatch(t)) return double.nan;
  return num.tryParse(t) ?? double.tryParse(t) ?? double.nan;
}

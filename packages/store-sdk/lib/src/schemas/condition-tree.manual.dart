// 손으로 쓴 부분 — condition-tree.ts의 그룹 모델·고정 단계 스키마와 검증·정규화·평가 함수.
part of 'condition-tree.dart';

/// 규칙 값입니다. JSON 스칼라(숫자·참거짓·문자열·null)나 스칼라 목록(`in` 목록, `between`의 `[from, to]`, 비운 끝은 null)입니다.
///
/// 공개 응답에 그대로 실리므로 직렬화되는 값만 둡니다.
typedef ConditionValue = Object?;

/// 조건 트리의 노드입니다. 규칙([ConditionRule])이나 그룹([ConditionGroup])입니다.
abstract interface class ConditionNode {
  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson();
}

/// 조건 그룹입니다. 규칙과 하위 그룹을 `and`(모두) 또는 `or`(하나 이상)로 묶습니다.
class ConditionGroup extends ParsedObject implements ConditionNode {
  /// [ConditionGroup]을 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.
  ConditionGroup({required String combinator, required List<ConditionNode> rules})
      : super({'combinator': combinator, 'rules': rules});

  ConditionGroup._(super.json);

  /// JSON을 [conditionGroupSchema]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  factory ConditionGroup.fromJson(Map<String, Object?> json) => conditionGroupSchema.parse(json);

  Map<String, Object?> get _j => jsonOf(this);

  /// 결합어입니다. `and`는 모두 참이어야, `or`는 하나 이상 참이어야 그룹이 참입니다.
  ConditionCombinator get combinator => _j['combinator'] as String;

  /// 규칙과 하위 그룹입니다. 비면 그룹은 참입니다.
  List<ConditionNode> get rules => (_j['rules'] as List).cast<ConditionNode>();
}

ZodObject<ConditionGroup> _groupOf(ZodType<ConditionNode> child) => z.object<ConditionGroup>({
      'combinator': z.enum_(['and', 'or']),
      'rules': z.array<ConditionNode>(child).max(100),
    }, ConditionGroup._, strict: true);

// 깊이 3 고정 단계다. 재귀(z.lazy)로 두면 깊이 중첩한 본문이 파싱 중에 스택을 넘는다
final ZodObject<ConditionGroup> _level3 = _groupOf(conditionRuleSchema);
final ZodObject<ConditionGroup> _level2 = _groupOf(z.union<ConditionNode>([conditionRuleSchema, _level3]));

/// [ConditionGroup] 스키마입니다.
///
/// 깊이 3(`DEFAULT_CONDITION_LIMITS.maxDepth`)까지만 받는 고정 단계 스키마입니다. 더 깊으면 형식 오류입니다.
final ZodType<ConditionGroup> conditionGroupSchema = _groupOf(z.union<ConditionNode>([conditionRuleSchema, _level2]));

/// 노드가 그룹인지입니다.
bool isConditionGroup(ConditionNode node) => node is ConditionGroup;

final _birthdateText = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 생일(`YYYY-MM-DD`, 연도를 모르면 `0000-MM-DD`)과 판정 날짜(쓰는 쪽 달력의 연·월·일)로 사실 값을 만듭니다. 읽지 못하면 null입니다.
BirthdateFact? birthdateFactOf(String? birthdate, ({int year, int month, int day}) today) {
  final match = birthdate == null || birthdate.isEmpty ? null : _birthdateText.firstMatch(birthdate);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  int? age;
  if (year > 0) {
    final beforeBirthday = today.month < month || (today.month == month && today.day < day);
    final value = today.year - year - (beforeBirthday ? 1 : 0);
    if (value >= 0) age = value;
  }
  return BirthdateFact(age: age, month: month, isCurrentMonth: month == today.month);
}

/// 나이 값 범위
const _ageMax = 150;

/// 필드 정의입니다. `Ctx`는 쓰는 쪽의 평가 컨텍스트입니다.
class ConditionFieldDef<Ctx> {
  /// [ConditionFieldDef]을 만듭니다.
  const ConditionFieldDef({
    required this.name,
    required this.type,
    this.operators,
    this.options,
    this.min,
    this.max,
    required this.resolve,
  });

  /// 필드 이름입니다(`customer.daysSinceJoined` 등).
  final String name;

  /// 값 형식입니다. 허용 값은 [ConditionValueType]을 참고하십시오.
  final ConditionValueType type;

  /// 허용 연산자입니다. 생략하면 값 형식의 연산자 전부입니다.
  final List<ConditionOperator>? operators;

  /// `enumSet`의 선택지입니다.
  final List<String>? options;

  /// `integer`의 하한(포함)입니다.
  final num? min;

  /// `integer`의 상한(포함)입니다.
  final num? max;

  /// 컨텍스트에서 사실 값을 읽습니다. 모르면 null(규칙은 거짓)입니다.
  final Object? Function(Ctx ctx) resolve;

  /// JSON으로 바꿉니다. [resolve]는 싣지 않습니다.
  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        if (operators != null) 'operators': operators,
        if (options != null) 'options': options,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };
}

/// 필드 이름 → 필드 정의입니다.
typedef ConditionCatalog<Ctx> = Map<String, ConditionFieldDef<Ctx>>;

/// 필드 정의 목록으로 카탈로그를 만듭니다.
ConditionCatalog<Ctx> conditionCatalog<Ctx>(List<ConditionFieldDef<Ctx>> fields) =>
    Map.unmodifiable({for (final field in fields) field.name: field});

final _defaultLimits = ConditionLimits(
  maxDepth: DEFAULT_CONDITION_LIMITS['maxDepth']!,
  maxRules: DEFAULT_CONDITION_LIMITS['maxRules']!,
  maxSetSize: DEFAULT_CONDITION_LIMITS['maxSetSize']!,
);

final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// JS `Number.isInteger(value)` + 범위
bool _isInteger(Object? value, {num? min, num? max}) =>
    value is num &&
    value.isFinite &&
    value == value.truncateToDouble() &&
    (min == null || value >= min) &&
    (max == null || value <= max);

bool _valueValid<Ctx>(ConditionFieldDef<Ctx> def, String operator, Object? value, ConditionLimits limits) {
  switch (def.type) {
    case 'integer':
      if (operator == 'between') {
        return value is List &&
            value.length == 2 &&
            _isInteger(value[0], min: def.min, max: def.max) &&
            _isInteger(value[1], min: def.min, max: def.max) &&
            (value[0] as num) <= (value[1] as num);
      }
      return _isInteger(value, min: def.min, max: def.max);
    case 'boolean':
      return value is bool;
    case 'idSet':
    case 'enumSet':
      return value is List &&
          value.isNotEmpty &&
          value.length <= limits.maxSetSize &&
          value.every((v) => v is String && v.isNotEmpty && v.length <= 200) &&
          (def.type == 'idSet' || value.every((v) => def.options?.contains(v) ?? false));
    case 'timeRange':
      return value is List &&
          value.length == 2 &&
          value.every((v) => v is String && _timePattern.hasMatch(v)) &&
          value[0] != value[1];
    case 'birthdate':
      if (operator == 'ageBetween') {
        return value is List &&
            value.length == 2 &&
            _isInteger(value[0], min: 0, max: _ageMax) &&
            _isInteger(value[1], min: 0, max: _ageMax) &&
            (value[0] as num) <= (value[1] as num);
      }
      if (operator == 'age>=' || operator == 'age<=') return _isInteger(value, min: 0, max: _ageMax);
      if (operator == 'birthMonthIn') {
        return value is List &&
            value.isNotEmpty &&
            value.length <= 12 &&
            value.every((v) => _isInteger(v, min: 1, max: 12));
      }
      return operator == 'birthMonthIsCurrent' && value == true;
  }
  return false;
}

/// 카탈로그로 트리를 검증합니다. 문제가 없으면 빈 목록입니다. [allowed]를 주면 그 필드만 쓸 수 있습니다(쓰는 자리별 제한).
///
/// zod `superRefine`에서 이 결과를 그대로 이슈로 옮깁니다. [limits]를 생략하면 `DEFAULT_CONDITION_LIMITS`입니다.
List<ConditionIssue> conditionIssues<Ctx>(
  ConditionGroup group,
  ConditionCatalog<Ctx> catalog, {
  bool Function(String field)? allowed,
  ConditionLimits? limits,
}) {
  final limit = limits ?? _defaultLimits;
  final issues = <ConditionIssue>[];
  var ruleCount = 0;
  void walk(ConditionGroup node, int depth, List<Object?> path) {
    if (depth > limit.maxDepth) {
      issues.add(ConditionIssue(path: path, code: 'DEPTH'));
      return;
    }
    final rules = node.rules;
    for (var index = 0; index < rules.length; index++) {
      final child = rules[index];
      final at = [...path, 'rules', index];
      if (child is ConditionGroup) {
        walk(child, depth + 1, at);
        continue;
      }
      final rule = child as ConditionRule;
      ruleCount += 1;
      final def = catalog[rule.field];
      if (def == null) {
        issues.add(ConditionIssue(path: [...at, 'field'], code: 'UNKNOWN_FIELD', field: rule.field));
        continue;
      }
      if (allowed != null && !allowed(rule.field)) {
        issues.add(ConditionIssue(path: [...at, 'field'], code: 'FIELD_NOT_ALLOWED', field: rule.field));
        continue;
      }
      final operators = def.operators ?? CONDITION_OPERATORS_BY_TYPE[def.type] ?? const <String>[];
      if (!operators.contains(rule.operator)) {
        issues.add(ConditionIssue(path: [...at, 'operator'], code: 'OPERATOR', field: rule.field));
        continue;
      }
      if (!_valueValid(def, rule.operator, rule.value, limit)) {
        issues.add(ConditionIssue(path: [...at, 'value'], code: 'VALUE', field: rule.field));
      }
    }
  }

  walk(group, 1, []);
  if (ruleCount > limit.maxRules) issues.add(const ConditionIssue(path: [], code: 'TOO_MANY_RULES'));
  return issues;
}

/// 정규형을 만듭니다. 화면 키 등 모르는 키를 버리고 키 순서를 고정하고 `in` 값의 중복을 없애 정렬합니다.
///
/// 저장·잠금 비교·스냅샷이 같은 함수입니다.
ConditionGroup canonicalizeConditionGroup(ConditionGroup group) => ConditionGroup(
      combinator: group.combinator,
      rules: [
        for (final node in group.rules)
          node is ConditionGroup ? canonicalizeConditionGroup(node) : canonicalizeConditionRule(node as ConditionRule),
      ],
    );

/// 규칙의 정규형을 만듭니다. `in`은 값의 중복을 없애 문자열 순, `birthMonthIn`은 숫자 순으로 정렬합니다.
ConditionRule canonicalizeConditionRule(ConditionRule rule) {
  final raw = rule.value;
  final Object? value;
  if (rule.operator == 'in' && raw is List) {
    // JS 기본 정렬 — 문자열로 바꿔 UTF-16 코드 단위 순
    value = raw.toSet().toList()..sort((a, b) => _jsString(a).compareTo(_jsString(b)));
  } else if (rule.operator == 'birthMonthIn' && raw is List) {
    value = raw.toSet().toList()..sort((a, b) => a is num && b is num ? a.compareTo(b) : 0);
  } else {
    value = raw;
  }
  return ConditionRule(field: rule.field, operator: rule.operator, value: value);
}

/// JS `String(value)` — 정수 값 double은 소수점 없이 쓴다
String _jsString(Object? value) {
  if (value is double && value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21) {
    return value.toInt().toString();
  }
  return '$value';
}

/// 트리에 나온 필드 이름입니다. 쓰는 쪽이 필요한 사실 값만 읽는 데 씁니다.
Set<String> conditionFields(ConditionGroup group) {
  final fields = <String>{};
  void walk(ConditionGroup node) {
    for (final child in node.rules) {
      if (child is ConditionGroup) {
        walk(child);
      } else {
        fields.add((child as ConditionRule).field);
      }
    }
  }

  walk(group);
  return fields;
}

int? _minutesOf(String time) {
  if (!_timePattern.hasMatch(time)) return null;
  final parts = time.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

bool _ruleHolds<Ctx>(ConditionRule rule, ConditionCatalog<Ctx> catalog, Ctx ctx) {
  final def = catalog[rule.field];
  if (def == null) return false;
  final fact = def.resolve(ctx);
  if (fact == null) return false;
  final operator = rule.operator;
  final value = rule.value;
  switch (def.type) {
    case 'integer':
      if (fact is! num || fact.isNaN) return false;
      if (operator == '=') return value is num && fact == value;
      if (operator == '>=') return value is num && fact >= value;
      if (operator == '<=') return value is num && fact <= value;
      if (operator == 'between' && value is List) {
        final from = value.isNotEmpty ? value[0] : null;
        final to = value.length > 1 ? value[1] : null;
        return from is num && to is num && fact >= from && fact <= to;
      }
      return false;
    case 'boolean':
      return operator == '=' && value is bool && fact == value;
    case 'idSet':
    case 'enumSet':
      if (operator != 'in' || value is! List) return false;
      final facts = fact is List ? fact : [fact];
      return facts.any(value.contains);
    case 'timeRange':
      if (operator != 'between' || value is! List || fact is! String) return false;
      final at = _minutesOf(fact);
      final first = value.isNotEmpty ? value[0] : null;
      final second = value.length > 1 ? value[1] : null;
      final from = first is String ? _minutesOf(first) : null;
      final to = second is String ? _minutesOf(second) : null;
      if (at == null || from == null || to == null) return false;
      // 끝 제외. 시작 > 끝이면 자정을 넘는 구간(22:00~02:00)
      return from < to ? at >= from && at < to : at >= from || at < to;
    case 'birthdate':
      if (fact is! BirthdateFact) return false;
      final age = fact.age;
      if (operator == 'ageBetween' && value is List) {
        final from = value.isNotEmpty ? value[0] : null;
        final to = value.length > 1 ? value[1] : null;
        return age != null && from is num && to is num && age >= from && age <= to;
      }
      if (operator == 'age>=') return age != null && value is num && age >= value;
      if (operator == 'age<=') return age != null && value is num && age <= value;
      if (operator == 'birthMonthIn') return value is List && value.contains(fact.month);
      if (operator == 'birthMonthIsCurrent') return value == true && fact.isCurrentMonth;
      return false;
  }
  return false;
}

/// 노드 하나를 평가합니다. 빈 그룹은 참(조건 없음)입니다.
bool evaluateConditionNode<Ctx>(ConditionNode node, ConditionCatalog<Ctx> catalog, Ctx ctx) {
  if (node is! ConditionGroup) return _ruleHolds(node as ConditionRule, catalog, ctx);
  final rules = node.rules;
  if (rules.isEmpty) return true;
  return node.combinator == 'and'
      ? rules.every((child) => evaluateConditionNode(child, catalog, ctx))
      : rules.any((child) => evaluateConditionNode(child, catalog, ctx));
}

/// 트리를 평가합니다. 최상위가 `and`(또는 노드가 하나 이하)면 실패한 최상위 노드를 앞에서부터 돌려줍니다.
ConditionEvaluation evaluateCondition<Ctx>(ConditionGroup group, ConditionCatalog<Ctx> catalog, Ctx ctx) {
  final rules = group.rules;
  if (group.combinator == 'and' || rules.length <= 1) {
    final failed = [
      for (final child in rules)
        if (!evaluateConditionNode(child, catalog, ctx)) child,
    ];
    return ConditionEvaluation(passed: failed.isEmpty, failed: failed);
  }
  return ConditionEvaluation(passed: evaluateConditionNode(group, catalog, ctx), failed: const []);
}

/// 규칙이 하나라도 맞는지입니다. 평평한 규칙 목록(포함·제외 대상)용이고 빈 목록은 거짓입니다.
bool anyConditionHolds<Ctx>(List<ConditionRule> rules, ConditionCatalog<Ctx> catalog, Ctx ctx) =>
    rules.any((rule) => _ruleHolds(rule, catalog, ctx));

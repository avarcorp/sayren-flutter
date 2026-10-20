// Node SDK 설명(한다체)을 pub 문서 문장(하십시오체)으로 바꾼다. 문장 끝 「다」만 바꾸고 나머지는 그대로 둔다.

const BASE = 0xac00;
const isHangul = (ch) => ch >= "가" && ch <= "힣";
const jong = (ch) => (ch.charCodeAt(0) - BASE) % 28;
const withJong = (ch, j) => String.fromCharCode(ch.charCodeAt(0) - jong(ch) + j);
const J_NONE = 0;
const J_N = 4; // ㄴ
const J_L = 8; // ㄹ
const J_B = 17; // ㅂ

// 받침 없는 음절로 끝나는 용언 어간(형용사·하다·이다) — 나머지 받침 없는 음절 + 다는 명사 + 이다의 준말로 본다
const VOWEL_STEMS = new Set(["하", "이", "니", "르", "크", "쁘", "프"]);

/** 문장 끝 「…다」 한 단어를 하십시오체로 바꾼다. 바꿀 수 없으면 null */
function formalWord(word) {
  if (!word.endsWith("다") || word.length < 2 || word.endsWith("니다")) return null; // 이미 하십시오체
  const stem = word.slice(0, -1);
  const last = stem.at(-1);
  if (!isHangul(last)) return `${stem}입니다`; // `null`다 → `null`입니다
  if (last === "는" && stem.length >= 2) return `${stem.slice(0, -1)}습니다`; // 읽는다 → 읽습니다
  const j = jong(last);
  if (j === J_N) return `${stem.slice(0, -1)}${withJong(last, J_B)}니다`; // 한다 → 합니다, 보낸다 → 보냅니다
  if (j === J_L) return `${stem.slice(0, -1)}${withJong(last, J_B)}니다`; // 길다 → 깁니다
  if (j !== J_NONE) return `${stem}습니다`; // 있다 → 있습니다, 했다 → 했습니다
  if (VOWEL_STEMS.has(last)) return `${stem.slice(0, -1)}${withJong(last, J_B)}니다`; // 필요하다 → 필요합니다, 아니다 → 아닙니다
  return `${stem}입니다`; // 통화다 → 통화입니다
}

/**
 * 한다체 문단을 하십시오체로 바꾼다. 문장 끝(마침표·줄 끝·` — `·괄호 앞)의 「다」로 끝나는 단어만 바꾼다.
 * 코드 구간(백틱)은 건드리지 않는다.
 */
export function toFormal(text) {
  if (!text) return text;
  const parts = text.split(/(`[^`]*`)/);
  return parts
    .map((original, i) => {
      let part = original;
      if (i % 2 === 1) return part;
      // 코드 바로 뒤의 「다」(`X`다) → 「입니다」
      if (i > 0) part = part.replace(/^다(?=(\.|\s*$|\s*\n|\s*—|\)|\(|,\s|;\s))/, "입니다");
      return part
        .replace(/([^\s`()*]*다)(?=(\.|\s*$|\s*\n|\s*—|\)|\(|\*\*|,\s|;\s|:\s))/g, (m) => formalWord(m) ?? m)
        .replace(/([가-힣]*(?:는|인|은|한|된|했는|였는))가(?=(\.|\?|\s*$|\s*\n|\s*—|\(|\)|\*\*))/g, "$1지입니다");
    })
    .join("")
    .replace(/([^\s.])$/u, (m) => m) // 끝 문장부호는 그대로
    .trim();
}

/** 문서 문장 끝에 마침표를 찍는다(dartdoc 첫 문장 요약용) */
export function sentence(text) {
  if (!text) return text;
  const t = text.trim();
  return /[.!?]$/.test(t) ? t : `${t}.`;
}

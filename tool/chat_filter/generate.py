#!/usr/bin/env python3
"""공통 규칙으로 Dart 검사 데이터와 PostgreSQL 마이그레이션을 생성한다."""
import argparse
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RULES = json.loads((HERE / 'rules.json').read_text())
LEADS = 'ㄱㄱㄴㄷㄷㄹㅁㅂㅂㅅㅅㅇㅈㅈㅊㅋㅌㅍㅎ'
VOWELS = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'
TAILS = ['ㄱ', 'ㄱ', 'ㄱㅅ', 'ㄴ', 'ㄴㅈ', 'ㄴㅎ', 'ㄷ', 'ㄹ', 'ㄹㄱ', 'ㄹㅁ',
         'ㄹㅂ', 'ㄹㅅ', 'ㄹㅌ', 'ㄹㅍ', 'ㄹㅎ', 'ㅁ', 'ㅂ', 'ㅂㅅ', 'ㅅ', 'ㅅ',
         'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']
JAMO = dict(zip(map(chr, range(0x1100, 0x1113)), LEADS))
JAMO.update(zip(map(chr, range(0x1161, 0x1176)), VOWELS))
JAMO.update(zip(map(chr, range(0x11a8, 0x11c3)), TAILS))


def fold(char):
    if 0xff01 <= ord(char) <= 0xff5e:
        return chr(ord(char) - 0xfee0).lower()
    decomposed = unicodedata.normalize('NFKD', char).lower()
    # 외국어 전체를 발음으로 치환하지 않는다. ASCII와 현대 한글 자모만 통일한다.
    decomposed = ''.join(c for c in decomposed if not unicodedata.category(c).startswith('M'))
    if decomposed and all(c in JAMO or 'a' <= c <= 'z' or '0' <= c <= '9' for c in decomposed):
        return ''.join(JAMO.get(c, c) for c in decomposed)
    return RULES['lookalikes'].get(char.lower(), char)


FOLDS = {}
for code in range(0x110000):
    if 0xac00 <= code <= 0xd7a3 or 0xd800 <= code <= 0xdfff:
        continue  # 완성형 한글은 런타임에서 분해한다.
    char = chr(code)
    value = fold(char)
    if value != char:
        FOLDS[char] = value

# 결합 부호, 폭 없는 문자, 방향 제어 문자, variation selector를 삭제한다.
IGNORED_CODES = [c for c in range(0x110000)
                 if unicodedata.category(chr(c)) in ('Mn', 'Me', 'Cf')
                 or c in (0x115f, 0x1160, 0x3164, 0xffa0)]


def char_ranges(codes):
    groups = []
    start = end = codes[0]
    for code in codes[1:]:
        if code == end + 1:
            end = code
        else:
            groups.append(chr(start) if start == end else chr(start) + '-' + chr(end))
            start = end = code
    groups.append(chr(start) if start == end else chr(start) + '-' + chr(end))
    return '[' + ''.join(groups) + ']'


IGNORED = char_ranges(IGNORED_CODES)


def normalize(text):
    text = ''.join(fold(c) if 0xac00 <= ord(c) <= 0xd7a3 else FOLDS.get(c, c) for c in text)
    text = re.sub(IGNORED, '', text)
    text = ''.join(c if c.isalnum() or c in '!@$|+*' else ' ' for c in text)
    text = re.sub(r'([ㅏ-ㅣ])(ㅇ\1)+', r'\1', text)
    text = re.sub(r'([a-z])([ 0-9!@$|+*]*\1)+', r'\1', text)
    return re.sub(r'(.)\1+', r'\1', text)


GAP = '[ 0-9!@$|+*]*'
TOKEN_BOUNDARY = '[^a-z0-9ㄱ-ㅎㅏ-ㅣ]'


def pattern(word, english=False):
    units = []
    for char in normalize(word):
        aliases = RULES['leet'].get(char) if english else None
        units.append('[' + aliases + ']' if aliases else re.escape(char))
    return GAP.join(units)


korean = '|'.join(sorted({pattern(w) for w in RULES['korean']}))
tokens = '|'.join(sorted({pattern(w) for w in RULES['korean_tokens']}))
english = '|'.join(sorted({pattern(w, True) for w in RULES['english']}))
KOREAN_BLOCKED = (f'({korean})(?![ㅏ-ㅣ])|(^|{TOKEN_BOUNDARY})({tokens})($|{TOKEN_BOUNDARY})'
                  f'|(^|[^0-9])18{GAP}({pattern("놈")}|{pattern("년아")}|{pattern("새끼")})(?![ㅏ-ㅣ])')
MASKED = r'(^|[^a-z0-9])(b\*+h|f\*+k|s\*+t)($|[^a-z0-9])'
BLOCKED = f'{KOREAN_BLOCKED}|(^|[^a-z0-9])({english})($|[^a-z0-9])|{MASKED}'
ALLOWED = f'(^|{TOKEN_BOUNDARY})(' + '|'.join(
    re.escape(normalize(w)) for w in RULES['allowed_korean_prefixes']) + '|[0-9]+' + normalize('개년') + ')'
GROUPS = {}
for char, value in FOLDS.items():
    GROUPS[value] = GROUPS.get(value, '') + char


def sql(value):
    return "'" + value.replace("'", "''") + "'"


def dart_string(value):
    literal = json.dumps(value, ensure_ascii=False).replace('$', r'\$')
    return ''.join(f'\\u{{{ord(c):x}}}' if unicodedata.category(c) == 'Cf' else c
                   for c in literal)


dart = '// 자동 생성: python3 tool/chat_filter/generate.py (직접 수정하지 않음)\n'
dart += f'// Unicode {unicodedata.unidata_version}\n'
for name, value in [('chatRejectionMessage', RULES['message']), ('chatIgnoredPattern', IGNORED),
                    ('chatAllowedPattern', ALLOWED), ('chatKoreanPattern', KOREAN_BLOCKED),
                    ('chatMaskedPattern', MASKED)]:
    dart += f'const {name} = {dart_string(value)};\n'
dart += 'const chatEnglishTokens = <List<String>>[\n'
for word in sorted({normalize(w) for w in RULES['english']}):
    # Dart/Web 양쪽의 32비트 비트 연산으로 상태를 표현한다.
    if not 1 <= len(word) <= 30:
        raise ValueError(f'영문 규칙은 정규화 후 1~30자여야 합니다: {word}')
    dart += '  [' + ', '.join(dart_string(RULES['leet'].get(c, c)) for c in word) + '],\n'
dart += '];\n'
dart += 'const chatFoldGroups = <String, String>{\n'
for value, chars in sorted(GROUPS.items()):
    dart += f'  {dart_string(value)}: {dart_string(chars)},\n'
dart += '};\n'

migration = f"""-- 자동 생성: python3 tool/chat_filter/generate.py (직접 수정하지 않음)
-- Unicode {unicodedata.unidata_version}. 앱과 동일한 규칙. 본문 변경 없는 읽음 처리와 업무 이력은 보존한다.
create or replace function saip_private.chat_normalize(input text)
returns text language plpgsql immutable set search_path = '' as $function$
declare
  folds constant jsonb := {sql(json.dumps(FOLDS, ensure_ascii=False, separators=(',', ':')))}::jsonb;
  output text := '';
  ch text;
  code integer;
  syllable integer;
begin
  foreach ch in array string_to_array(coalesce(input, ''), null) loop
    code := ascii(ch);
    if code between 44032 and 55203 then
      syllable := code - 44032;
      output := output || (folds->>chr(4352 + syllable / 588))
        || (folds->>chr(4449 + (syllable % 588) / 28));
      if syllable % 28 <> 0 then
        output := output || (folds->>chr(4519 + syllable % 28));
      end if;
    else
      output := output || coalesce(folds->>ch, ch);
    end if;
  end loop;
  output := regexp_replace(output, {sql(IGNORED)}, '', 'g');
  output := regexp_replace(output, '[^[:alnum:]!@$|+*]', ' ', 'g');
  output := regexp_replace(output, '([ㅏ-ㅣ])(ㅇ\\1)+', '\\1', 'g');
  output := regexp_replace(output, '([a-z])([ 0-9!@$|+*]*\\1)+', '\\1', 'g');
  return regexp_replace(output, '(.)\\1+', '\\1', 'g');
end $function$;

create or replace function saip_private.chat_has_profanity(input text)
returns boolean language sql immutable set search_path = '' as $function$
  select regexp_replace(saip_private.chat_normalize(input), {sql(ALLOWED)}, '\\1~', 'g')
    ~ {sql(BLOCKED)}
$function$;

create or replace function saip_private.enforce_chat_content()
returns trigger language plpgsql set search_path = '' as $function$
begin
  if new.collection <> 'messages' or coalesce((new.data->>'system')::boolean, false) then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.collection = new.collection and old.data->>'body' is not distinct from new.data->>'body'
       and old.data->>'system' is not distinct from new.data->>'system' then
      return new;
    end if;
  end if;
  if length(coalesce(new.data->>'body', '')) > 10000 then
    raise exception '메시지를 10,000자 이하로 나누어 보내 주세요.';
  end if;
  if saip_private.chat_has_profanity(new.data->>'body') then
    raise exception using errcode = 'P0001', message = {sql(RULES['message'])};
  end if;
  return new;
end $function$;

drop trigger if exists saip_chat_content on public.saip_records;
create trigger saip_chat_content before insert or update on public.saip_records
for each row execute function saip_private.enforce_chat_content();

revoke all on function saip_private.chat_normalize(text), saip_private.chat_has_profanity(text),
  saip_private.enforce_chat_content() from public, anon, authenticated;
"""

cases = json.loads((ROOT / 'test/fixtures/chat_content_cases.json').read_text())
corpus = """-- 자동 생성: 앱과 같은 사례를 PostgreSQL 정규식 엔진에서도 검사한다.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();
"""
for category, bodies in cases.items():
    for index, body in enumerate(bodies, 1):
        expected = 'true' if category == 'blocked' else 'false'
        corpus += f'select is(saip_private.chat_has_profanity({sql(body)}), {expected}, {sql(f"{category} {index}")});\n'
corpus += 'select * from finish();\nrollback;\n'

outputs = {
    ROOT / 'lib/local/domain/chat_filter_data.dart': dart,
    ROOT / 'supabase/migrations' / RULES['migration']: migration,
    ROOT / 'supabase/tests/chat_content_corpus_test.sql': corpus,
}
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true', help='생성 파일과 규칙의 일치 여부만 검사')
args = parser.parse_args()
for path, contents in outputs.items():
    if args.check:
        if not path.exists() or path.read_text() != contents:
            raise SystemExit(f'재생성 필요: {path.relative_to(ROOT)}')
    else:
        path.write_text(contents)
        print(path.relative_to(ROOT))

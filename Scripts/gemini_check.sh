#!/bin/zsh
# Gemini API 키 검증 스크립트
# 사용법:
#   GEMINI_API_KEY=발급키 Scripts/gemini_check.sh
#   GEMINI_API_KEY=발급키 Scripts/gemini_check.sh gemini-3.8-flash
#   GEMINI_API_KEY=발급키 Scripts/gemini_check.sh gemini-3.8-flash /경로/audio.m4a
#
# 무료 키 발급: https://aistudio.google.com/apikey
set -uo pipefail

BASE="https://generativelanguage.googleapis.com/v1beta"
KEY="${GEMINI_API_KEY:-${1:-}}"
MODEL="${2:-gemini-3.8-flash}"
AUDIO="${3:-}"

if [[ -z "$KEY" && -f .env ]]; then
  KEY=$(grep -E '^GEMINI_API_KEY=' .env | head -1 | cut -d= -f2-)
fi

if [[ -z "$KEY" ]]; then
  cat <<'USAGE'
사용법:
  GEMINI_API_KEY=발급받은키 Scripts/gemini_check.sh [모델] [오디오파일]

예:
  GEMINI_API_KEY=AIza... Scripts/gemini_check.sh
  GEMINI_API_KEY=AIza... Scripts/gemini_check.sh gemini-3.8-flash /경로/audio.m4a

무료 키 발급: https://aistudio.google.com/apikey
USAGE
  exit 1
fi

has_python=0
command -v python3 >/dev/null 2>&1 && has_python=1

show_json() {
  if [[ $has_python -eq 1 ]]; then
    python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    print(open(sys.argv[1]).read()[:500]); sys.exit()
print("오류:", json.dumps(d.get("error"), ensure_ascii=False) if d.get("error") else json.dumps(d, ensure_ascii=False)[:600])' "$1"
  else
    head -c 600 "$1"; echo
  fi
}

echo "== 1) 키 유효성 / 사용 가능한 모델 확인"
code=$(curl -s -o /tmp/gemini_models.json -w "%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models?key=$KEY")
echo "HTTP $code"
if [[ "$code" != "200" ]]; then
  echo "키가 유효하지 않거나 오류가 있습니다:"; show_json /tmp/gemini_models.json; exit 1
fi
if [[ $has_python -eq 1 ]]; then
  python3 - <<'PY'
import json
data = json.load(open('/tmp/gemini_models.json'))
names = [m['name'].split('/')[-1] for m in data.get('models', [])]
print("사용 가능한 모델 수:", len(names))
for probe in ("gemini-3.8-flash", "gemini-3.5-flash", "gemini-3.5-transcribe",
              "gemini-2.5-flash", "gemini-2.5-flash-lite"):
    print(("  [O] " if probe in names else "  [X] ") + probe)
PY
fi

echo
echo "== 2) 텍스트 생성 테스트 ($MODEL)"
body='{"contents":[{"parts":[{"text":"다음 문장을 20자 이내로 요약해줘: 숏폼 영상은 첫 3초가 가장 중요하다."}]}]}'
code=$(curl -s -o /tmp/gemini_text.json -w "%{http_code}" -X POST \
  -H "Content-Type: application/json" -d "$body" \
  "$BASE/models/$MODEL:generateContent?key=$KEY")
echo "HTTP $code"
if [[ "$code" == "200" && $has_python -eq 1 ]]; then
  python3 -c 'import json; d=json.load(open("/tmp/gemini_text.json")); print("응답:", d["candidates"][0]["content"]["parts"][0]["text"].strip())'
else
  show_json /tmp/gemini_text.json
fi

if [[ -n "$AUDIO" ]]; then
  echo
  echo "== 3) 오디오 전사 테스트 ($MODEL)"
  if [[ ! -f "$AUDIO" ]]; then echo "파일을 찾을 수 없습니다: $AUDIO"; exit 1; fi
  if [[ $has_python -eq 0 ]]; then echo "오디오 테스트에는 python3가 필요합니다."; exit 1; fi
  python3 - "$AUDIO" <<'PY'
import base64, json, os, sys
path = sys.argv[1]
ext = os.path.splitext(path)[1].lower()
mime = {'.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4',
        '.aac': 'audio/aac', '.ogg': 'audio/ogg', '.flac': 'audio/flac',
        '.aiff': 'audio/aiff'}.get(ext, 'audio/mp4')
data = base64.b64encode(open(path, 'rb').read()).decode()
prompt = ('Transcribe this audio in its original language. Return ONLY JSON: '
          '{"language":"xx","segments":[{"start":0.0,"end":2.0,"text":"..."}],"text":"full text"}')
req = {"contents":[{"parts":[{"text":prompt},{"inlineData":{"mimeType":mime,"data":data}}]}],
       "generationConfig":{"responseMimeType":"application/json"}}
json.dump(req, open('/tmp/gemini_audio_req.json','w'))
print("mime:", mime, "| base64 bytes:", len(data))
PY
  code=$(curl -s -o /tmp/gemini_audio.json -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" --data-binary @/tmp/gemini_audio_req.json \
    "$BASE/models/$MODEL:generateContent?key=$KEY")
  echo "HTTP $code"
  show_json /tmp/gemini_audio.json
fi

echo
echo "== 완료 =="

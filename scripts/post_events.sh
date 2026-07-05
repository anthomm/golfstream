#!/usr/bin/env bash
# post_events.sh – send random JSON event payloads to the /events endpoint

HOST="${HOST:-localhost}"
PORT="${PORT:-8080}"
COUNT="${COUNT:-10}"          # number of events to send
DELAY="${DELAY:-0.5}"         # seconds between requests

BASE_URL="http://${HOST}:${PORT}/events"

# ── helpers ───────────────────────────────────────────────────────────────────

random_int()  { echo $(( RANDOM % ($2 - $1 + 1) + $1 )); }
random_float(){ awk "BEGIN{printf \"%.2f\", $1 + rand() * ($2 - $1)}"; }

PLAYERS=("Tiger Woods" "Rory McIlroy" "Jon Rahm" "Scottie Scheffler" "Brooks Koepka" "Dustin Johnson" "Justin Thomas" "Collin Morikawa")
COURSES=("Augusta National" "St Andrews" "Pebble Beach" "Torrey Pines" "Whistling Straits" "Shinnecock Hills")
EVENT_TYPES=("tee_shot" "approach_shot" "chip" "putt" "hole_completed" "round_started" "round_completed" "scorecard_update")

random_element() {
  local arr=("$@")
  echo "${arr[$(( RANDOM % ${#arr[@]} ))]}"
}

# ── event generators ──────────────────────────────────────────────────────────

build_tee_shot() {
  local player course hole par distance
  player=$(random_element "${PLAYERS[@]}")
  course=$(random_element "${COURSES[@]}")
  hole=$(random_int 1 18)
  par=$(random_int 3 5)
  distance=$(random_int 150 550)
  cat <<EOF
{
  "event_type": "tee_shot",
  "player": "$player",
  "course": "$course",
  "hole": $hole,
  "par": $par,
  "distance_yards": $distance,
  "club": "Driver",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

build_putt() {
  local player course hole distance made
  player=$(random_element "${PLAYERS[@]}")
  course=$(random_element "${COURSES[@]}")
  hole=$(random_int 1 18)
  distance=$(random_float 1 40)
  made=$(( RANDOM % 2 ))
  cat <<EOF
{
  "event_type": "putt",
  "player": "$player",
  "course": "$course",
  "hole": $hole,
  "distance_feet": $distance,
  "made": $([ $made -eq 1 ] && echo true || echo false),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

build_hole_completed() {
  local player course hole par score
  player=$(random_element "${PLAYERS[@]}")
  course=$(random_element "${COURSES[@]}")
  hole=$(random_int 1 18)
  par=$(random_int 3 5)
  score=$(( par + RANDOM % 5 - 2 ))   # eagle to double-bogey
  cat <<EOF
{
  "event_type": "hole_completed",
  "player": "$player",
  "course": "$course",
  "hole": $hole,
  "par": $par,
  "score": $score,
  "score_to_par": $(( score - par )),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

build_scorecard_update() {
  local player course round total_score
  player=$(random_element "${PLAYERS[@]}")
  course=$(random_element "${COURSES[@]}")
  round=$(random_int 1 4)
  total_score=$(random_int -10 15)
  cat <<EOF
{
  "event_type": "scorecard_update",
  "player": "$player",
  "course": "$course",
  "round": $round,
  "total_score_to_par": $total_score,
  "holes_completed": $(random_int 1 18),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

random_payload() {
  local types=("tee_shot" "putt" "hole_completed" "scorecard_update")
  local t
  t=$(random_element "${types[@]}")
  case "$t" in
    tee_shot)         build_tee_shot ;;
    putt)             build_putt ;;
    hole_completed)   build_hole_completed ;;
    scorecard_update) build_scorecard_update ;;
  esac
}

# ── main loop ─────────────────────────────────────────────────────────────────

echo "Posting $COUNT events to $BASE_URL (delay: ${DELAY}s)"
echo "---"

for i in $(seq 1 "$COUNT"); do
  PAYLOAD=$(random_payload)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$BASE_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  echo "[${i}/${COUNT}] status=${HTTP_STATUS}  event_type=$(echo "$PAYLOAD" | grep '"event_type"' | awk -F'"' '{print $4}')"

  sleep "$DELAY"
done

echo "---"
echo "Done."


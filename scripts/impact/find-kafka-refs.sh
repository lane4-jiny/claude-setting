#!/bin/bash
# Find references to a Kafka topic name across all lane4 repos.
# Catches both producers (.emit('topic')) and consumers (@MessagePattern('topic')).
#
# Usage:
#   find-kafka-refs.sh <topic-name>
#
# Examples:
#   find-kafka-refs.sh "local.driver.begin-driving"
#   find-kafka-refs.sh "local.monitoring.send-monitoring-notification"
#
# Output is grouped: line context will reveal whether it's a producer or consumer.

set -e

TOPIC="$1"

if [ -z "$TOPIC" ]; then
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 1
fi

source "$(dirname "$0")/lib/repos.sh"

for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  rg \
    --line-number --no-heading --color=never \
    --context 1 \
    "${LANE4_RG_EXCLUDES[@]}" \
    --type ts \
    -F "$TOPIC" "$repo" 2>/dev/null || true
done

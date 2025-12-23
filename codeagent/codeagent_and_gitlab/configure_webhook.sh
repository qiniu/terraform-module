#!/bin/bash
set -e

# GitLab Webhook Configuration Script
# This script waits for GitLab to be ready and creates a webhook for CodeAgent

GITLAB_URL="${gitlab_url}"
CODEAGENT_IP="${codeagent_ip}"
TOKEN="${gitlab_token}"
WEBHOOK_SECRET="${webhook_secret}"
PROJECT_ID="${project_id}"

echo "============================================"
echo "Configuring GitLab Webhook"
echo "GitLab URL: $GITLAB_URL"
echo "CodeAgent IP: $CODEAGENT_IP"
echo "Project ID: $PROJECT_ID"
echo "============================================"

# Create webhook with retry (GitLab will be checked as part of the API call)
echo "Creating webhook for project ID $PROJECT_ID..."

max_retry=30
retry=0

while [ $retry -lt $max_retry ]; do
  echo "Attempt $((retry + 1))/$max_retry..."

  response=$(curl -s -w "\n%%{http_code}" --request POST \
    --header "PRIVATE-TOKEN: $TOKEN" \
    --data "url=http://$CODEAGENT_IP:8889/hook" \
    --data "push_events=true" \
    --data "merge_requests_events=true" \
    --data "issues_events=true" \
    --data "confidential_issues_events=true" \
    --data "note_events=true" \
    --data "confidential_note_events=true" \
    --data "enable_ssl_verification=false" \
    --data "token=$WEBHOOK_SECRET" \
    "$GITLAB_URL/api/v4/projects/$PROJECT_ID/hooks" 2>/dev/null)

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" = "201" ]; then
    echo "✓ Webhook created successfully!"
    echo "Response: $body"
    exit 0
  elif echo "$body" | grep -q "already exists"; then
    echo "✓ Webhook already exists"
    exit 0
  else
    echo "Got response code: $http_code"
    retry=$((retry + 1))
    if [ $retry -lt $max_retry ]; then
      echo "Retrying in 10 seconds..."
      sleep 10
    fi
  fi
done

echo ""
echo "WARNING: Failed to create webhook after $max_retry attempts"
echo "You can manually create it later with:"
echo "  curl --request POST --header \"PRIVATE-TOKEN: $TOKEN\" \\"
echo "    --data \"url=http://$CODEAGENT_IP:8889/hook\" --data \"token=$WEBHOOK_SECRET\" \\"
echo "    \"$GITLAB_URL/api/v4/projects/$PROJECT_ID/hooks\""
exit 0

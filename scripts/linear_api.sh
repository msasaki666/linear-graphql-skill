#!/usr/bin/env bash
# Linear GraphQL API ヘルパー
# Usage: source linear_api.sh

LINEAR_API_URL="https://api.linear.app/graphql"

# 基本クエリ実行
linear_query() {
  local query="$1"
  curl -s -X POST "$LINEAR_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LINEAR_API_TOKEN" \
    --data "{\"query\": \"$query\"}" | jq .
}

# variables付きクエリ実行
linear_query_with_vars() {
  local query="$1"
  local variables="$2"
  local payload
  payload=$(jq -n --arg q "$query" --argjson v "$variables" '{query: $q, variables: $v}')
  curl -s -X POST "$LINEAR_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LINEAR_API_TOKEN" \
    --data "$payload" | jq .
}

# 接続確認
linear_whoami() {
  linear_query '{ viewer { id name email } }' | jq '.data.viewer'
}

# チーム一覧
linear_teams() {
  linear_query '{ teams { nodes { id name key description } } }' | jq '.data.teams.nodes'
}

# プロジェクト一覧
linear_projects() {
  linear_query '{ projects(first: 20) { nodes { id name state startDate targetDate lead { name } teams { nodes { name } } } } }' | jq '.data.projects.nodes'
}

# チームのワークフロー状態一覧
linear_team_states() {
  local team_id="$1"
  local vars
  vars=$(jq -n --arg id "$team_id" '{teamId: $id}')
  linear_query_with_vars \
    'query($teamId: String!) { team(id: $teamId) { states { nodes { id name type position } } } }' \
    "$vars" \
    | jq '.data.team.states.nodes | sort_by(.position)'
}

echo "Linear API ヘルパーをロードしました。linear_whoami で接続確認できます。"

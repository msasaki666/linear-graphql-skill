---
name: linear-graphql
description: >
  Linear のIssue管理をGraphQL API + curl で直接行うスキル。
  MCP不要で軽量、コンテキストウィンドウの消費を最小限に抑える。
  ユーザーが「Linearのissue」「チケット作成」「タスク一覧」「Linear検索」
  「issueにコメント」「プロジェクト確認」などLinear関連の操作に言及したら
  必ずこのスキルを使う。Linear MCPの代替として常に優先する。
---

# Linear GraphQL Skill

Linear の GraphQL API を `curl` で直接叩き、Issue管理を行うスキル。
Linear MCP の代替として、コンテキストウィンドウの消費を最小限に抑える。

## 自動認証フロー（最重要）

**Linear関連の操作を行う前に、必ずこのフローを実行する。**
ユーザーに認証情報を聞く必要はない。

### Step 1: 環境準備

```bash
# jq が無ければインストール（毎セッション必要）
which jq > /dev/null 2>&1 || (apt-get update -qq 2>/dev/null && apt-get install -y -qq jq 2>/dev/null)
```

### Step 2: MCP Vault からシークレット取得

MCP Vault コネクタの `get_secret` ツールを使って Linear の認証情報を取得する。
**プロジェクトナレッジには認証情報を保存しない。**

以下の2つのMCPツール呼び出しを実行する：

1. `get_secret(key: "linear-client-id")` → CLIENT_ID を取得
2. `get_secret(key: "linear-client-secret")` → CLIENT_SECRET を取得

> **注意**: MCP Vault コネクタが未接続の場合、ユーザーに接続を案内する。
> claude.ai の Settings → Connectors から MCP Vault を追加し、
> GitHub OAuth で認証を完了する必要がある。

### Step 3: Linear一時トークン取得

Step 2 で取得した CLIENT_ID と CLIENT_SECRET を使い、
`bash -c` 内で Client Credentials フローを実行する。

```bash
bash -c '
LINEAR_TOKEN_RESPONSE=$(curl -s -X POST https://api.linear.app/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=<MCP_VAULTから取得したCLIENT_ID>" \
  -d "client_secret=<MCP_VAULTから取得したCLIENT_SECRET>" \
  -d "scope=read,write")

export LINEAR_API_TOKEN=$(echo "$LINEAR_TOKEN_RESPONSE" | jq -r ".access_token")

if [ "$LINEAR_API_TOKEN" = "null" ] || [ -z "$LINEAR_API_TOKEN" ]; then
  echo "ERROR: トークン取得失敗"
  echo "$LINEAR_TOKEN_RESPONSE" | jq .
  exit 1
fi

echo "認証OK"

# 接続確認
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LINEAR_API_TOKEN" \
  --data "{\"query\": \"{ viewer { name } }\"}" | jq -r ".data.viewer.name"
'
```

`<MCP_VAULTから取得したCLIENT_ID>` と `<MCP_VAULTから取得したCLIENT_SECRET>` は
Step 2 の `get_secret` で取得した実際の値に置き換える。

### Step 4: 以後の操作

トークン取得後は、同じ `bash -c` ブロック内で続けて操作を行うか、
取得した `LINEAR_API_TOKEN` を後続のコマンドで使い回す。

**重要**: claude.ai のデフォルトシェルは `/bin/sh`（dash）なので、
全てのコマンドを `bash -c '...'` でラップして実行すること。

---

## 初回セットアップ手順（ユーザー向け案内）

### A. MCP Vault コネクタの接続（未接続の場合）

1. claude.ai の Settings → Connectors → Add custom connector
2. MCP Vault の URL を入力（例: `https://mcp-vault.xxx.workers.dev/mcp`）
3. GitHub OAuth でログイン・認証を完了する

### B. Linear OAuth アプリの作成（未作成の場合）

1. Linear にログイン → Settings → API → OAuth2 Applications
2. 「New OAuth2 Application」をクリック
3. Application name: `claude-linear-skill`（任意）
4. Redirect URLs: `http://localhost:3000/callback`（使わないが必須入力）
5. 「Client credentials tokens」を有効にする
6. 作成後、Client ID と Client Secret を控える

### C. 認証情報を MCP Vault に保存

MCP Vault の `set_secret` ツールで認証情報を安全に保存する：

1. `set_secret(key: "linear-client-id", value: "<取得したClient ID>", description: "Linear OAuth Client ID")`
2. `set_secret(key: "linear-client-secret", value: "<取得したClient Secret>", description: "Linear OAuth Client Secret")`

**プロジェクトナレッジには認証情報を保存しないこと。**
MCP Vault に保存すれば暗号化KVで安全に管理され、必要時に `get_secret` で取得できる。

詳細は `references/oauth-setup.md` を参照。

---

## 基本方針

1. **常に `curl` + GraphQL を使う**（外部CLIツールのインストール不要）
2. **必要最小限のフィールドだけ取得する**（レスポンスを小さく保つ）
3. **jq でレスポンスを整形する**（読みやすく、パース可能に）
4. **エラーハンドリングを必ず行う**（HTTP ステータスとGraphQLエラーの両方）
5. **全コマンドは `bash -c` でラップする**（`/bin/sh` 互換性対策）

## API呼び出しの基本パターン

```bash
bash -c '
export LINEAR_API_TOKEN="<token>"
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LINEAR_API_TOKEN" \
  --data "{\"query\": \"<GRAPHQL_QUERY>\"}" | jq .
'
```

### variables 付きクエリ（特殊文字を含む入力に安全）

```bash
bash -c '
export LINEAR_API_TOKEN="<token>"
PAYLOAD=$(jq -n \
  --arg q "mutation IssueCreate(\$input: IssueCreateInput!) { issueCreate(input: \$input) { success issue { identifier title url } } }" \
  --argjson v "{\"input\":{\"teamId\":\"...\",\"title\":\"...\"}}" \
  "{query: \$q, variables: \$v}")

curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LINEAR_API_TOKEN" \
  --data "$PAYLOAD" | jq .
'
```

## 典型的な操作フロー

### Issue 操作

1. チーム一覧を取得（teamId が必要な場合）
2. ワークフロー状態一覧を取得（stateId が必要な場合）
3. 目的の操作（作成/更新/検索等）を実行
4. 結果をユーザーに整形して表示

### よく使うクエリ

詳細は `references/graphql-queries.md` を参照。ここでは頻出パターンのみ示す。

```bash
# チーム一覧
'{ teams { nodes { id name key } } }'

# プロジェクト一覧
'{ projects(first: 20) { nodes { id name state targetDate } } }'

# 自分のissue
'{ viewer { assignedIssues(first: 10) { nodes { identifier title state { name } priority } } } }'
```

## ヘルパースクリプト

繰り返し使う操作は `scripts/linear_api.sh` を利用可能。
**必ず `bash -c` でラップして実行すること。**

```bash
bash -c '
export LINEAR_API_TOKEN="..."
source /path/to/scripts/linear_api.sh
linear_whoami
linear_teams
linear_projects
'
```

## ベストプラクティス

- **変数を使う**: GraphQL variables でクエリを安全に構築する
- **ページネーション**: `first` / `after` で必要な分だけ取得
- **フィルタリング**: サーバーサイドで絞り込み、レスポンスを小さく保つ
- **レート制限**: Linear は複雑度ベースの制限あり。大量操作時は間隔を空ける
- **1操作1ブロック**: bash -c ブロック内でトークン設定→操作→結果表示を完結させる

# Linear OAuth セットアップガイド

## 方式の選択

| 方式 | 用途 | トークン有効期限 | ブラウザ必要 |
|------|------|-----------------|------------|
| Client Credentials | アプリとして操作（チーム共有向け） | 30日 | 不要 |
| Authorization Code | ユーザーとして操作（個人向け） | 24時間（refresh可） | 初回のみ |

**推奨**: 個人利用なら Authorization Code、チーム自動化なら Client Credentials。

---

## 事前準備（共通）

1. Linear にログイン
2. Settings → API → OAuth2 Applications → 「New OAuth2 Application」
3. 以下を設定:
   - Application name: 任意（例: `claude-linear-skill`）
   - Redirect URLs: `http://localhost:3000/callback`（Auth Code用。Client Credentialsのみなら任意）
   - 必要なスコープを選択
4. 作成後、**Client ID** と **Client Secret** を控える
5. MCP Vault コネクタの `set_secret` ツールで安全に保存:
   - `set_secret(key: "linear-client-id", value: "<Client ID>", description: "Linear OAuth Client ID")`
   - `set_secret(key: "linear-client-secret", value: "<Client Secret>", description: "Linear OAuth Client Secret")`

> **注意**: プロジェクトナレッジに平文で保存しないこと。MCP Vault で暗号化管理する。

---

## Client Credentials フロー

ブラウザ不要。Linear のOAuth2アプリ設定で「Client credentials tokens」を有効にする必要がある。

> **注意**: `scope=read,write` の指定は必須。省略するとトークン取得に失敗する。

### トークン取得

```bash
export LINEAR_CLIENT_ID="your_client_id"
export LINEAR_CLIENT_SECRET="your_client_secret"

curl -s -X POST https://api.linear.app/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$LINEAR_CLIENT_ID" \
  -d "client_secret=$LINEAR_CLIENT_SECRET" \
  -d "scope=read,write" | jq .
```

レスポンス例:
```json
{
  "access_token": "lin_oauth_...",
  "token_type": "Bearer",
  "expires_in": 2591999,
  "scope": "read write"
}
```

取得したトークンを設定:
```bash
export LINEAR_API_TOKEN="lin_oauth_..."
```

---

## Authorization Code フロー

ユーザーとして操作する場合に使用。初回はブラウザでの認可が必要。

### 1. 認可URLの生成

```bash
CLIENT_ID="your_client_id"
REDIRECT_URI="http://localhost:3000/callback"
SCOPE="read,write"
STATE=$(openssl rand -hex 16)

echo "https://linear.app/oauth/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&state=${STATE}"
```

### 2. コールバックからcodeを取得

ユーザーがブラウザで認可すると、リダイレクトURLに `?code=xxx&state=xxx` が付与される。

### 3. codeをトークンに交換

```bash
curl -s -X POST https://api.linear.app/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=$LINEAR_CLIENT_ID" \
  -d "client_secret=$LINEAR_CLIENT_SECRET" \
  -d "redirect_uri=$REDIRECT_URI" \
  -d "code=<取得したcode>" | jq .
```

---

## トークンのリフレッシュ（Auth Codeフロー）

Authorization Codeフローのトークンは24時間で期限切れ。refresh_tokenで更新可能。

```bash
curl -s -X POST https://api.linear.app/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=$LINEAR_CLIENT_ID" \
  -d "client_secret=$LINEAR_CLIENT_SECRET" \
  -d "refresh_token=<refresh_token>" | jq .
```

---

## トラブルシューティング

| エラー | 原因 | 対処 |
|--------|------|------|
| `invalid_client` | Client IDまたはSecretが間違い | OAuth2アプリの設定を確認 |
| `invalid_grant` | codeが期限切れまたは既使用 | 認可フローをやり直す |
| `unauthorized_client` | Client Credentialsが未有効 | アプリ設定で有効化する |
| `invalid_scope` | 無効なスコープ指定 | `read`, `write` を確認 |

# linear-graphql-skill

Linear の Issue 管理を GraphQL API + `curl` で直接行う **Claude Skill**。
MCP 不要・外部 CLI 不要で、コンテキストウィンドウの消費を最小限に抑えます。

## 特徴

- **依存ゼロ** — `curl`, `jq`, `bash` だけで動作（追加インストール不要）
- **軽量** — MCP サーバーを立てずに Linear API を直接呼び出し
- **安全** — 認証情報は MCP Vault で暗号化管理、プロジェクト内に平文保存しない
- **フル機能** — Issue の作成・更新・検索・コメント、チーム/プロジェクト一覧、ページネーション対応

## ファイル構成

```
├── SKILL.md                        # スキル定義（認証フロー・API パターン・操作手順）
├── scripts/
│   └── linear_api.sh               # ヘルパー関数（linear_whoami, linear_teams 等）
└── references/
    ├── oauth-setup.md              # OAuth セットアップ手順・トラブルシューティング
    └── graphql-queries.md          # GraphQL クエリ・ミューテーション集
```

## セットアップ

### 1. Linear OAuth アプリを作成

1. Linear → Settings → API → OAuth2 Applications → **New OAuth2 Application**
2. **Client credentials tokens** を有効にする
3. Client ID と Client Secret を控える

### 2. MCP Vault に認証情報を保存

```
set_secret(key: "linear-client-id",     value: "<Client ID>")
set_secret(key: "linear-client-secret",  value: "<Client Secret>")
```

### 3. 使う

Claude のチャットで Linear 関連の操作を依頼するだけです。スキルが自動で認証フローを実行し、API を呼び出します。

> 詳細は [references/oauth-setup.md](references/oauth-setup.md) を参照してください。

## ヘルパー関数

`scripts/linear_api.sh` を source すると以下の関数が使えます：

| 関数 | 説明 |
|------|------|
| `linear_query <query>` | GraphQL クエリを実行 |
| `linear_query_with_vars <query> <vars>` | 変数付きクエリを実行（特殊文字安全） |
| `linear_whoami` | 接続確認（自分の情報を取得） |
| `linear_teams` | チーム一覧 |
| `linear_projects` | プロジェクト一覧 |
| `linear_team_states <team_id>` | チームのワークフロー状態一覧 |

```bash
bash -c '
export LINEAR_API_TOKEN="..."
source scripts/linear_api.sh
linear_whoami
'
```

## 認証方式

| 方式 | 用途 | トークン有効期限 | ブラウザ |
|------|------|-----------------|---------|
| Client Credentials | チーム共有・自動化 | 30 日 | 不要 |
| Authorization Code | 個人操作 | 24 時間（refresh 可） | 初回のみ |

## 注意事項

- claude.ai のデフォルトシェルは `/bin/sh` のため、全コマンドを `bash -c '...'` でラップする
- GraphQL の入力には variables を使い、文字列結合を避ける
- Linear はクエリ複雑度ベースのレート制限あり — 大量操作時は間隔を空ける
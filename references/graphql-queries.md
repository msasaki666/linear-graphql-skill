# Linear GraphQL クエリ・ミューテーション集

## 読み取り系

### チーム一覧
```graphql
{ teams { nodes { id name key description } } }
```

### プロジェクト一覧
```graphql
{ projects(first: 20) { nodes { id name state startDate targetDate lead { name } teams { nodes { name } } } } }
```

### ワークフロー状態一覧（チーム指定）
```graphql
query($teamId: String!) {
  team(id: $teamId) {
    states { nodes { id name type position } }
  }
}
```

### 自分のissue一覧
```graphql
{
  viewer {
    assignedIssues(first: 10) {
      nodes { identifier title state { name } priority createdAt }
    }
  }
}
```

### Issue検索（フィルタ付き）
```graphql
query($teamId: String, $stateType: String) {
  issues(
    first: 20
    filter: {
      team: { id: { eq: $teamId } }
      state: { type: { eq: $stateType } }
    }
  ) {
    nodes { identifier title state { name } assignee { name } priority }
  }
}
```

### Issue詳細
```graphql
query($id: String!) {
  issue(id: $id) {
    identifier title description state { name }
    assignee { name } priority labels { nodes { name } }
    comments { nodes { body createdAt user { name } } }
  }
}
```

## 書き込み系

### Issue作成
```graphql
mutation IssueCreate($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { identifier title url state { name } }
  }
}
```
variables:
```json
{ "input": { "teamId": "...", "title": "...", "description": "...", "stateId": "..." } }
```

### Issue更新
```graphql
mutation IssueUpdate($id: String!, $input: IssueUpdateInput!) {
  issueUpdate(id: $id, input: $input) {
    success
    issue { identifier title state { name } }
  }
}
```
variables:
```json
{ "id": "issue-uuid", "input": { "stateId": "...", "title": "..." } }
```

### コメント追加
```graphql
mutation CommentCreate($input: CommentCreateInput!) {
  commentCreate(input: $input) {
    success
    comment { id body createdAt }
  }
}
```
variables:
```json
{ "input": { "issueId": "issue-uuid", "body": "コメント内容" } }
```

## ページネーション

```graphql
query($after: String) {
  issues(first: 50, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { identifier title }
  }
}
```

次ページ取得時は `endCursor` を `$after` に渡す。

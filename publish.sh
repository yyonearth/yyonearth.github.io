#!/usr/bin/env bash
# 一键发布博客：提交本地改动 → 推送到 main → 等待并报告 GitHub Pages 部署结果
#
# 用法：
#   ./publish.sh                 # 用默认提交信息（带时间戳）发布
#   ./publish.sh "新增文章:xxx"   # 自定义提交信息
#
# 说明：本机在 Visa 内网，调 GitHub API 需走代理；脚本已内置。
# token 在运行时从 git 凭证缓存临时读取，不会写进文件。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

PROXY="http://userproxy.visa.com:80"
OWNER_REPO="yyonearth/yyonearth.github.io"
SITE_URL="https://yyonearth.github.io/"

# 1) 提交信息
MSG="${1:-Update site: $(date '+%Y-%m-%d %H:%M')}"

# 2) 有改动才提交
if [[ -z "$(git status --porcelain)" ]]; then
  echo "⚠️  没有检测到改动，无需提交。"
else
  echo "📦 提交改动：$MSG"
  git add -A
  git commit -m "$MSG"
fi

# 3) 推送（git 已配置走 Visa 代理）
echo "🚀 推送到 main ..."
git push origin main

# 4) 取 token + 查最新一次构建/部署结果
TOK="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')"
if [[ -z "$TOK" ]]; then
  echo "ℹ️  未取到 GitHub token，跳过部署状态查询。请稍后用浏览器确认：$SITE_URL"
  exit 0
fi

api() { curl -s -x "$PROXY" -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github+json" "$@"; }

echo "⏳ 等待 GitHub Actions 部署（最多约 3 分钟）..."
RUN_ID=""
for i in $(seq 1 18); do
  sleep 10
  RUN_ID="$(api "https://api.github.com/repos/$OWNER_REPO/actions/runs?branch=main&per_page=1" \
    | python -c "import sys,json;r=json.load(sys.stdin)['workflow_runs'];print(r[0]['id'] if r else '')" 2>/dev/null || true)"
  [[ -z "$RUN_ID" ]] && continue
  read -r STATUS CONCL < <(api "https://api.github.com/repos/$OWNER_REPO/actions/runs/$RUN_ID" \
    | python -c "import sys,json;r=json.load(sys.stdin);print(r['status'], r['conclusion'])" 2>/dev/null || echo "unknown unknown")
  printf "   [%02d] status=%s conclusion=%s\n" "$i" "$STATUS" "$CONCL"
  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCL" == "success" ]]; then
      echo "✅ 部署成功！线上地址：$SITE_URL"
      echo "   （内网可能打不开，请用手机/非内网浏览器确认）"
    else
      echo "❌ 构建失败（conclusion=$CONCL）。查看日志："
      echo "   https://github.com/$OWNER_REPO/actions/runs/$RUN_ID"
    fi
    exit 0
  fi
done

echo "⌛ 等待超时，构建可能仍在进行。手动查看："
echo "   https://github.com/$OWNER_REPO/actions"

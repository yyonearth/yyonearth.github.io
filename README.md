# yyonearth.github.io

yuyu 的个人技术博客,基于 [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) 主题,通过 GitHub Actions 构建并部署到 GitHub Pages。

🔗 在线地址:<https://yyonearth.github.io>

## 写新文章

在 `_posts/` 下新建 `YYYY-MM-DD-标题.md`,文件开头加 front matter:

```markdown
---
title: "文章标题"
date: 2026-06-02 12:00:00 +0800
categories: [分类]
tags: [标签1, 标签2]
---

正文……
```

提交并推送到 `main` 分支后,Actions 会自动重新构建上线。

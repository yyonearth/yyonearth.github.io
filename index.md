 ---
  layout: home
  title: 首页
  ---

  # 你好,欢迎

  这里是我的技术博客,主要写数据科学、AI 落地、SQL/数据工程相关的实践和踩坑笔记。

  ## 最近文章

  {% for post in site.posts %}
  - [{{ post.title }}]({{ post.url }}) — {{ post.date | date: "%Y-%m-%d" }}
  {% endfor %}

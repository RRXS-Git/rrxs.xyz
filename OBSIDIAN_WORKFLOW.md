# Obsidian 与 RRXS.xyz 网站工作流程指南

## 📁 目录结构

```
src/content/
├── blog/           # 综合博客文章
├── ai-learning/    # AI学习相关内容
├── life/          # 心灵生活内容
├── business/      # 商务洞察内容
└── config.ts      # 内容配置文件
```

## ✍️ Obsidian 写作工作流

### 1. 在 Obsidian 中创建新笔记

在你的 Obsidian vault 中，为每个类别创建对应的文件夹结构，然后将笔记保存到正确的位置。

### 2. 文章 Frontmatter 模板

每篇文章都需要在顶部添加 YAML frontmatter：

#### 博客文章模板 (blog/)
```markdown
---
title: "文章标题"
description: "文章简短描述"
pubDate: 2025-09-13
updatedDate: 2025-09-13
heroImage: "/images/hero-image.jpg"
tags: ["标签1", "标签2"]
category: "ai-learning" # ai-learning, life, business, tech
featured: true
draft: false
---

# 你的内容开始

正文内容...
```

#### AI学习文章模板 (ai-learning/)
```markdown
---
title: "AI学习主题"
description: "学习内容描述"
pubDate: 2025-09-13
heroImage: "/images/ai-hero.jpg"
tags: ["AI", "机器学习"]
level: "beginner" # beginner, intermediate, advanced
tools: ["Python", "TensorFlow"]
---

# AI学习内容

详细的学习笔记...
```

#### 心灵生活文章模板 (life/)
```markdown
---
title: "生活感悟标题"
description: "感悟描述"
pubDate: 2025-09-13
heroImage: "/images/life-hero.jpg"
tags: ["成长", "思考"]
mood: "inspiring" # inspiring, reflective, motivational, peaceful
---

# 心灵分享

你的生活感悟...
```

#### 商务洞察文章模板 (business/)
```markdown
---
title: "商务策略标题"
description: "策略分析描述"
pubDate: 2025-09-13
heroImage: "/images/business-hero.jpg"
tags: ["策略", "营销"]
type: "strategy" # strategy, marketing, investment, startup
industry: "科技"
---

# 商务分析

详细的商业洞察...
```

## 🔄 同步到网站

### 方法1: 直接同步 (推荐)
1. 将 Obsidian vault 设置为你的 `src/content/` 目录
2. 在 Obsidian 中直接编辑文件
3. 使用 Git 提交并推送更改

### 方法2: 复制同步
1. 在 Obsidian 中编写内容
2. 复制到对应的 `src/content/` 子目录
3. 使用 Git 提交并推送

### 自动化命令
```bash
# 进入项目目录
cd "D:/OneDrive_RRXS/OneDrive/__RRXS_XYZ/home/ubuntu/rrxs.xyz"

# 查看更改
git status

# 添加新文件
git add src/content/

# 提交更改
git commit -m "添加新内容: [文章标题]"

# 推送到 GitHub (触发 Vercel 自动部署)
git push origin main
```

## 🎨 图片资源管理

### 图片存储位置
- 将图片放在 `public/images/` 目录下
- 在 frontmatter 中引用: `/images/your-image.jpg`

### 推荐图片规格
- Hero 图片: 1200x600px
- 文章内图片: 800x400px
- 格式: JPG/PNG/WebP

## 🚀 发布流程

1. **写作**: 在 Obsidian 中创建新笔记
2. **编辑**: 添加正确的 frontmatter
3. **预览**: 本地运行 `npm run dev` 预览
4. **同步**: 复制到 `src/content/` 对应目录
5. **提交**: Git add, commit, push
6. **部署**: Vercel 自动部署 (2-3分钟)

## 🔧 高级功能

### 草稿功能
在 frontmatter 中设置 `draft: true` 来标记草稿，这些文章不会在生产环境显示。

### 特色文章
设置 `featured: true` 来标记重要文章，可以在首页或特殊位置展示。

### 标签系统
使用一致的标签来帮助文章分类和搜索：
- AI相关: "AI", "机器学习", "深度学习", "ChatGPT"
- 生活相关: "成长", "思考", "感悟", "生活"
- 商务相关: "策略", "营销", "投资", "创业"

## 📊 网站访问

- **开发环境**: http://localhost:4321
- **生产环境**: https://rrxs.xyz
- **Vercel 面板**: https://vercel.com/dashboard

## ⚡ 快速开始

1. 打开 Obsidian
2. 选择对应分类目录
3. 创建新笔记
4. 复制对应模板的 frontmatter
5. 编写内容
6. 保存并同步到网站

现在你可以开始使用这个强大的内容管理系统了！
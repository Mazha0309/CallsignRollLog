# 官网（`site/`）

`CRL · Callsign Roll Log · 呼号点名日志` 的产品主页。**纯静态、零构建、零依赖**（只有 `index.html` 与几个图片资源：`icon.png`、`wechat-zjra.svg` 公众号二维码），因此 GitHub Pages / Cloudflare Pages / Vercel 都能直接托管。

计划绑定域名：`crl.mazha0309.com`（主域子域，不额外购买）。

## 本地预览

```bash
# 任选其一
python3 -m http.server 8080 --directory site
npx serve site
```

打开 <http://localhost:8080>。

## 部署

### GitHub Pages（Actions，发布 `site/` 的公开文件）

`main` 上改动 `site/` 或 `.github/workflows/pages.yml` 时，`.github/workflows/pages.yml` 把 `index.html`、`icon.png`、`wechat-zjra.svg` 发布到 GitHub Pages。分支部署只接受仓库根目录或 `/docs`，不能直接选 `/site`。

### Cloudflare Pages

- Framework preset：`None`
- Build command：留空
- Build output directory：`site`

### Vercel

- Framework preset：`Other`
- Root directory：`site`
- Build command：留空，Output directory：`.`

## 绑定 `crl.mazha0309.com`

平台后台添加自定义域名后，按提示在 DNS 添加记录：

- Cloudflare Pages：项目里加 `crl` 子域（主域已在 Cloudflare 时自动建记录）。
- Vercel：`CNAME crl → cname.vercel-dns.com`
- GitHub Pages：`CNAME crl → <用户名>.github.io`，并在 `site/` 放一个内容为 `crl.mazha0309.com` 的 `CNAME` 文件。

## 维护约定

- 页面第一屏必须同时出现 **CRL / Callsign Roll Log / 呼号点名日志**；不要把裸 `CRL` 或裸域名当作品牌。
- 功能与下载文案以 `README.md` 为准。**版本号与下载表由页面实时读取 GitHub Releases API**（`releases/latest`）生成；API 不可达时自动回退到静态表格，不会空白。
- 设计令牌对齐 App（`lib/theme/app_theme.dart`）：蓝色 seed `#2196F3`、圆角 12/16、间距 4/8/12/16/24/32、内容宽 1120、控件高 40。首屏示例是按 `lib/widgets/log_table.dart` 的真实列名还原的，不是凭空画的。
- 字体全部自托管在 `fonts/`，页面不请求 Google Fonts。中文主字体为更纱黑体 SC，西文与等宽为 `IBM Plex Sans` / `IBM Plex Mono`，Live Share 示例另用 `Inter`。清单、许可与更纱黑体子集的重生成方式见 `fonts/NOTICE.md`；**新增汉字段落后若有个别字明显是另一种字体，重跑 `python3 site/tools/subset-sarasa.py`**。
- 因为要访问 `api.github.com`，站点**不要**加严格的 `connect-src` CSP；若必须加，请白名单 `https://api.github.com`。

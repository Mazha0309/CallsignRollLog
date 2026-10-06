# 官网（`site/`）

`CRL · Callsign Roll Log · 呼号点名日志` 的产品主页。**纯静态、零构建、零依赖**（仅一个 `index.html` + `logo.svg`），因此 GitHub Pages / Cloudflare Pages / Vercel 都能直接托管。

计划绑定域名：`crl.mazha0309.com`（主域子域，不额外购买）。

## 本地预览

```bash
# 任选其一
python3 -m http.server 8080 --directory site
npx serve site
```

打开 <http://localhost:8080>。

## 部署

### GitHub Pages（从 `main` 的 `/site` 目录）

仓库 Settings → Pages → Source 选 `Deploy from a branch`，分支 `main`、目录 `/site`。

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
- 字体走 Google Fonts（`Saira` 标题 + `IBM Plex Sans` 正文 + `IBM Plex Mono` 数据/标签）。失效时回退系统中文字体，不影响可读性；要离线或国内加速可把字体自托管到本目录并改 `<link>`。
- 因为要访问 `api.github.com`，站点**不要**加严格的 `connect-src` CSP；若必须加，请白名单 `https://api.github.com`。

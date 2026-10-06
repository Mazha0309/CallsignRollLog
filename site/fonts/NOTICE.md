# `site/fonts/` 字体清单

官网的字体全部自托管在本目录，页面不再请求 `fonts.googleapis.com`（该域名在国内不可达，且外链样式表会阻塞首屏渲染）。

## 文件

| 文件 | 字体 | 字重 | 来源 | 许可 |
| --- | --- | --- | --- | --- |
| `sarasa-gothic-sc-400.woff2` | 更纱黑体 SC / Sarasa Gothic SC | 400（同时供 500） | [be5invis/Sarasa-Gothic](https://github.com/be5invis/Sarasa-Gothic)，取本机 `Sarasa-Regular.ttc` 的 `Sarasa Gothic SC` 字面后做子集 | SIL OFL 1.1 |
| `sarasa-gothic-sc-700.woff2` | 更纱黑体 SC / Sarasa Gothic SC | 700（同时供 600、800、900） | 同上，取 `Sarasa-Bold.ttc` | SIL OFL 1.1 |
| `plex-sans-400/500/600/700.woff2` | IBM Plex Sans | 400 / 500 / 600 / 700 | [`@fontsource/ibm-plex-sans`](https://www.npmjs.com/package/@fontsource/ibm-plex-sans)，仅 latin 子集 | SIL OFL 1.1 |
| `plex-mono-400/500/600.woff2` | IBM Plex Mono | 400 / 500 / 600 | [`@fontsource/ibm-plex-mono`](https://www.npmjs.com/package/@fontsource/ibm-plex-mono)，仅 latin 子集 | SIL OFL 1.1 |
| `inter-400/500/600/700.woff2` | Inter | 400 / 500 / 600 / 700 | [`@fontsource/inter`](https://www.npmjs.com/package/@fontsource/inter)，仅 latin 子集 | SIL OFL 1.1 |

合计约 608 KB。完整许可文本见 `OFL.txt`。

## 排版约定

`--sans` 与 `--mono` 都把西文放在更纱黑体之前：

```
"IBM Plex Sans","Sarasa Gothic SC",…      /* 拉丁字母走 Plex，汉字走更纱黑体 */
"IBM Plex Mono","Sarasa Gothic SC",…      /* 等宽同理 */
```

IBM Plex 不含汉字，因此汉字会落到下一个真正含该字形的更纱黑体；两者之后的系统字体（PingFang SC / Microsoft YaHei / Noto Sans SC）只作为兜底。

## 更纱黑体是子集，改动文案后需要重生成

更纱黑体全量约 80 MB，不能直接放进仓库，因此这里只保留站点用得到的字形。子集范围 = 首页正文、标题、以及 `aria-label` / `title` / `alt` 属性的用字，并上 `lib/l10n/app_zh.arb`、`README.md`、`site/README.md` 的汉字并集（当前 910 字，其中汉字 776）。

**新增汉字段落后，如果出现「个别字明显是另一种字体」，就是该字不在子集里**，此时重跑：

```bash
python3 site/tools/subset-sarasa.py
```

脚本默认读取本机的 `/usr/local/share/fonts/Sarasa-TTC-1.0.34/`，路径不同时用 `--sarasa-dir` 指定。它需要 `fonttools`（含 `brotli`）。

西文三个家族是官方 woff2，不需要重新生成；只有升级字体版本时才替换，来源为：

```bash
npm pack @fontsource/ibm-plex-sans @fontsource/ibm-plex-mono @fontsource/inter
# 解包后取 files/*-latin-{字重}-normal.woff2
```

## 新增字重时注意

更纱黑体目前只提供 400 与 700 两份。`index.html` 中 500 指向 400 的文件，600/800/900 指向 700 的文件，浏览器取最接近的字面，不做合成加粗。若某处必须用真正的 600，需要重新生成对应文件并在 `@font-face` 中登记。

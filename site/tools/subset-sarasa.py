#!/usr/bin/env python3
"""重新生成官网用的更纱黑体（Sarasa Gothic SC）子集。

首页的汉字不是固定的：新增文案后如果出现个别字回退到系统字体，就是它不在
子集里，重跑本脚本即可。子集范围 = 首页正文/标题用字 ∪ 项目词表用字。

依赖：fonttools（需带 brotli 支持，否则无法输出 woff2）。
用法：
    python3 site/tools/subset-sarasa.py
    python3 site/tools/subset-sarasa.py --sarasa-dir /path/to/Sarasa-TTC-1.0.34
"""

import argparse
import html
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
FONTS = SITE / "fonts"

# 与 @font-face 中登记的档位一致：常规供 400/500，粗体供 600/700/800/900
WEIGHTS = [
    ("Sarasa-Regular.ttc", "sarasa-gothic-sc-400.woff2"),
    ("Sarasa-Bold.ttc", "sarasa-gothic-sc-700.woff2"),
]

# 除首页之外，再取项目自身的词表，给日后的文案改动留余量
CORPUS = [
    ROOT / "lib/l10n/app_zh.arb",
    ROOT / "README.md",
    SITE / "README.md",
]

# 子集里始终带上 ASCII 与常见标点，避免拉丁字符缺失时回落到别的字体
PUNCTUATION = "、。，：；！？（）【】《》〈〉「」『』“”‘’—…·×÷±°％＋－＝／＼～　"


def visible_text(path):
    """取 <style>/<script> 之外的渲染文本，外加 <title> 与各属性的值。

    属性值（aria-label / title / alt）不会画出来，但一并纳入子集，
    避免无障碍标签里出现回退字体。
    """
    raw = path.read_text(encoding="utf-8")
    body = re.sub(r"<style[\s\S]*?</style>", "", raw)
    body = re.sub(r"<script[\s\S]*?</script>", "", body)
    attributes = " ".join(re.findall(r'="([^"]*)"', body))
    body = re.sub(r"<[^>]+>", "", body)
    text = html.unescape(body + " " + attributes)
    title = re.search(r"<title>(.*?)</title>", raw, re.S)
    return text + (title.group(1) if title else "")


def build_charset():
    chars = set(visible_text(SITE / "index.html"))
    for path in CORPUS:
        if path.exists():
            chars |= set(path.read_text(encoding="utf-8"))
    chars |= set(chr(c) for c in range(0x20, 0x7F))
    chars |= set(PUNCTUATION)
    chars = {c for c in chars if not c.isspace()}
    return "".join(sorted(chars))


def face_number(ttc, wanted):
    """在 TTC 中找出 Sarasa Gothic SC 的字面序号。"""
    from fontTools.ttLib import TTCollection

    collection = TTCollection(str(ttc), lazy=True)
    for index, font in enumerate(collection.fonts):
        if font["name"].getDebugName(1) == wanted:
            return index
    raise SystemExit("在 %s 中找不到字面 %s" % (ttc, wanted))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sarasa-dir",
        default="/usr/local/share/fonts/Sarasa-TTC-1.0.34",
        help="存放 Sarasa-*.ttc 的目录",
    )
    args = parser.parse_args()

    sarasa_dir = pathlib.Path(args.sarasa_dir)
    charset = build_charset()
    cjk = sum(1 for c in charset if "\u4e00" <= c <= "\u9fff")
    print("子集字符数 %d（其中汉字 %d）" % (len(charset), cjk))

    FONTS.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", suffix=".txt", delete=False
    ) as handle:
        handle.write(charset)
        text_file = handle.name

    try:
        for source, target in WEIGHTS:
            ttc = sarasa_dir / source
            if not ttc.exists():
                raise SystemExit("缺少字体文件 %s" % ttc)
            index = face_number(ttc, "Sarasa Gothic SC")
            out = FONTS / target
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "fontTools.subset",
                    str(ttc),
                    "--font-number=%d" % index,
                    "--text-file=%s" % text_file,
                    "--flavor=woff2",
                    "--output-file=%s" % out,
                ],
                check=True,
            )
            print("  %-32s %6.1f KB" % (target, out.stat().st_size / 1024))
    finally:
        pathlib.Path(text_file).unlink(missing_ok=True)

    if shutil.which("git"):
        print("\n完成。提交前请确认 site/fonts/NOTICE.md 中的体积说明仍然成立。")


if __name__ == "__main__":
    main()

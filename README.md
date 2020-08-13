# hatena-blog-to-hugo
はてなブログのMTファイルを静的Web生成ツールHugo用データに変換

# Motivation
はてなブログからHugoに引っ越すのに際し、はてなブログ時代のデータをHugoの形式に移行する必要が出てきた。はてなブログのエクスポート機能はMTフォーマットにしか対応しておらず自作する必要あり

# Target Hugo Theme
[tranquilpeak](https://github.com/kakawait/hugo-tranquilpeak-theme)

# Usage
ruby hb2h.rb example.hatenablog.com.export.txt

# Process

example.hatenablog.com.export.txtを読み込んで

```
AUTHOR: insaneway
TITLE: aaaaaaaa test
BASENAME: aaa
STATUS: Publish
ALLOW COMMENTS: 0
CONVERT BREAKS: 0
DATE: 08/10/2020 00:11:33
CATEGORY: Vocabulary
IMAGE: https://cdn-ak.f.st-hatena.com/images/fotolife/i/insaneway/20200710/20200710000151.jpg
-----
BODY:
<p>あああ</p>
<p>テスト</p>
<p>ううう</p>
-----
EXCERPT:
抜粋が入る
-----
--------
AUTHOR: insaneway
TITLE: bbbbbbbbb test
BASENAME: bbb
STATUS: Publish
ALLOW COMMENTS: 0
CONVERT BREAKS: 0
...
...
...
```

entryディレクトリ内に

```
entry
├── aaa.html
├─── bbb.html
...
...
...
```

を作る。

このentryディレクトリをHugoのcontentディレクトリに入れれば基本はOK（ディレクトリ名などは当然選択したテーマに依存）

# Reference
+ https://www.serendipity.page/b/2020/07/hatena-migration1/
+ https://www.serendipity.page/b/2020/07/hatena-migration2/ （予定）

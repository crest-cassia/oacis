# 開発環境構築

github pagesを利用してページをレンダリングしている。github-pagesではserver側でjekyllを使ってページをレンダリングしている。

手元でレンダリングして結果を確認したい場合はbundle installで必要なgemをインストール後、
```
bundle exec jekyll serve -w --baseurl ''
```
でサーバーを起動すると、localhost:4000 でアクセスできる。

python2系に依存している。"Liquid Exception: Failed to get header." というメッセージがでた場合はpythonのバージョンを確認のこと。


==========================================
Installation
==========================================

ここではCASSIA Managerのセットアップ方法について説明する。

Supported platforms
=================

サポートされるプラットフォームは以下の通り。

- Linux, Mac OSXなどのUnix系OS

  - Mac OS 10.8, Ubuntu, CentOSで動作実績あり。

- Google Chrome または Firefox

  - (IEでの挙動は未確認)

- bash （計算ホスト側）

Pre-requisites
===================

CMを動かすサーバーでは事前に以下のものをインストールする必要がある。

- Ruby 1.9.3
- bundler (http://bundler.io/)
- MongoDB 2.4以上 (http://www.mongodb.org/)
- Redis 2.6以上 (http://redis.io/)

以下ではこれらのものがインストールされている前提で説明する。

Installation
====================

まずRailsのインストールを行う。
CMのソースコードをチェックアウトしたディレクトリで ::

  bundle install --binstubs --path=vendor/bundle

を行う。

ここでRailsを起動してみる ::

  bundle exec rails s

http://localhost:3000 にアクセスし、ページが適切に表示されればインストールは成功している。
もし失敗した場合は、MongoDB, Redisが正しく起動しているか、ファイアウォールは3000番に対して開いているか、gemは正しくインストールされたか、などを確認する。
停止する場合は Ctrl-C を押す。

Launch Rails and Workers
=================

Railsおよびworkerの起動は以下のコマンドを実行する。 ::

  bundle exec rails s -d
  bundle exec rake resque:scheduler PIDFILE=./tmp/pids/resque_scheduler.pid BACKGROUND=yes
  bundle exec rake resque:work QUEUE='*' VERBOSE=1 PIDFILE=./tmp/pids/resque.pid BACKGROUND=yes

Process IDを記述したファイルが、tmp/pids 以下に作成される。

プロセスの停止は以下のコマンドを実行する ::

  kill -INT $(cat tmp/pids/server.pid)
  kill -QUIT $(cat tmp/pids/resque_scheduler.pid) && rm tmp/pids/resque_scheduler.pid
  kill -QUIT $(cat tmp/pids/resque.pid) && rm tmp/pids/resque.pid

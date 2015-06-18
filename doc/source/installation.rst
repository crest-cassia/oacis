==========================================
インストール
==========================================

ここではセットアップ方法について説明する。

サポートされるプラットフォーム
==================================

サポートされるプラットフォームは以下の通り。

- サーバー
    - Linux, Mac OSXなどのUnix系OS
        - Mac OS 10.8, Ubuntu, CentOSで動作実績あり
- 計算ホスト
    - Linux, Mac OSXなどのUnix系OS
        - Mac OS 10.8, Ubuntu, CentOSで動作実績あり
        - bash がインストールされていること
        - sshの鍵認証でログインできること
        - xsub (https://github.com/crest-cassia/xsub) がインストールされていること
- クライアント
    - Google Chrome および Firefox でテストされている
        - (IEでの挙動は未確認)

前提条件
==================================

サーバーでは事前に以下のものをインストールする必要がある。

- Ruby 1.9.3
- bundler (http://bundler.io/)
- MongoDB 2.4以上 (http://www.mongodb.org/)

| Rubyのインストールにはrbenvまたはrvmを使って環境を整えると良い。
| Mac OS Xの場合、homebrew (http://brew.sh/) を使ってインストールするのが手軽で良い。
| Linuxの場合、yumやaptコマンドを使ってインストールできる。

| 以下のコマンドでRubyのバージョン、bundlerのインストール、MongoDBのバージョン、MongoDBのデーモンが起動していることを確認する事ができる。

::

  ${OACIS_PROJECT_ROOT}/bin/check_oacis_env

| もしエラーが起きた場合は、以下のコマンドで手動で確認し必要なソフトウェアをインストールすること。
| インストール(PATH)の確認

::

  which ruby(mongod)

バージョンの確認

::

  ruby(mongod) --version

| OACISは各利用者が自分のPCにインストールし、イントラネット内で使用されることを想定している。
| インターネット上へ公開し不特定多数のアクセスを受け付ける場合は、ここで記述したセットアップに加えてセキュリティーや不可分散の対策を十分に行う必要がある。
| ファイアウォールなどのネットワークセキュリティおよびRailsの知識が十分ある方以外は推奨しない。

インストール
===================================

まず手元にOACISのソースコード一式をダウンロードする。

次にRailsおよび関連gemのインストールを行う。ダウンロードしたディレクトリ内に移動し、 ::

  bundle install --path=vendor/bundle

| を実行する。
| 成功すればこの時点でRailsを起動できる。試しに以下のコマンドで起動する。

  bundle exec rails s

| http://localhost:3000 にアクセスし、ページが適切に表示されればインストールは成功している。
| 端末で Ctrl-C を押し、Railsを停止させる。
| もし失敗した場合は、MongoDBが正しく起動しているか、ファイアウォールは3000番に対して開いているか、gemは正しくインストールされたか、などを確認する。

RailsおよびWorkerの起動
========================================

Railsおよびworkerの起動は以下のコマンドを実行する。 ::

  bundle exec rake daemon:start

http://localhost:3000 にアクセスできればRailsの起動が成功している。
またWorkerプロセスが起動しているかどうかは http://localhost:3000/runs にアクセスすれば確認できる。
Workerが起動していない場合にはエラーメッセージが表示される。

これらのプロセスの再起動、および停止は以下のコマンドで実行できる。 ::

  bundle exec rake daemon:restart
  bundle exec rake daemon:stop

Firewallの設定
========================================

| 現状のOACISはユーザー管理機能を持っていないため、ネットワーク内の任意のホストからアクセス可能である。
| 他のホストからのアクセスを制限するためにはファイアウォールを設定するのが最も簡単である。
| デフォルトではRailsは3000番、MongoDBは27017番のポートをそれぞれ使用しているので、これらのポートへのアクセスを限定する。

| 運用時はローカルホストのみに限定することが推奨される。
| その場合でもsshポートフォワーディングを使用する事で、別の端末からOACISにアクセスすることが可能である。
| OACISを server.example.com で起動している場合、

  ssh -N -f -L 3000:localhost:3000 server.example.com

| を実行すると localhost:3000 でOACISにアクセスできるようになる。

パスワードの設定
========================================

| Digest認証に使用するパスワードを設定することも可能である。
| config/user_config.yml ファイルに以下のように記述してOACISを起動する。
| サンプルが config/user_config.sample.yml にあるので参考にしてほしい。(username, passwordは適宜変更すること)

.. code-block:: yaml

  ---
  authentication: {username: password}
  auto_reload_tables: false

| これでページにアクセスした際にユーザー認証が要求されるようになる。
| auto_reload_tables をfalseにすると、テーブルが自動的に更新されなくなる。ユーザー認証をつけている環境ではfalseにしておいたほうが良い。

データベースの変更
========================================

デフォルトではローカルのデータベースにアクセスするが、他のホストのデータベースを参照する事も可能である。
config/mongoid.yml の中でMongoDBへの接続情報を設定しているので、これを変更してRailsおよびWorkerを再起動する。

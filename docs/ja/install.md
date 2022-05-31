---
layout: default
title: "インストール"
lang: ja
next_page: tutorial
---

# インストール方法

OACISを利用するには

- (1)OACISのセットアップ
- (2)計算ホストのセットアップ

の両方を行う必要があります。

OACISをインストールするには、

- (1.1)仮想環境を使う方法
- (1.2)手動で環境構築する方法


の２種類があります。

Windowsの方は(1.1)を選択してください。Unix系OS(Linux,Mac)の場合にはどちらの方法によっても環境構築ができます。
初めての方はセットアップが容易な仮想環境を推奨します。仮想環境の場合、次ページのチュートリアルがすぐに始められます。
より本格的に運用したい場合は(1.2)の方法に移行するのがよいでしょう。

ここではそれぞれのセットアップ方法を解説します。

---

## (1.1) 仮想環境を使ったOACISのインストール

[Docker](https://www.docker.com/)というツールを使ってOACISがインストールされた仮想環境を手軽に導入することができます。
Linuxだけでなく、Windows、MacOSにも導入することができます。
手順の概要は以下の通りです。

インストール手順は[oacis_docker](https://github.com/crest-cassia/oacis_docker)のREADMEを参照してください。
**oacis_docker**はOACISのDockerイメージを作成するプロジェクトです。
ここで作成されているイメージには、次ページのチュートリアルのStep1までが実行済みの状態で保存されています。

## (1.2) 手動でのOACISのインストール

### 対象プラットフォーム

- OACIS
    - Unix系OS。Mac OS X, Ubuntu, and CentOS などで稼働実績あり
    - Windowsはサポート対象外。Cygwinもサポートされない。Windowsユーザーは仮想環境を導入する必要がある。
- 計算ホスト
    - 同様にbashが起動するUnix系OSでなくてはならない。こちらはcygwinも可。
- ブラウザ
    - Google Chrome, Firefox, Safari。IEでの挙動は未確認。

### 前提条件

- Ruby 2.5.1以降 ([https://www.ruby-lang.org/](https://www.ruby-lang.org/))
- MongoDB 3.6以降 ([http://www.mongodb.org/](http://www.mongodb.org/))
- bundler ([http://bundler.io/](http://bundler.io/))
    - Ruby2.6.0以降を利用する場合は、標準ライブラリとして添付されるので個別にインストールする必要はない。
- redis ([https://redis.io/](https://redis.io/))

Rubyのインストールにはrbenvまたはrvmを使って環境を整えるのがよいです。

Mac OS Xの場合、homebrew ([http://brew.sh/](http://brew.sh/)) を使ってrbenvとMongoDBをインストールするのが手軽です。
Linuxの場合、yumやaptコマンドを使ってインストールできます。

#### MacOSXでの前提条件の整え方

ここではhomebrewを用いてセットアップしていきます。

- rbenvのインストール
    - [公式ドキュメント](https://github.com/rbenv/rbenv#homebrew-on-macos)の手順に従う
- rbenvを用いてrubyをインストール（以下は2.7.5をインストールする場合）
    ``` sh
    rbenv install 2.7.5 && rbenv global 2.7.5
    rbenv rehash
    ruby --version
    ```
    を実行して、`ruby 2.7.5....`と出力されれば成功
- mongoDBをインストール
    - [公式ドキュメント](https://docs.mongodb.com/manual/tutorial/install-mongodb-on-os-x/)の手順に従う
      - インストール後、macOSのサービスとして起動(`brew services start mongodb-community`)すれば、以後ログイン時にmongodが自動的に起動するようになる
- bundlerのインストールと最新版への更新
    ``` sh
    gem install bundler
    gem update bundler
    rbenv rehash
    ```
    `which bundle`を実行しコマンドへのパスが表示されればインストールに成功している
- redisのインストール
    ``` sh
    brew install redis
    brew services start redis
    ```


#### Linuxでの前提条件の整え方
ここではUbuntu 14.04を例に取り、apt-getを用いてセットアップしていきます。

- 前提環境(必要コマンド)の構築
    ``` sh
    sudo apt-get update
    sudo apt-get install -y git build-essential wget libssl-dev libreadline-dev zlib1g-dev
    ```
- rbenvのインストール
    - [公式ドキュメント](https://github.com/rbenv/rbenv#installation)の手順に従う
- rbenvを用いてrubyをインストール（以下は2.7.5をインストールする場合）
    ``` sh
    rbenv install 2.7.5 && rbenv global 2.7.5
    rbenv rehash
    ruby --version
    ```
    を実行して、`ruby 2.7.5....`と出力されれば成功
- mongoDBをインストール
    - [公式ドキュメント](https://docs.mongodb.com/manual/administration/install-on-linux/)の手順に従う
- bundlerのインストールと最新版への更新
    ``` sh
    gem install bundler
    gem update bundler
    rbenv rehash
    ```
    `which bundle`を実行しコマンドへのパスが表示されればインストールに成功している
- redisのインストール
    ``` sh
    sudo apt-get install redis
    service redis-server start
    ```

### インストール・railsの起動チェック

まず手元にOACISのソースコード一式をgit cloneします。（gitがない場合はダウンロードします。）

```shell
git clone --recursive -b master https://github.com/crest-cassia/oacis.git
```

クローンしたディレクトリに移動し、以下のコマンドを実行するとRubyのバージョン、bundlerのインストール、MongoDBのバージョン、MongoDBのデーモンが起動していることを確認する事ができます。

```shell
./bin/check_oacis_env
```

次にRailsおよび関連gemのインストールを行います。ダウンロードしたディレクトリ内に移動し、

```shell
bundle install
```

を実行します。

成功すればこの時点でRailsを起動できます。試しに以下のコマンドで起動します。

```shell
bundle exec rails s
```
[localhost:3000](http://localhost:3000) にアクセスし、ページが適切に表示されればインストールは成功しています。
端末で Ctrl-C を押し、Railsを停止します。
もし失敗した場合は、MongoDBが正しく起動しているか、gemは正しくインストールされたか、などを確認してください。

### 起動

Railsおよびworkerの起動は以下のコマンドを実行します。

```shell
bundle exec rake daemon:start
```
[localhost:3000](http://localhost:3000) にアクセスできればRailsの起動が成功しています。
またWorkerプロセスが起動しているかどうかは [localhost:3000/runs](http://localhost:3000/runs) にアクセスすれば確認できます。
Workerが起動していない場合にはエラーメッセージが表示されます。

これらのプロセスの再起動、および停止は以下のコマンドで実行できます。

```shell
bundle exec rake daemon:restart
bundle exec rake daemon:stop
```

{% capture tips %}
ジョブを投入後、全てのジョブが完了していなくてもOACISを停止することは可能です。
OACISが停止している間も実行中のジョブは計算ホストでそのまま動き続けます。次にOACISが起動したタイミングで完了したジョブがデータベースに取り込まれます。
{% endcapture %}{% include tips %}


## (2) 計算ホストのセットアップ

**チュートリアル実行用の仮想環境を利用する場合はこのステップは不要です。仮想環境をジョブ実行用のリモートホストとしても利用します。**

ジョブ実行用のホストは以下の手順でセットアップします。以後、OACISを実行しているホストを「OACISホスト」、ジョブを実行するホストを「計算ホスト」と呼ぶことにします。
![OACISホストと計算ホスト]({{ site.baseurl }}/images/SSH_connection.png){:width="600px"}

1. (OACISホストにて) OACISホストから鍵認証でSSH接続できるようにセットアップする。
    - `ssh-keygen -t rsa` を実行し、SSH認証用の鍵を作成する。
        - パスフレーズは自分で適当なものを設定します。
        - このコマンドにより秘密鍵、公開鍵がそれぞれ `~/.ssh/id_rsa`, `~/.ssh/id_rsa.pub` に作成されます。
    - 公開鍵をリモートホストに転送し、"authorized_keys"に追加する。
        - `ssh-copy-id`コマンドを使うと便利です。
    - `~/.ssh/config`ファイルを以下の形式で作成する。
      ```config
      Host my_host
        HostName 127.0.0.1
        Port 22
        User my_user
        IdentityFile ~/.ssh/id_rsa
      ```
      - `Host`には好きな名前を指定可能
      - `HostName`にリモートホストのアドレスを指定
      - `User`にはログインユーザ名を指定
      - `IdentityFile`には生成した秘密鍵を指定
      - OACIS v3より、IP・port・ユーザ名の指定はwebインターフェースを用いず、`~/.ssh/config`を参照する仕組みになりました。
    - 接続確認を行う。
        - `ssh my_host` でパスワードを使わずにログインできたら成功です。
            - 鍵作成時にパスフレーズを入力した場合は、ログイン時にパスフレーズの入力が要求されます。OACISの実行時にはパスワードもパスフレーズも入力せずにログインできるようにセットアップする必要があります。パスフレーズの入力を省略するには
                - (macOS Sierra以降の場合) `ssh-add ~/.ssh/id_rsa`を実行します。この際パスフレーズの入力を要求されますが、以降はパスフレーズの入力を省略できます。
                - (Linuxの場合) SSH Agentを利用します。以下のコマンドを入力してください。（これらのコマンドはシステムにログインするたびに実行する必要があります。）
                    - ``eval `ssh-agent` `` (SSH agentを起動する）
                    - `ssh-add ~/.ssh/id_rsa` （秘密鍵のパスを指定する。このときにパスフレーズの入力を要求されますが、以降はパスフレーズの入力を省略できます。
                    - さらに入力を簡便にするために[Keychain](http://www.funtoo.org/Keychain)というツールもあります。
2. (計算ホストにて) [xsub](https://github.com/crest-cassia/xsub) または [xsub_py](https://github.com/crest-cassia/xsub_py) を導入する。
    - xsubというのは、ジョブスケジューラの仕様の差異を吸収するスクリプトで、OACISはxsubコマンドを利用してジョブを投入します。
    - xsubの実行にはruby2.0以降が必要です。システムにインストールされていない場合はRubyもインストールしてください。
    - xsub_py はPythonで実装されたxsubコマンドで、Python 3.6以降が必要です。
    - 詳細は[xsubのREADME](https://github.com/crest-cassia/xsub/blob/master/README.md)または[xsub_pyのREADME](https://github.com/crest-cassia/xsub_py/blob/main/readme.md) を参照してください。
3. (OACISホストにて) 導入の確認
    - `ssh remotehost 'bash -l -c xstat'` を実行します。エラーメッセージが出ずに、リモートホストのステータスが表示されれば完了です。
        - もしSSH接続に失敗している場合は1の設定を見直します。
        - xsubコマンドが見つからないというエラーの場合は3の設定を確認してください。

## 注意点（(1.1)の場合も(1.2)の場合も共通）

OACISをインターネットに公開しないでください。
OACISは計算ホストとして登録したサーバー内で任意のコマンドを実行できるので、悪意のあるユーザーからアクセスされるとセキュリティホールになります。
各個人のマシン上で起動し、他の人からのアクセスを受け付けないようにして置く必要があります。

OACIS 2.11.0から、デフォルトで`127.0.0.1`のアドレスにバインドされる様になりました。他のマシンからはOACISにアクセスできません。
MongoDBもデフォルトでは`127.0.0.1`にバインドされるので、デフォルトで使っている限りさらに対策を行う必要はありません。
バージョン2.10以前のOACISを利用している場合は、ファイアウォールの設定を行い3000番ポートへのアクセスを制限してください。

Docker環境を使用している場合は、公開されたポートをローカルホストにバインドすることが望ましいです。こうすることにより他のホストからアクセスできなくなります。
`docker run`コマンドを実行する際に、`-p`オプションで`127.0.0.1`にバインドするようにしてください。

```shell
docker run -p 127.0.0.1:3000:3000 -dt oacis/oacis
```

外部からのアクセスを制限するとOACISの利便性が失われると心配かもしれませんが、このように設定しても外部からSSHのポートフォワーディングを利用することでOACISを使うことができます。
OACISを server.example.com で起動している場合、以下のコマンドを実行すると localhost:3000 でOACISにアクセスできるようになります。
（"server.example.com"をOACISが起動しているサーバーに置き換えて実行してください。）

```shell
ssh -N -f -L 3000:localhost:3000 server.example.com
```

# 更新

## OACISの更新
"oacis"ディレクトリで以下のコマンドを実行してください。

```
bundle exec rake daemon:stop            # tentatively stop OACIS
git pull origin master                  # get the latest source code of OACIS
git pull origin master --tags
git submodule update --init --recursive
gem update bundler                      # update bundler gem
bundle install                          # install dependency
bundle exec rake daemon:start           # restart OACIS
```


## OACIS v2からv3への更新
OACIS v3ではMongoDBをv3.6以降に、Rubyを2.5.1以降にアップデート、および新規にredisをインストールする必要があります。

#### MongoDBの更新

MongoDBをアップデートする際には2.6 -> 3.0 -> 3.2 -> 3.4といった段階的アップデートをしないとデータの互換性が維持されません。
ここでは一度に最新版に更新するため「OACISのデータのバックアップ」-> 「MongoDBを最新版に更新」-> 「OACISのデータのレストア」という手順で行うことを推奨します。
詳細は[公式ドキュメント](https://docs.mongodb.com/manual/tutorial/upgrade-revision/)を参照してください。

- データのバックアップ
``` sh
mongodump --db oacis_development #データをエクスポート
```
実行後、`dump/oacis_development`に結果が出力されていることを確認

- MongoDBの更新
    - [公式ドキュメント](https://docs.mongodb.com/manual/tutorial/upgrade-revision/) を参考に更新する
- データの書き戻し
``` sh
mongorestore --db oacis_development dump/oacis_development #データベースをインポート
```

#### SSH-configの編集

V3ではHostの設定項目から、"Hostname", "User", "Port", "IdentityFile"がなくなりました。代わりに"~/.ssh/config"ファイルにこれらの情報を記述してください。

#### OACISの再起動
``` sh
bundle install                          # install dependent libraries
bundle exec rake daemon:start           # restart OACIS
```

OACISのユーザーメーリングリストに登録することをお勧めします。新規リリースについての情報がメールで通知されます。
[oacis-users mailing list](https://groups.google.com/forum/#!forum/oacis-users)


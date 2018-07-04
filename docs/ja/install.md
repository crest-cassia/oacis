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

- Ruby 2.5.1 ([https://www.ruby-lang.org/](https://www.ruby-lang.org/))
- MongoDB 3.6 ([http://www.mongodb.org/](http://www.mongodb.org/))
- bundler ([http://bundler.io/](http://bundler.io/))
- redis ([https://redis.io/](https://redis.io/))

Rubyのインストールにはrbenvまたはrvmを使って環境を整えるのがよいです。

Mac OS Xの場合、homebrew ([http://brew.sh/](http://brew.sh/)) を使ってrbenvとMongoDBをインストールするのが手軽です。
Linuxの場合、yumやaptコマンドを使ってインストールできます。

#### MacOSXでの前提条件の整え方

ここではhomebrewを用いてセットアップしていきます。

- rbenvのインストール
    ``` sh
    brew install rbenv ruby-build
    echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc
    ```
- rbenvを用いてruby 2.5.1をインストール
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    ruby --version
    ```
    を実行して、`ruby 2.5.1....`と出力されれば成功
- mongoDBをインストール
    ``` sh
    brew install mongo #インストール
    brew services start mongodb #起動
    ```
    - `brew info mongo`コマンドを実行するとmongodを起動するコマンドが表示される。
    - コマンドを実行すると、以後ログイン時にmongodも自動的に起動する。
    - `mongo` コマンドを実行し端末が表示されれば成功。`exit`で端末から抜ける
- bundlerのインストール
    ``` sh
    gem install bundler
    which bundle
    ```
    でコマンドへのパスが表示されればインストールに成功
- redisのインストール
    ``` sh
    brew install redis
    brew services start redis
    ```


#### Linuxでの前提条件の整え方
ここではUbuntu 14.04を例に取り、apt-getを用いてセットアップしていきます。

従来よりOACISをご利用の方は末尾の「更新」を御覧ください。
- 前提環境(必要コマンド)の構築
    ``` sh
    sudo apt-get update
    sudo apt-get install -y git build-essential wget libssl-dev libreadline-dev zlib1g-dev
    ```
- rbenvのインストール
    ``` sh
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc
    eval "$(rbenv init -)"
    ```
- rbenvを用いてruby 2.5.1をインストール
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    ruby --version
    ```
    を実行して、`ruby 2.5.1....`と出力されれば成功
- mongoDB v3.6をインストール

  Ubuntu以外のLinuxをお使いの場合は[Install MongoDB Community Edition on Linux
    ](https://docs.mongodb.com/manual/administration/install-on-linux/)をご参照ください。
    ``` sh
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5`
    echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.6 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list`
    sudo apt-get update && sudo apt-get install mongodb-org
    ```
    - ここで`Geographic area`を聞かれた場合は`6. Asia`、`time zone`は`78. Tokyo`を指定。
    - `mongo` コマンドを実行し端末が表示されれば成功。`exit`で端末から抜ける。

    ``` sh
    sudo service mongod start
    ```
    によってmongodを起動。以後、システムの再起動時にmongodも自動的に起動する。
{% comment %}
- mongoDB v2.6をインストール
    - `sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10`
    - `echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list`
    - `sudo apt-get update && sudo apt-get install mongodb-org`
    - `sudo service mongod start`によってmongodを起動することができる。以後、システムの再起動時にmongodも自動的に起動する。
    - `mongo` コマンドを実行し端末が表示されれば成功。`exit`で端末から抜ける
{% endcomment %}
- bundlerのインストール
    ``` sh
    gem install bundler
    which bundle
    ```
    でコマンドへのパスが表示されればインストールに成功
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

ジョブ実行用のホストは以下の手順でセットアップします。以後、OACISを実行しているホストをOACISホスト、ジョブを実行するホストをリモートホストと呼ぶことにします。

1. OACISホストから鍵認証でSSH接続できるようにセットアップする。
    - (OACISホストにて) `ssh-keygen -t rsa` を実行し、SSH認証用の鍵を作成する。
        - パスフレーズは自分で適当なものを設定します。
        - このコマンドにより秘密鍵、公開鍵がそれぞれ `~/.ssh/id_rsa`, `~/.ssh/id_rsa.pub` に作成されます。
    - (OACISホストにて) 公開鍵をリモートホストに転送する。
        - 公開鍵をリモートホストに転送します。 `scp ~/.ssh/id_rsa.pub user@remotehost:~`
            - 上記コマンドの "user", "remotehost" は各自の環境に合わせて書き換えてください。
    - (OACISホストにて)`~/.ssh/config`ファイルを以下の形式で作成する。
      ```config
      Host connection_name
        HostName remotehost
        User user
        IdentityFile ~/.ssh/id_rsa
        port 22
      ```
      - `connection_name`には好きな名前を指定可能
      - `User`にはログインユーザ名を指定
      - `HostName`にリモートホストのアドレス(IP, localhostなど)を指定
      - `IdentityFile`には生成した秘密鍵を指定
      - OACIS v3より、IP・port・ユーザ名の指定はwebインターフェースを用いず、`~/.ssh/config`を参照する仕組みになりました。
    - (リモートホストにて) `cat ~/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys` を実行する。
    - (OACISホストにて) 接続確認を行う。
        - `ssh connection_name` でパスワードを使わずにログインできたら成功です。
            - 鍵作成時にパスフレーズを入力した場合は、ログイン時にパスフレーズの入力が要求されます。OACISの実行時にはパスワードもパスフレーズも入力せずにログインできるようにセットアップする必要があります。パスフレーズの入力を省略するには
                - (macOS El Capitan以前の場合) 初回ログインの際にはパスフレーズが要求されますが、以降はキーチェーンアクセスの機能によって入力を省略できます。
                - (macOS Sierraの場合) `ssh-add ~/.ssh/id_rsa`を実行します。この際パスフレーズの入力を要求されますが、以降はパスフレーズの入力を省略できます。
                - (Linuxの場合) SSH Agentを利用します。以下のコマンドを入力してください。（これらのコマンドはシステムにログインするたびに実行する必要があります。）
                    - ``eval `ssh-agent` `` (SSH agentを起動する）
                    - `ssh-add ~/.ssh/id_rsa` （秘密鍵のパスを指定する。このときにパスフレーズの入力を要求されますが、以降はパスフレーズの入力を省略できます。
                    - さらに入力を簡便にするために[Keychain](http://www.funtoo.org/Keychain)というツールもあります。
2. (リモートホストにて) ruby 1.8以降をインストールする。
    - すでにシステムにインストール済みの場合はこの手順は不要です。
    - rubyのバージョンは `ruby --version` で確認できます。
3. (リモートホストにて) [xsub](https://github.com/crest-cassia/xsub)を導入する。
    - xsubというのは、ジョブスケジューラの仕様の差異を吸収するスクリプトで、OACISはxsubコマンドを利用してリモートホストにジョブを投入します。
    - 詳細はxsubの[README](https://github.com/crest-cassia/xsub/blob/master/README.md)を参照してください。
4. (OACISホストにて) 導入の確認
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
```


## v3への更新
OACIS v3ではMongoDBをv3.6に、Rubyをv2.5.1にアップデート、および新規にredisをインストールする必要があります。

### MongoDBの更新

MongoDBをアップデートする際には2.6 -> 3.0 -> 3.2 -> 3.4といった段階的アップデートをしないとデータの互換性が維持されません。
ここでは一度に最新版に更新するため「OACISのデータのバックアップ」-> 「MongoDBを最新版に更新」-> 「OACISのデータのレストア」という手順で行うことを推奨します。

- データのバックアップ
``` sh
mongodump --db oacis_development #データをエクスポート
```
実行後、`dump/oacis_development`に結果が出力されていることを確認

- MongoDBの更新
    - macOSの場合

      詳細は「(1.2)手動でのOAICSのインストール」の「MacOSXでの前提条件の整え方」にある「mongoDB v3.6をインストール」を参照
      ``` sh
      brew uninstall mongo                         # 古いMongoDBのアンインストール
      mv /usr/local/var/mongodb ~/mongodb.backup   # 念のためにデータファイルをバックアップ
      brew update
      brew install mongo                           # MongoDB3.6のインストール
      brew services start mongodb                  # 起動
      ```
    - Ubuntuの場合

      詳細は「(1.2)手動でのOAICSのインストール」の「Ubuntu14.04での前提条件の整え方」にある「mongoDB v3.6をインストール」を参照
      ``` sh
      sudo apt-get autoremove mongodb-org #アンインストール
      sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
      echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.6 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list
      sudo apt-get update && sudo apt-get install mongodb-org
      sudo service mongod start #起動
      ```
- データの書き戻し
``` sh
mongorestore --db oacis_development dump/oacis_development #データベースをインポート
```

### Ruby・redisのセットアップ
- Rubyの更新
  ``` sh
  rbenv install 2.5.1 && rbenv global 2.5.1
  ```
- redisのインストールと起動
    - macOS
      ```sh
      brew install redis
      brew services start redis
      ```
    - Ubuntu
      ``` sh
      sudo apt-get install redis
      sudo service redis-server start
      ```

### SSH-configの編集

V3ではHostの設定項目から、"Hostname", "User", "Port", "IdentityFile"がなくなりました。代わりに"~/.ssh/config"ファイルにこれらの情報を記述してください。

## OACISの再起動
``` sh
bundle install                          # install dependent libraries
bundle exec rake daemon:start           # restart OACIS
```

OACISのユーザーメーリングリストに登録することをお勧めします。新規リリースについての情報がメールで通知されます。
[oacis-users mailing list](https://groups.google.com/forum/#!forum/oacis-users)


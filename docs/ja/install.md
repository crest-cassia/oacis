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

1. Dockerを導入
  - dockerの導入方法はDockerの[ドキュメント](https://docs.docker.com/)を参照のこと
    - (Mac,Windows) [Docker Toolbox](https://www.docker.com/toolbox)を使ってインストールします。
        - インストール後、Docker Quickstart Terminal という端末を起動できるようになる。以下の作業はこの端末上で実行すること
1. docker run コマンドを実行
    - 初めてOACISを利用する方で、すぐに次ページのチュートリアルを実施したい場合は `docker run --name oacis -p 3000:3000 -dt oacis/oacis_tutorial` を実行します。
        - このコマンドを実行すると、次ページのSTEP 2まで完了済みの状態の仮想環境イメージがダウンロードされ、仮想環境が起動します。
        - チュートリアル用の設定は不要な場合は `docker run --name oacis -p 3000:3000 -dt oacis/oacis` を実行すると、OACIS実行に最小限の設定が行われた仮想環境を起動できます。
1. ブラウザでアクセス
  - (Linux) http://localhost:3000, (Mac or Windows) http://192.168.99.100:3000 でOACISのトップページにアクセスできます。
      - 上記コマンド実行後、OACISが起動してトップページが表示できるまで数十秒かかる場合があります。ページが表示されない場合は、少し待ってブラウザのページを再読み込みしてください。
1. 仮想マシンの停止と再起動を行いたい場合は、以下のコマンドを実行します。
  - 仮想マシンを停止したい場合 : `docker stop oacis`
  - 停止した仮想マシンの再起動したい場合 : `docker start oacis`

詳細は[oacis_docker](https://github.com/crest-cassia/oacis_docker) のREADMEを参照してください。

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

- Ruby 2.2 or 2.3 (2.4系統は未対応)
- MongoDB 2.4.9 (http://www.mongodb.org/)
- bundler (http://bundler.io/)

Rubyのインストールにはrbenvまたはrvmを使って環境を整えるのがよいです。

Mac OS Xの場合、homebrew (http://brew.sh/) を使ってrbenvとMongoDBをインストールするのが手軽です。
Linuxの場合、yumやaptコマンドを使ってインストールできます。

#### MacOSXでの前提条件の整え方

ここではhomebrewを用いてセットアップしていきます。

- rbenvのインストール
    - `brew install rbenv ruby-build`
    - `echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc`
- rbenvを用いてrubyをインストール
    - `rbenv install 2.2.4 && rbenv global 2.2.4`
    - `ruby --version` を実行して、`ruby 2.2.4....`と出力されれば成功
- mongoDBをインストール
    - `brew install mongo` でインストール
    - `launchctl load ~/Library/LaunchAgents/homebrew.mxcl.mongodb.plist` によってmongodを起動することができる。以後ログイン時にmongodも自動的に起動する。
    - `mongo` コマンドを実行し端末が表示されれば成功。`exit`で端末から抜ける
- bundlerのインストール
    - `gem install bundler`
    - `which bundle` でコマンドへのパスが表示されればインストールに成功

#### Ubuntu14.04での前提条件の整え方

ここではapt-getを用いてセットアップしていきます。

- rbenvのインストール
    - `sudo apt-get update; sudo apt-get install -y git build-essential wget libssl-dev libreadline-dev zlib1g-dev`
    - `git clone https://github.com/rbenv/rbenv.git ~/.rbenv`
    - `git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build`
    - `echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc`
    - `echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc`
    - `eval "$(rbenv init -)"`
- rbenvを用いてrubyをインストール
    - `rbenv install 2.2.4 && rbenv global 2.2.4`
    - `ruby --version` を実行して、`ruby 2.2.4....`と出力されれば成功
- mongoDB v2.6をインストール
    - `sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10`
    - `echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list`
    - `sudo apt-get update && sudo apt-get install mongodb-org`
    - `sudo service mongod start`によってmongodを起動することができる。以後、システムの再起動時にmongodも自動的に起動する。
    - `mongo` コマンドを実行し端末が表示されれば成功。`exit`で端末から抜ける
- bundlerのインストール
    - `gem install bundler`
    - `which bundle` でコマンドへのパスが表示されればインストールに成功

### インストール

まず手元にOACISのソースコード一式をgit clonします。（gitがない場合はダウンロードします。）

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
http://localhost:3000 にアクセスし、ページが適切に表示されればインストールは成功しています。
端末で Ctrl-C を押し、Railsを停止します。
もし失敗した場合は、MongoDBが正しく起動しているか、gemは正しくインストールされたか、などを確認してください。

### 起動

Railsおよびworkerの起動は以下のコマンドを実行します。

```shell
bundle exec rake daemon:start
```
http://localhost:3000 にアクセスできればRailsの起動が成功しています。
またWorkerプロセスが起動しているかどうかは http://localhost:3000/runs にアクセスすれば確認できます。
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
    - (リモートホストにて) `cat ~/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys` を実行する。
    - (OACISホストにて) 接続確認を行う。
        - `ssh user@remotehost` でパスワードを使わずにログインできたら成功です。
            - 鍵作成時にパスフレーズを入力した場合は、ログイン時にパスフレーズの入力が要求されます。OACISの実行時にはパスワードもパスフレーズも入力せずにログインできるようにセットアップする必要があります。パスフレーズの入力を省略するには
                - (Macの場合) 初回ログインの際にはパスフレーズが要求されますが、以降はキーチェーンアクセスの機能によって入力を省略できます。
                - (Linuxの場合) SSH Agentを利用します。以下のコマンドを入力してください。（これらのコマンドはシステムにログインするたびに実行する必要があります。）
                    - ``eval `ssh-agent` `` (SSH agentを起動する）
                    - `ssh-add ~/.ssh/id_rsa` （秘密鍵のパスを指定する。このときにパスフレーズの入力を要求されますが、以降はパスフレーズの入力を省略できます。
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
docker run -p 127.0.0.1:3000:3000 -dt oacis/oacis_base
```

外部からのアクセスを制限するとOACISの利便性が失われると心配かもしれませんが、このように設定しても外部からSSHのポートフォワーディングを利用することでOACISを使うことができます。
OACISを server.example.com で起動している場合、以下のコマンドを実行すると localhost:3000 でOACISにアクセスできるようになります。
（"server.example.com"をOACISが起動しているサーバーに置き換えて実行してください。）

```shell
ssh -N -f -L 3000:localhost:3000 server.example.com
```


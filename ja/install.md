---
layout: default
title: "インストール"
lang: ja
next_page: tutorial
---

# インストール方法

OACISをインストールする方法には、

- (1)仮想環境を使う方法
- (2)手動で環境構築する方法
    
の２種類があります。

Windowsの方は(1)を選択してください。Unix系OS(Linux,Mac)の場合にはどちらの方法によっても環境構築ができます。

---

## (1) 仮想環境を使ったインストール

[Docker](https://www.docker.com/)というツールを使ってOACISがインストールされた仮想環境を手軽に導入することができます。
Linuxだけでなく、Windows、MacOSにも導入することができます。
手順の概要は以下の通りです。

1. Dockerを導入
  - dockerの導入方法はDockerの[ドキュメント](https://docs.docker.com/)を参照のこと
    - (Mac,Windows) [Docker Toolbox](https://www.docker.com/toolbox)を使ってインストールする。
        - インストール後、Docker Quickstart Terminal という端末を起動できるようになる。以下の作業はこの端末上で実行すること
1. docker run コマンドを実行
    - `docker run --name oacis -p 3000:3000 -dt oacis/oacis` を実行。
    - コマンドを実行すると、仮想マシンのイメージをダウンロード後に起動する。
1. ブラウザでアクセス
  - (Linux) http://localhost:3000, (Mac or Windows) http://192.168.99.100:3000 でOACISのトップページにアクセスできる。
1. 仮想マシンの停止と再起動を行いたい場合は、以下のコマンドを実行する。
  - 仮想マシンを停止したい場合 : `docker stop oacis`
  - 停止した仮想マシンの再起動したい場合 : `docker start oacis`

詳細は[oacis_docker](https://github.com/crest-cassia/oacis_docker) のREADMEを参照してください。

## (2) 手動インストール

### 対象プラットフォーム

- OACIS
    - Unix系OS。Mac OS X, Ubuntu, and CentOS などで稼働実績あり
    - Windowsはサポート対象外。Cygwinもサポートされない。Windowsユーザーは仮想環境を導入する必要がある。
- 計算ホスト
    - 同様にbashが起動するUnix系OSでなくてはならない。こちらはcygwinも可。
- ブラウザ
    - Google Chrome, Firefox, Safari。IEでの挙動は未確認。

### 前提条件

- Ruby 2.2.*
- MongoDB 2.4.9 (http://www.mongodb.org/)
- bundler (http://bundler.io/)

Rubyのインストールにはrbenvまたはrvmを使って環境を整えるのがよいです。

Mac OS Xの場合、homebrew (http://brew.sh/) を使ってrbenvとMongoDBをインストールするのが手軽です。
Linuxの場合、yumやaptコマンドを使ってインストールできます。

bundlerは正しいRubyのバージョンをインストールした後に、 `gem install bundler` コマンドを実行してください。（rbenvを使っている場合、 `rbenv rehash` コマンドも実行する必要があります）

### インストール

まず手元にOACISのソースコード一式をgit clonします。（gitがない場合はダウンロードします。）

{% highlight sh %}
git clone -b master https://github.com/crest-cassia/oacis.git
{% endhighlight %}

クローンしたディレクトリに移動し、以下のコマンドを実行するとRubyのバージョン、bundlerのインストール、MongoDBのバージョン、MongoDBのデーモンが起動していることを確認する事ができます。
{% highlight sh %}
./bin/check_oacis_env
{% endhighlight %}

次にRailsおよび関連gemのインストールを行います。ダウンロードしたディレクトリ内に移動し、
{% highlight sh %}
bundle install
{% endhighlight %}
を実行します。

成功すればこの時点でRailsを起動できます。試しに以下のコマンドで起動します。
{% highlight sh %}
bundle exec rails s
{% endhighlight %}
http://localhost:3000 にアクセスし、ページが適切に表示されればインストールは成功しています。
端末で Ctrl-C を押し、Railsを停止します。
もし失敗した場合は、MongoDBが正しく起動しているか、gemは正しくインストールされたか、などを確認してください。

### 起動

Railsおよびworkerの起動は以下のコマンドを実行します。
{% highlight sh %}
bundle exec rake daemon:start
{% endhighlight %}
http://localhost:3000 にアクセスできればRailsの起動が成功しています。
またWorkerプロセスが起動しているかどうかは http://localhost:3000/runs にアクセスすれば確認できます。
Workerが起動していない場合にはエラーメッセージが表示されます。

これらのプロセスの再起動、および停止は以下のコマンドで実行できます。

{% highlight sh %}
bundle exec rake daemon:restart
bundle exec rake daemon:stop
{% endhighlight %}

## 注意点（(1)の場合も(2)の場合も共通）

- OACISはイントラネット内で使用してください
  - OACISは計算ホストとして登録したサーバー内で任意のコマンドを実行できるので、悪意のあるユーザーからアクセスされるとセキュリティホールになります
  - 各個人のマシン上で起動し、ファイアウォールによりOACISには外部からのアクセスを許可しないように設定しておくのが望ましいです
    - Railsは3000番、MongoDBは27017番のポートをそれぞれ使用しているので、これらのポートへのアクセスを制限してください
- LinuxからDocker環境を使用している場合は、iptablesコマンドによるファイアウォール設定を推奨します。
  - 以下のコマンドを実行することにより、有線接続の外部ネットワークからOAICSへのアクセスを拒否できます。
{% highlight sh %}
iptables -I FORWARD -i eth+ -o docker0 -p tcp -m tcp --dport 3000 -j DROP
{% endhighlight %}
- Mac,WindowsからDocker環境を使用している場合は、デフォルトで外部からのアクセスはできないので特に対応をする必要はありません
- OACISへのアクセスをローカルホストからに制限した場合でもsshポートフォワーディングを使用する事で、別の端末からOACISにアクセスすることが可能です
  - OACISを server.example.com で起動している場合、以下のコマンドを実行すると localhost:3000 でOACISにアクセスできるようになります
{% highlight sh %}
ssh -N -f -L 3000:localhost:3000 server.example.com
{% endhighlight %}

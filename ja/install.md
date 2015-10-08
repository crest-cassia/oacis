---
layout: default
title: "インストール"
lang: ja
next_page: basic_usage
---

# インストール方法

OACISをインストールする方法には、

- (1)仮想環境を使う方法
- (2)手動で環境構築する方法
    
の２種類があります。

(1)が推奨ですが、Unix系OS(Linux,Mac)の場合には(2)の方法によっても環境構築ができます。

---

## (1) 仮想環境を使ったインストール

[Docker](https://www.docker.com/)というツールを使ってOACISがインストールされた仮想環境を手軽に導入することができます。
Linuxだけでなく、Windows、MacOSにも導入することができます。
手順の概要は以下の通りです。

1. Dockerを導入
  - dockerの導入方法はDockerの[ドキュメント](https://docs.docker.com/)を参照のこと
    - (Mac,Windows) [Docker Toolbox](https://www.docker.com/toolbox)を使ってインストールする。
        - インストール後、Docker Quickstart Terminal という端末を起動できるようになる。以下の作業はこの端末上で実行すること
1. [oacis_docker](https://github.com/crest-cassia/oacis_docker) というリポジトリをcloneする
  - `git clone https://github.com/crest-cassia/oacis_docker.git` を実行
1. oacis_docker のスクリプトを実行
  - `oacis_docker/bin/start.sh PROJECT_NAME` を実行。PROJECT_NAMEは任意の名前で良い。
  - 任意のディレクトリから実行可能。
  - 実行するとカレントディレクトリ以下に *PROJECT_NAME* という名前のディレクトリが作られる。そこに実行結果のファイルが格納される。
      - 一度OACISの起動イメージを作成すると、イメージを削除するまでこのディレクトリを別のパスに移動することができないので注意。

スクリプトを実行すると、仮想マシンのイメージをダウンロードし、仮想環境上で起動し、ホストOSのブラウザからアクセスできるようになります。
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
Mac OS Xの場合、homebrew (http://brew.sh/) を使ってインストールするのが手軽です。
Linuxの場合、yumやaptコマンドを使ってインストールできます。

以下のコマンドでRubyのバージョン、bundlerのインストール、MongoDBのバージョン、MongoDBのデーモンが起動していることを確認する事ができます。
{% highlight sh %}
${OACIS_PROJECT_ROOT}/bin/check_oacis_env
{% endhighlight %}

### インストール

まず手元にOACISのソースコード一式をgit clonします。（gitがない場合はダウンロードします。）

{% highlight sh %}
git clone https://github.com/crest-cassia/oacis.git
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
bundle exec rake daemon:start RAILS_ENV=production
{% endhighlight %}
http://localhost:3000 にアクセスできればRailsの起動が成功しています。
またWorkerプロセスが起動しているかどうかは http://localhost:3000/runs にアクセスすれば確認できます。
Workerが起動していない場合にはエラーメッセージが表示されます。

これらのプロセスの再起動、および停止は以下のコマンドで実行できます。

{% highlight sh %}
bundle exec rake daemon:restart RAILS_ENV=production
bundle exec rake daemon:stop RAILS_ENV=production
{% endhighlight %}

## 注意点

- OACISはイントラネット内で使用してください
  - OACISは計算ホストとして登録したサーバー内で任意のコマンドを実行できるので、悪意のあるユーザーからアクセスされるとセキュリティホールになります
  - 各個人のマシン上で起動し、ファイアウォールによりOACISには外部からのアクセスを許可しないように設定しておくのが望ましいです
    - Railsは3000番、MongoDBは27017番のポートをそれぞれ使用しているので、これらのポートへのアクセスを制限してください
  - Mac,WindowsからDocker環境を使用している場合は、デフォルトで外部からのアクセスはできないので特に対応をする必要はありません
- OACISへのアクセスをローカルホストからに制限した場合でもsshポートフォワーディングを使用する事で、別の端末からOACISにアクセスすることが可能です
  - OACISを server.example.com で起動している場合、以下のコマンドを実行すると localhost:3000 でOACISにアクセスできるようになります
{% highlight sh %}
ssh -N -f -L 3000:localhost:3000 server.example.com
{% endhighlight %}


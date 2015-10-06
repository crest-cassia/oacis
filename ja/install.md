---
layout: default
title: "インストール"
lang: ja
next_page: basic_usage
---

# インストール方法

OACISをインストールするには、

- (1)仮想環境を使う方法
- (2)手動で環境構築する方法の２種類がある。

(1)が推奨だが、Unix系OS(Linux,Mac)の場合には(2)の方法によっても環境構築ができる。

---

## (1) 仮想環境を使ったインストール

[Docker](https://www.docker.com/)というツールを使ってOACISがインストールされた仮想環境を手軽に導入することができる。
Linuxだけでなく、Windows、MacOSにも導入することができる。
手順の概要は以下のようになる。

1. Dockerを導入
1. [oacis_docker](https://github.com/crest-cassia/oacis_docker) というリポジトリをcloneする
1. oacis_docker のスクリプトを実行

スクリプトを実行すると、仮想マシンのイメージをダウンロードし、仮想環境上で起動し、ホストOSのブラウザからアクセスできるようになる。

詳細は[oacis_docker](https://github.com/crest-cassia/oacis_docker) のREADMEを参照のこと。

## (2) 手動インストール

### 対象プラットフォーム

- OACIS
    - Unix系OS。Mac OS X, Ubuntu, and CentOS などで稼働実績がある。
    - Windowsはサポート対象外。Cygwinもサポートされない。Windowsユーザーは仮想環境を導入する必要がある。
- 計算ホスト
    - 同様にbashが起動するUnix系OSでなくてはならない。こちらはcygwinも可。
- ブラウザ
    - Google Chrome, Firefox, Safari。IEでの挙動は未確認。

### 前提条件

- Ruby 2.2.*
- MongoDB 2.4.9 (http://www.mongodb.org/)
- bundler (http://bundler.io/)

Rubyのインストールにはrbenvまたはrvmを使って環境を整えると良い。
Mac OS Xの場合、homebrew (http://brew.sh/) を使ってインストールするのが手軽で良い。
Linuxの場合、yumやaptコマンドを使ってインストールできる。

以下のコマンドでRubyのバージョン、bundlerのインストール、MongoDBのバージョン、MongoDBのデーモンが起動していることを確認する事ができる。
{% highlight sh %}
${OACIS_PROJECT_ROOT}/bin/check_oacis_env
{% endhighlight %}

### インストール

まず手元にOACISのソースコード一式をgit cloneする。（gitがない場合はダウンロードする。）

{% highlight sh %}
git clone https://github.com/crest-cassia/oacis.git
{% endhighlight %}

次にRailsおよび関連gemのインストールを行う。ダウンロードしたディレクトリ内に移動し、
{% highlight sh %}
bundle install
{% endhighlight %}
を実行する。

成功すればこの時点でRailsを起動できる。試しに以下のコマンドで起動する。
{% highlight sh %}
bundle exec rails s
{% endhighlight %}
http://localhost:3000 にアクセスし、ページが適切に表示されればインストールは成功している。
端末で Ctrl-C を押し、Railsを停止させる。
もし失敗した場合は、MongoDBが正しく起動しているか、gemは正しくインストールされたか、などを確認する。

### 起動

Railsおよびworkerの起動は以下のコマンドを実行する。
{% highlight sh %}
bundle exec rake daemon:start RAILS_ENV=production
{% endhighlight %}
http://localhost:3000 にアクセスできればRailsの起動が成功している。
またWorkerプロセスが起動しているかどうかは http://localhost:3000/runs にアクセスすれば確認できる。
Workerが起動していない場合にはエラーメッセージが表示される。

これらのプロセスの再起動、および停止は以下のコマンドで実行できる。

{% highlight sh %}
bundle exec rake daemon:restart RAILS_ENV=production
bundle exec rake daemon:stop RAILS_ENV=production
{% endhighlight %}

## 注意点

- OACISはイントラネット内で使用すること
  - OACISは計算ホストとして登録したサーバー内で任意のコマンドを実行できるので、悪意のあるユーザーからアクセスされるとセキュリティホールになる
  - 各個人のマシン上で起動し、ファイアウォールによりOACISには外部からのアクセスを許可しないように設定しておくのが望ましい
    - Railsは3000番、MongoDBは27017番のポートをそれぞれ使用しているので、これらのポートへのアクセスを制限する。
- OACISへのアクセスをローカルホストからに制限した場合でもsshポートフォワーディングを使用する事で、別の端末からOACISにアクセスすることが可能である。
  - OACISを server.example.com で起動している場合、以下のコマンドを実行すると localhost:3000 でOACISにアクセスできるようになる。
{% highlight sh %}
ssh -N -f -L 3000:localhost:3000 server.example.com
{% endhighlight %}


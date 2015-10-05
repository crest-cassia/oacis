---
layout: default
title: "Tips"
lang: ja
---

# {{page.title }}

---

## バックアップ・レストア

#### OACISのバックアップとレストア方法について

OACISによって管理されているデータは、DB上のレコード(MongoDBではコレクションと呼ぶ。)とファイルシステム上のpublicディレクトリ以下に保存されている。
以下では、コレクションとpublicディレクトリそれぞれに対して、バックアップ・レストア手順を示す。

#### コレクションのバックアップ

OACISが利用しているDBの名前をoacis_developmentとする。（DB名は、confing/mongoid.ymlに記載されている。）

1. コレクションのバックアップ(バックアップデータは./dump/以下に作成される。)
    - `mongodump --db oacis_development`

#### コレクションのレストア

2. DBのレストア
    - `mongorestore --db oacis_development /path/to/DB_data/dump/oacis_development`

#### publicディレクトリのバックアップ

OACISは、結果のファイル群をpublicディレクトリ以下に保管している。

ローカルのディレクトリに差分コピーする場合

{% highlight sh %}
rsync -av -P --delete /path/to/OACIS/public/Reuslt_development/526638c781e31e98cf000001 /path/to/backup_dir/Reuslt_development/
{% endhighlight %}

リモートマシンに差分コピーする場合

{% highlight sh %}
rsync -avz -P --delete -e "ssh -i ~/.ssh/id_rsa" /path/to/OACIS/public/Reuslt_development/526638c781e31e98cf000001 username@remotehost:/path/to/backup_dir/Reuslt_development/
{% endhighlight %}

- 補足
    - ``cp -r`` や ``scp -r`` では、バックアップ先に同じ名前のディレクトリが存在しているとき、挙動が変わるので非推奨

#### publicディレクトリのレストア

ローカルからの場合

{% highlight sh %}
rsync -av -P /path/to/backup_dir/Reuslt_development/526638c781e31e98cf000001 /path/to/OACIS/public/Reuslt_development/
{% endhighlight %}

リモートマシンからの場合

{% highlight sh %}
rsync -avz -P -e "ssh -i ~/.ssh/id_rsa" username@oacishost:/path/to/backup_dir/Reuslt_development/526638c781e31e98cf000001 /path/to/OACIS/public/Reuslt_development/
{% endhighlight %}

#### 参考

* MongoDB mongodump: http://docs.mongodb.org/manual/reference/program/mongodump/
* MongoDB mongorestore: http://docs.mongodb.org/manual/reference/program/mongorestore/
* MongoDB ObjectID: http://docs.mongodb.org/manual/reference/object-id/

## READ_ONLY モード

地理的に離れた研究者とデータの共有をする場合など、データを共有のサーバーにアップロードしてOACISを経由してシミュレーション結果を見てもらいたい場合がある。
この場合アップロードしたサーバー上でOACISを起動する事になるが、その際には閲覧のみを可能にし、リモートジョブの実行や新規シミュレーターの登録などはできないようにした方が安全である。
OACISを閲覧専用モードで起動すると結果の閲覧のみが可能な状態で利用できる。

`config/user_config.yml` というファイルを用意する。
サンプルが `config/user_config.sample.yml` にあるので、参考にしてほしい。
READ_ONLYモードにする場合には以下のようにファイルに記述する。（sampleの全てのフィールドを書く必要はなく、必要な設定のみuser_config.ymlに記述すれば良い）


{% highlight yaml %}
---
read_only: true
{% endhighlight %}

このように設定後OACISを起動するとバックグラウンドのワーカープロセスは起動せず、ブラウザ上からの新規レコードの作成や編集もできなくなる。
ローカルマシンで起動したOACISからジョブを実行しつつ共有マシンではREAD_ONLYモードで起動しておき、定期的に共有サーバーにバックアップコマンドでデータを同期するとデータの共有が容易にできる。


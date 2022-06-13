---
layout: default
title: "TIPs"
lang: ja
---

# {{page.title }}

---

## バックアップ・レストア

OACISによって管理されているデータは、DB上のレコード（MongoDBではコレクションと呼ばれる）と、ファイルシステム上のpublicディレクトリ以下に保存されています。
両方のデータをそれぞれバックアップおよびレストアする必要があります。
ここでは、その手順を説明します。

### Docker環境を利用していない場合

#### バックアップ

まずMongo DBのコレクションを保存するために以下のコマンドを実行します。
v3.8.0以降で利用できますので、古いOACISを利用している人はOACISを更新するか、下のコマンドを利用してください。

{% highlight sh %}
./bin/oacis_dump_db
(for v3.7 or prior: mongodump --db oacis_development )
{% endhighlight %}

ファイルシステムのデータについては *OACIS_PROJECT_ROOT/public/Result_development* 以下のファイルを全て保存してください。
（cpコマンドを使っても良いですが、容量が大きい場合にはrsyncを使った方がよいでしょう）

{% highlight sh %}
rsync -av -P --delete /path/to/OACIS/public/Result_development /backup_dir
{% endhighlight %}

#### レストア

下記のコマンドを実行します。

{% highlight sh %}
./bin/oacis_restore_db
(for v3.7 or prior: mongorestore --db oacis_development --drop /path/to/DB_data/dump/oacis_development )
{% endhighlight %}

（注）上記のコマンドはDB内の既存のレコードを一度削除しています。つまり上書きしています。

ファイルのレストアはバックアップと同様にrsyncで行います。

{% highlight sh %}
rsync -av -P --delete /backup_dir/Result_development /path/to/OACIS/public
{% endhighlight %}

#### 参考

* MongoDB mongodump: [http://docs.mongodb.org/manual/reference/program/mongodump/](http://docs.mongodb.org/manual/reference/program/mongodump/)
* MongoDB mongorestore: [http://docs.mongodb.org/manual/reference/program/mongorestore/](http://docs.mongodb.org/manual/reference/program/mongorestore/)
* MongoDB ObjectID: [http://docs.mongodb.org/manual/reference/object-id/](http://docs.mongodb.org/manual/reference/object-id/)

### Docker環境を利用している場合

oacis_docerリポジトリの [Backup and Restore](https://github.com/crest-cassia/oacis_docker/blob/master/README.md#backup-and-restore) を参照してください。

## アクセスレベルの制御

地理的に離れた研究者とデータの共有をする場合など、データを共有のサーバーにアップロードしてOACISを経由してシミュレーション結果を見てもらいたい場合があります。
この場合アップロードしたサーバー上でOACISを起動する事になりますが、その際には閲覧のみを可能にし、リモートジョブの実行や新規シミュレーターの登録などはできないようにした方が安全です。
OACISを閲覧専用モードで起動すると結果の閲覧のみが可能な状態で利用できます。

OACISのプロジェクトのディレクトリで `config/user_config.yml` というファイルを用意します。
サンプルが `config/user_config.sample.yml` にあるので、参考にしてください。
READ_ONLYモードにする場合には以下のようにファイルに記述します。
（sampleの全てのフィールドを書く必要はなく、必要な設定のみuser_config.ymlに記述すれば良いです）

{% highlight yaml %}
---
access_level: 0
{% endhighlight %}

access_levelの項目には0,1,2の３種類を指定することができます。通常モードは２です。

1を指定するとSimulator、Analyzer、Hostの新規作成、編集、削除を禁止します。すでに定義されたSimulatorのジョブは実行できるが、任意のコマンドを新たに定義したSimulatorを作成することはできません。

0を指定するとREAD_ONLYモードになり、結果の閲覧のみができるような状態になります。
このように設定後OACISを起動するとバックグラウンドのワーカープロセスは起動せず、ブラウザ上からの新規レコードの作成や編集もできなくなります。
さらにOACISがバインドされるIPアドレスがデフォルトで`0.0.0.0`になり、他ホストからもアクセスできるようになります。
IPアドレスについての設定を変更したい場合は、このファイルに`binding_ip: 'localhost'`というような行を追加してください。

ローカルマシンでアクセスレベル2で起動したOACISからジョブを実行しつつ、共有マシンではアクセスレベル0でOACISを別に起動しておき、定期的に共有サーバーにバックアップコマンドでデータを同期することで他者とのデータの共有が容易にできます。


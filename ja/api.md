---
layout: default
title: "API"
lang: ja
next_page: tips
---

# APIの使い方

---

OACISはRubyで実装されており、RubyのAPIを持っています。
スクリプトからOAICSのAPIを呼ぶことにより、OACIS上の処理を自動化することができます。
ここではAPIの使い方を説明します。

## 前提

ここでは、３つのパラメータ p1,p2,p3 を持つSimulatorがあるとして話を進めます。
このページは基本的なRubyの文法は知っているユーザー向けです。


## 実行方法

Rubyのスクリプトを書いて実行する方法と、対話的な環境で実行する方法の２種類があります。
対話的な環境でテストやデバッグなどを行い、大きな処理はスクリプトで行うのがおすすめです。

### 対話的環境での実行方法

OACISのディレクトリにて、 `bundle exec rails c` を実行。対話的環境が起動します。

```
$ bundle exec rails c
Loading development environment (Rails 4.2.0)
irb(main):001:0> Simulator.first.name
=> "my_simulator
irb(main):002:0>
```

### スクリプトでの実行

OACISのディレクトリから`./config/environment.rb`をロードすると、OACISの環境を呼び込んだあとでスクリプトを実行できます。

```
$ echo 'p Simulator.first.name' > test.rb   # test.rbを準備
$ bundle exec ruby -r ./config/environment test.rb
"my_simulator"
```

## API一覧

OACIS上の処理を行うために、主に以下のクラスのオブジェクトを利用します。

- Simulator
- ParameterSet
- Run
- Host
- Analyzer
- Analysis

の６つ。この６つのクラスの主要なメソッドを以下に列挙します。

また以下のAPIはv2.6.0以降で利用できます。

### [Optional] 参考情報

OACISは内部のデータをMongoDBに保存しており、MongoDB上のデータを扱うためのライブラリとしてMongoidを採用しています。
[Mongoidのドキュメント](https://docs.mongodb.com/ruby-driver/master/mongoid-tutorials/) を読むと内容をよりよく理解できるでしょう。
特に [Queries](https://docs.mongodb.com/ruby-driver/master/tutorials/mongoid-queries/) のページは要素を検索する際に役に立つでしょう。

OACISの中でMongoidのドキュメントを定義したコードは https://github.com/crest-cassia/oacis/tree/Development/app/models に存在します。

### Simulator

#### 取得

```ruby
sim = Simulator.find("...ID...")
```

#### 検索

```ruby
sim = Simulator.where(name: "my_simulator").first
```

#### 参照

```ruby
sim.name  #=> "my_simulator"
sim.parameter_definitions
#=>
[#<ParameterDefinition _id: 522d751f899e533149000003, key: "p1", type: "Integer", default: 1, description: "first parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000004, key: "p2", type: "Integer", default: 1, description: "second parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000005, key: "p3", type: "Float", default: 0.0, description: "third parameter">]
```

### ParameterSet

#### 取得

IDから取得

```ruby
ps = ParameterSet.find("...ID...")
```

#### 検索

Simulatorから該当するパラメータのPSを検索。パラメータの値はParameterSetオブジェクトの"v"というフィールドに保存されている。"v"の子要素("v.p1", "v.p2"など) への検索条件を使って`where`メソッドで検索する。
得られた結果に対してeachで回して要素を取得できる。(`count`, `exists?`などのEnumerableへのメソッドは同様に使える）

```ruby
sim.parameter_sets.where("v.p1" => 1, "v.p2" => 2).each do |ps|
  puts ps.id
end
```

#### 参照

- `v`でパラメータの値をHashで取得できる
- `dir`でディレクトリへのパスを取得できる

```ruby
ps.v  #=> {"p1"=>1, "p2"=>2, "p3"=>0.4}
ps.dir  # =><Pathname:/path/to/oacis/public/Result_development/522d751f899e533149000002/522d757d899e53a01400000b>
```

#### 作成

```ruby
created = sim.parameter_sets.create!(v: {"p1"=>19,"p2"=>20})
```

p1=19,p2=20のPSがつくられる。指定していないパラメータはデフォルト値になる。
既存のものと同じparameterのPSを作ろうとすると例外が発生する。

#### 削除

```ruby
ps.discard
```

配下の実行中のRunやAnalysisをキャンセルしたりしないといけないので、削除処理はOACISのworkerに実行してもらう必要がある。
Mongoidの削除メソッドである`destroy`は呼ばずに、OACISのAPIで定義されている`discard`を呼ぶこと。

### Run

#### 取得

```ruby
run = Run.find("...ID...")
```

#### 検索

```ruby
ps.runs.where( :status => :finished ).each do |run|
  puts run.id
end
```

#### 参照

Runの情報を以下のように参照できる。

```ruby
run.status  # => [:created,:submitted,:running,:failed,:finished]のいずれかが返る。
run.submitted_to  #=> 投入先ホスト #<Host _id: 53a3f583b93f964b7f0000fc, ...>
run.host_parameters  #=> {"ppn"=>"1", "walltime"=>"1:00:00"}
run.mpi_procs     #=> 1
run.omp_threads   #=> 1
run.priority      #=> 1
run.result        #=> {"result1"=>-0.016298, "result2"=>0.0264882}
```

#### 作成

```ruby
host = Host.find("...HOSTID...")
host_param = {ppn:"4",walltime:"1:00:00"}

# hostパラメータのデフォルト値を得るには以下のメソッドが有用
#  sim.get_default_host_parameter(host)
run = ps.runs.create!(submitted_to: host, host_parameters: host_param, mpi_procs: 4)

# To create multiple runs, call "create!" method as many times as you want
runs = []
10.times do |t|
  runs << ps.runs.create!( submitted_to: host, host_parameters: host_param, mpi_procs: 4)
end
```

#### 削除

```ruby
run.discard
```

### Host

#### 取得

```ruby
host = Host.find("...HOSTID...")
```

#### 検索

```ruby
host = Host.where("name"=>"localhost").first
```

#### 参照

```ruby
host.status   #=> [:enabled, :disabled] のどちらかが返る
host.user     #=> user名
host.port     #=> 22
host.ssh_key  #=> '~/.ssh/id_rsa'
host.host_parameter_definitions
=> [#<HostParameterDefinition _id: 57babbb46b696d52bf240000, key: "ppn", default: "1", format: "^[1-9]\\d*$">,
 #<HostParameterDefinition _id: 57babbb46b696d52bf250000, key: "walltime", default: "1:00:00", format: "^\\d+:\\d{2}:\\d{2}$">]
```

その他の参照可能な要素については https://github.com/crest-cassia/oacis/blob/Development/app/models/host.rb を参照のこと。

### Analyzer

#### 取得

```ruby
azr = Analyzer.find("...ID...")
```

#### 検索

```ruby
azr = sim.analyzers.where(name:"my_analyzer").first
```

#### 参照

Analyzerの設定値を確認できる。

```ruby
azr.support_mpi     #=> true/false
azr.support_omp     #=> true/false
azr.command         #=> 実行コマンド
```

### Analysis

#### 取得

```ruby
anl = Analysis.find("...ID...")
```

#### 検索

ParameterSetに対するAnalysisの場合は `parameter_set.analyses.where`、Runに対するAnalysisの場合は `run.analyses.where`で検索できる。

```ruby
sim = Simulator.find("...ID...")
azr = sim.analyzers.where(name: "my_analyzer").first
ps.analyses.where( analyzer: azr, status: :finished ).each do |anl|
  p anl.id
end
```

#### 参照

Runとほぼ同じAPIが利用できる

```ruby
anl.status   #=> [:created,:submitted,:running,:failed,:finished]のいずれかが返る。
anl.submitted_to  #=> 投入先ホスト #<Host _id: 53a3f583b93f964b7f0000fc, ...>
anl.host_parameters  #=> {"ppn"=>"1","walltime"=>"1:00:00"}
anl.result        #=> {"result1"=>-0.016298, "result2"=>0.0264882}
```

#### 作成

作成の際には、Analyzer、投入ホスト、ホストパラメータを指定する必要がある

```ruby
host_param = {"ppn"=>"1", "walltime"=>"1:00:00"}
ps.analyses.create!(analyzer: azr, submitted_to: host, host_parameters: host_param )
```

#### 削除

```
anl.discard
```


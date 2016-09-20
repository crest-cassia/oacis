---
layout: default
title: "CLIの使い方"
lang: ja
next_page: api
---

# Command Line Interface(CLI)の使い方

---

Web browser経由で対話的な操作に加え、コマンドライン経由でSimulator, ParameterSet, Runの作成をするためのプログラム(CLI)が用意されています。
対話的な操作ではできないような多数のParameterSetやRunを一度に作成したい場合に有効であるだけでなく、他のプログラムからOACISを操作する用途にも利用可能です。
ここではCLIの基本的な使い方を説明していきます。


## CLIで利用可能な操作一覧

CLIで利用可能な操作は以下の通りです。

- 登録済みHost一覧の取得 (show_host)
- Simulator作成用テンプレート作成 (simulator_template)
- Simulator作成 (create_simulator)
- ParameterSet作成用テンプレート作成 (parameter_sets_template)
- ParameterSet作成 (create_parameter_sets)
- ジョブパラメータ指定用テンプレート作成 (job_parameter_template)
- Run作成 (create_runs)
- 作成済みRunのステータス確認 (run_status)
- 手動実行したジョブの実行結果の取り込み (job_include)
- Run削除（destroy_runs）
- IDを指定してRun削除（destroy_runs_by_ids）
- Run再作成（replace_runs）
- IDを指定してRun再作成（replace_runs_by_ids）
- Analyzer作成用テンプレート作成 (analyzer_template)
- Analyzer作成 (create_analyzer)
- Analysis作成用テンプレート作成 (analyses_template)
- Analysis作成（create_analyses）
- 作成済みAnalysisのステータス確認（analysis_status）
- Analysis削除（destroy_analyses）
- IDを指定してAnalysis削除（destroy_analyses_by_ids）
- Analysis再作成（replace_analyses）
- IDを指定してAnalysis再作成（replace_analyses_by_ids）
- 既存SimulatorへのParameterDefinition追加 (append_parameter_definition)

OACISのチェックアウトディレクトリ以下の bin/oacis_cli に引数を渡して実行する操作を指定します。
例えば

{% highlight sh %}
./bin/oacis_cli usage
{% endhighlight %}

このドキュメント内ではOACISのチェックアウトディレクトリから実行することを想定してコマンド例を示すが、どのディレクトリから実行しても構いません。

---

## usage

CLIの各コマンドの使用方法を表示する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli usage
{% endhighlight %}

---

## show_host

登録済みHost一覧の情報を取得する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli show_host -o host.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### 出力

- 以下の様に、登録済みhostの情報をObjectの配列としてJSON形式で出力する。
- hostにはid, name, hostname, userの情報のみ出力される。

{% highlight json %}
[
  {
    "id": "522fe89a899e53ec05000005",
    "name": "localhost",
    "hostname": "localhost",
    "user": "murase"
  }
]
{% endhighlight %}

---

## simulator_template

create_simulatorの時に使用するsimulator.jsonファイルのテンプレートを作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli simulator_template -o simulator.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### 出力

Simulatorの属性情報のテンプレートを出力する

{% highlight json %}
{
  "name": "a_sample_simulator",
  "command": "/Users/murase/program/oacis/lib/lib/samples/tutorial/simulator/simulator.out",
  "support_input_json": false,
  "support_mpi": false,
  "support_omp": false,
  "print_version_command": null,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
{% endhighlight %}

---

## create_simulator

Simulatorを新規作成する

#### 実行方法
{% highlight sh %}
./bin/oacis_cli create_simulator -h host.json -i simulator.json -o simulator_id.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--host    |-h      |executable hosts                |no         |
|----------|--------|--------------------------------|-----------|
|--input   |-i      |input file path                 |yes        |
|----------|--------|--------------------------------|-----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### 入力ファイル

- hostファイルは show_host で出力されるJSON形式のファイルを指定する。
- inputファイルは simulator_template で出力されるJSON形式のファイルを指定する。
    - JSONのパスを指定してもよいし、JSONの文字列をそのまま渡しても良い

#### 出力

新規作成されたsimulatorのidをObjectとしてJSON形式で出力する。

{% highlight json %}
{
  "simulator_id": "52b3bcd7b93f964178000001"
}
{% endhighlight %}

---

## parameter_sets_template

create_parameter_setsの時に使用するparameter_sets.jsonファイルのテンプレートを作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli parameter_sets_template -s 5361e421b93f96bbc500000e -o parameter_sets.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--simulator|-s      |simulator                       |yes        |
|-----------|--------|--------------------------------|-----------|
|--output   |-o      |output file path                |yes        |
|-----------|--------|--------------------------------|-----------|

#### 入力ファイル

simulatorはSimulatorのIDを渡すか、create_simulator で出力されるJSON形式のファイルを指定する。

#### 出力

ParameterSet作成時に使用するパラメータ指定ファイルのテンプレートを出力する。

{% highlight json %}
[
  {"p1":0,"p2":5.0}
]
{% endhighlight %}

---

## create_parameter_sets

ParameterSetを新規作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json
{% endhighlight %}

{% highlight sh %}
./bin/oacis_cli create_parameter_sets -s 5361e421b93f96bbc500000e -i '{"p1":1,"p2":[2.0,3.0}' -o parameter_set_ids.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--simulator|-s      |simulator                       |yes        |
|-----------|--------|--------------------------------|-----------|
|--input    |-i      |input json                      |yes        |
|-----------|--------|--------------------------------|-----------|
|--run      |-r      |run-option json                 |yes        |
|-----------|--------|--------------------------------|-----------|
|--output   |-o      |output file path                |yes        |
|-----------|--------|--------------------------------|-----------|

#### 入力ファイル

- simulatorはIDを渡すか、create_simulatorで出力されるJSON形式のファイルを指定する。
- inputファイルは parameter_sets_template で出力されるJSON形式のファイルを指定する。
    - またはJSONの文字列を指定しても良い。
    - パラメータとして配列を指定すると、複数のパラメータセットを同時に作る事ができる。
- runは、指定されたParameterSetに対してRunの作成をする場合に指定する。
    - JSON形式の文字列、またはJSONファイルのパスを指定する。
    - runのフォーマットは以下の通り。

{% highlight json %}
{
  "num_runs":1,"mpi_procs":1,"omp_threads":1,"priority":1,
  "submitted_to":"522fe89a899e53ec05000005",
  "host_parameters":{"nodes":"1","ppn":"1","walltime":"10:00"}
}
{% endhighlight %}

- "submitted_to"フィールドにはHostのIDを指定する。
- "host_parameters"フィールドは、各ホストで必要とされるパラメータを入力する。
- それぞれのParameterSetが "num_runs" 個のRunを持つまでRunが作成される。

#### 出力

新規作成されたParameterSetのidをObjectの配列としてJSON形式で出力する。

{% highlight json %}
[
  {"parameter_set_id":"52b3ddc7b93f969b8c000001"}
]
{% endhighlight %}

#### その他

同じParameterの値を持つParameterSetが既に存在する場合には、新規にParameterSetを作成せずに既存のParameterSetのidを出力として返す。エラーにはならない。

---

## job_parameter_template

create_runs, create_analyses の時に使用するjob_parameter.jsonファイルのテンプレートを作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli job_parameter_template -h host_id -o job_parameter.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--host_id |-h      |host id (string)                |no         |
|----------|--------|--------------------------------|-----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### 入力

host idはHostのidを文字列で指定する。指定が無い場合はmanualでのジョブを投入する。

#### 出力

Run作成時に使用するジョブパラメータ指定ファイルのテンプレートを出力する。

{% highlight json %}
{
  "host_id": "522fe89a899e53ec05000005",
  "host_parameters": {
    "nodes": "1",
    "ppn": "1",
    "walltime": "10:00"
  },
  "mpi_procs": 1,
  "omp_threads": 1,
  "priority": 1
}
{% endhighlight %}

---

## create_runs

Runを新規作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli create_runs -p parameter_set_ids.json -j job_parameter.json -n 1 -o run_ids.json
{% endhighlight %}

#### オプション

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--parameter_sets|-p      |parameter set id file           |yes        |
|----------------|--------|--------------------------------|-----------|
|--job_parameters|-j      |job parameter file              |yes        |
|----------------|--------|--------------------------------|-----------|
|--number_of_runs|-n      |number of runs (Integer)        |no         |
|----------------|--------|--------------------------------|-----------|
|--output        |-o      |output file path                |yes        |
|----------------|--------|--------------------------------|-----------|

#### 入力ファイル

- parameter_setsファイルは create_parameter_sets で出力されるJSON形式のファイルまたは文字列を指定する。
- job_parameterファイルは job_parameter_template で出力されるJSON形式のファイルまたは文字列を指定する。
- number_of_runs はRunの数を数値で指定する。各ParameterSetごとに、ここで指定された数になるまでRunが作られる。デフォルトは1。

#### 出力

RunのidをObjectの配列としてJSON形式で出力する。
新規作成されていないRunについても、各ParameterSetごとにnで指定された数の分だけRunのidを出力する。

{% highlight json %}
[
  {"run_id":"52b3eaebb93f96933f000001"}
]
{% endhighlight %}

#### その他

既に指定された数のRunが存在する場合には、新規にRunを作成せずに既存のRunのidを出力として返す。エラーにはならない。

---

## run_status

Runの実行状況を確認する

#### 実効方法

{% highlight sh %}
./bin/oacis_cli run_status -r run_ids.json
{% endhighlight %}

#### オプション

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--run_ids       |-r      |run id file                     |yes        |
|----------------|--------|--------------------------------|-----------|

#### 入力ファイル

run_idsファイルは create_runs で出力されるJSON形式のファイルを指定する

#### 出力

指定されたRunのステータスを集計し、標準出力に表示する

{% highlight json %}
{
  "total": 1,
  "created": 0,
  "submitted": 0,
  "running": 0,
  "failed": 1,
  "finished": 0
}
{% endhighlight %}

---

## job_include

手動実行したRunの実行結果を取り込む

#### 実行方法

{% highlight sh %}
./bin/oacis_cli job_include -i 52cde935b93f969b07000005.tar.bz2
{% endhighlight %}

#### オプション

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--input         |-i      |input archive files             |yes        |
|----------------|--------|--------------------------------|-----------|

#### 入力ファイル

- inputファイルは手動実行後に生成される結果のアーカイブファイル(.tar.bz2)を指定する。
  - アーカイブファイルは空白区切り、またはコンマ区切りで複数指定可能。

---

## destroy_runs

Runを削除する

#### 実行方法

{% highlight sh %}
../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:failed
{% endhighlight %}

#### オプション

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for runs(Hash)                     |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### 入力形式

- simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
- queryは連想配列で指定する。
    - 連想配列は {key}:{value} という形式で指定する。
    - keyとして可能な値は"status", "simulator_version"のみ。

#### 実行例

- simulator_versionが"1.0.0"のRunを削除する
{% highlight sh %}
../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0
{% endhighlight %}

- simulator_version が存在しないRunを削除する。

{% highlight sh %}
../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:
{% endhighlight %}

- statusが "created" （ジョブ投入前）のRunを削除する。

{% highlight sh %}
../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:created
{% endhighlight %}

---

## destroy_runs_by_ids

IDを指定してRunを削除する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli destroy_runs_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### オプション

なし

#### 入力形式

- 削除するRunのIDを引数として指定する。
- 指定されたIDが見つからない場合は、他のRunに対して削除を実行するか確認するダイアログが出る。

#### 実行例

- IDが52f9c5b4b93f963b8f000021のRunを削除する
{% highlight sh %}
./bin/oacis_cli destroy_runs_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## replace_runs

指定したRunを削除して、同じ設定で新しいRunを再作成する

#### ユースケース

例えば、ジョブを大量に流したが古いコードにバグが見つかり再実験が必要になった場合などに使える。
以前のRunと同じジョブパラメータ（投入ホスト、MPIプロセス数、OMPスレッド数、ホストパラメータ）で実行される。
ただし、乱数の種 _seed は変更される。

#### 実行方法

{% highlight sh %}
../bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:0.0.1
{% endhighlight %}

#### オプション

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for runs(Hash)                     |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### 入力形式

- simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
- queryは連想配列で指定する。
  - 連想配列は {key}:{value} という形式で指定する。
  - keyとして可能な値は"status", "simulator_version"のみ。
  - "simulator_version" が空のものを指定したい場合には "simulator_version:" と指定する。

#### 実行例

simulator_versionが"1.0.0"のRunを削除し、同じ設定で新しいRunを再作成する。

{% highlight sh %}
../bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0
{% endhighlight %}

---

## replace_runs_by_ids

IDを指定してRunを置換する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli replace_runs_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### オプション

なし

#### 入力形式

- 置換するRunのIDを引数として指定する。
- 指定されたIDが見つからない場合は、他のRunに対して置換を実行するか確認するダイアログが出る。

#### 実行例

- IDが52f9c5b4b93f963b8f000021のRunを置換する
{% highlight sh %}
./bin/oacis_cli replace_runs_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## analyzer_template

create_analyzerの時に使用するanalyzer.jsonファイルのテンプレートを作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli analyzer_template -o analyzer.json
{% endhighlight %}

#### オプション

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### 出力

Analyzerの属性情報のテンプレートを出力する

{% highlight json %}
{
  "name": "a_sample_analyzer",
  "type": "on_run",
  "auto_run": "no",
  "files_to_copy": "*",
  "description": "",
  "command": "gnuplot /Users/murase/program/oacis/lib/samples/tutorial/analyzer/analyzer.plt",
  "support_input_json": true,
  "support_mpi": false,
  "support_omp": false,
  "print_version_command": null,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
{% endhighlight %}

---

## create_analyzer

Analyzerを新規作成する

#### 実行方法
{% highlight sh %}
./bin/oacis_cli create_analyzer -h host.json -s simulator_id.json -i analyzer.json -o analyzer_id.json
{% endhighlight %}

#### オプション

|------------|--------|--------------------------------|-----------|
|Option      |alias   |description                     |required?  |
|:-----------|:-------|:-------------------------------|:----------|
|--host      |-h      |executable hosts                |no         |
|------------|--------|--------------------------------|-----------|
|--simulator |-s      |analyzer's simulator            |yes        |
|------------|--------|--------------------------------|-----------|
|--input     |-i      |input file path                 |yes        |
|------------|--------|--------------------------------|-----------|
|--output    |-o      |output file path                |yes        |
|------------|--------|--------------------------------|-----------|

#### 入力ファイル

- hostファイルは show_host で出力されるJSON形式のファイルを指定する。
- simulatorは create_simulator で出力されるJSON形式のファイルを指定する。
- inputファイルは analyzer_template で出力されるJSON形式のファイルを指定する。
    - JSONのパスを指定してもよいし、JSONの文字列をそのまま渡しても良い

#### 出力

新規作成されたanalyzerのidをObjectとしてJSON形式で出力する。

{% highlight json %}
{
  "analyzer_id": "52b3bcd7b93f964178000002"
}
{% endhighlight %}

---

## analyses_template

create_analysesの時に使用するanalysis_parameters.jsonファイルのテンプレートを作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli analyses_template -a 5226f430899e532cf6000009 -o analysis_parameters.json
{% endhighlight %}

#### オプション

|--------------|--------|--------------------------------|-----------|
|Option        |alias   |description                     |required?  |
|:-------------|:-------|:-------------------------------|:----------|
|--analyzer_id |-a      |analyzer id                     |yes        |
|--------------|--------|--------------------------------|-----------|
|--output      |-o      |output file path                |yes        |
|--------------|--------|--------------------------------|-----------|

#### 入力ファイル

analyzer_id はIDの文字列を指定する。

#### 出力

Analysis作成時に使用するパラメータ指定ファイルのテンプレートを出力する。

{% highlight json %}
[
  {"parameter1":50,"parametr2":1.0}
]
{% endhighlight %}

---

## create_analyses

Analysisを新規作成する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json
{% endhighlight %}

#### オプション

|-----------------|--------|---------------------------------------------------|-----------|
|Option           |alias   |description                                        |required?  |
|:----------------|:-------|:--------------------------------------------------|:----------|
|--analyzer       |-a      |analyzer id                                        |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--input          |-i      |input file path                                    |no         |
|-----------------|--------|---------------------------------------------------|-----------|
|--job_parameters |-j      |job parameter file                                 |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--output         |-o      |output file path                                   |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--first_run_only |        |only on first runs                                 |no         |
|-----------------|--------|---------------------------------------------------|-----------|
|--target         |-t      |on targets(parmeter_set_ids.json or run_ids.json)  |no         |
|-----------------|--------|---------------------------------------------------|-----------|

#### 入力ファイル

- analyzerはanalyzerのIDを指定する。
- inputは analyses_template で出力されるJSON形式のファイルまたはJSON形式の文字列を指定する。デフォルトは、Analyzerに登録されたパラメータのデフォルト値。
- job_parameterファイルは job_parameter_template で出力されるJSON形式のファイルまたは文字列を指定する。
- --first_run_onlyオプションまたは、-tオプションで解析対象のRunまたはPSを指定できる。どちらも指定がない場合は全てのRunまたはPSを対象にしてAnalysisを作成する。

#### 出力

- AnalysisのidをObjectの配列としてJSON形式で出力する。
- 新規作成されていないAnalysisについても、Analysisのidを出力する

{% highlight json %}
  [
    {"analysis_id":"52b3eaebb93f96933f00000d"}
  ]
{% endhighlight %}

#### 実行例

- 各ParameterSet のRun 1つに対してのみanalyzer を実行する。

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json --first_run_only
{% endhighlight %}

- 指定したParameterSet に対してanalyzer(:on_parameter_set) を実行する。

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json -t parameter_set_ids.json
{% endhighlight %}

- 指定したRun に対してanalyzer(:on_run) を実行する。

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json -t run_ids.json
{% endhighlight %}

#### その他

- 既にAnalysisが存在する場合には、新規にAnalysisを作成せずに既存のAnalysisのidを出力として返す。エラーにはならない。
- ParamterSetに対するAnalyzerを実行するとき、status:finished のRunが存在しないParameterSetを対象としたAnalysisは作成されない。

---

## analysis_status

Analysisの実行状況を確認する

#### 実効方法

{% highlight sh %}
./bin/oacis_cli analysis_status -a analysis_ids.json
{% endhighlight %}

#### オプション

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--analysis_ids  |-a      |analysis id file                |yes        |
|----------------|--------|--------------------------------|-----------|

#### 入力ファイル

analysis_idsファイルは create_analyses で出力されるJSON形式のファイルを指定する

#### 出力

指定されたAnalysisのステータスを集計し、標準出力に表示する

{% highlight json %}
  {
    "total": 100,
    "created": 50,
    "running": 0,
    "failed": 1,
    "finished": 49
  }
{% endhighlight %}

---

## destroy_analyses

Analysisを削除する

#### 実行方法

{% highlight sh %}
../bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:v0.1.0
{% endhighlight %}

#### オプション

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--analyzer_id   |-a      |analyzer id                              |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for analyses(Hash)                 |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### 入力形式

- analyzer_id はIDの文字列を指定する。
- queryは連想配列で指定する。
    - 連想配列は {key}:{value} という形式で指定する。
    - keyとして可能な値は"status","analyzer_version"のみ。
    - “analyzer_version” が空のものを指定したい場合には “analyzer_version:” と指定する。

#### 実行例

statusが "failed" （解析失敗）かつanalyzer_versionが "nil"のAnalysisを削除する

{% highlight sh %}
../bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:
{% endhighlight %}

---

## destroy_analyses_by_ids

IDを指定してAnalysisを削除する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli destroy_analyses_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### オプション

なし

#### 入力形式

- 削除するAnalysisのIDを引数として指定する。
- 指定されたIDが見つからない場合は、他のAnalysisに対して削除を実行するか確認するダイアログが出る。

#### 実行例

- IDが52f9c5b4b93f963b8f000021のAnalysisを削除する
{% highlight sh %}
./bin/oacis_cli destroy_analyses_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## replace_analyses

指定したAnalysisを削除して、同じ設定で新しいAnalysisを再作成する

#### ユースケース

- 実行したAnalyzerにバグがあり、修正したAnalyzerで計算を再実行したい

#### 実行方法

{% highlight sh %}
../bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished analyzer_version:v0.1.0
{% endhighlight %}

#### オプション

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--analzyer_id   |-a      |analyzer id                              |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for analyses(Hash)                 |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### 入力形式

- analyzer_id はIDの文字列を指定する。
- queryは連想配列で指定する。
    - 連想配列は {key}:{value} という形式で指定する。
    - keyとして可能な値は"status","analyzer_version"のみ。
    - “analyzer_version” が空のものを指定したい場合には “analyzer_version:” と指定する。

#### 実行例

- statusが"finished"のAnalysisを削除し、同じ設定で新しいAnalysisを再作成する。

{% highlight sh %}
../bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished
{% endhighlight %}

---

## replace_analyses_by_ids

IDを指定してAnalysisを置換する

#### 実行方法

{% highlight sh %}
./bin/oacis_cli replace_analyses_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### オプション

なし

#### 入力形式

- 置換するAnalysisのIDを引数として指定する。
- 指定されたIDが見つからない場合は、他のAnalysisに対して置換を実行するか確認するダイアログが出る。

#### 実行例

- IDが52f9c5b4b93f963b8f000021のAnalysisを置換する
{% highlight sh %}
./bin/oacis_cli replace_analyses_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## append_parameter_definition

指定したSimulatorに、新しいParameterを追加する。

#### ユースケース

既存のSimulatorを拡張したいが、既存のデータを破棄したくない場合に使用する。

#### 実行方法

{% highlight sh %}
./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n "new_param" -t Float -e 0.0
{% endhighlight %}

#### オプション

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--name          |-n      |name of the new parameter                |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--type          |-t      |type of the new parameter                |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--default       |-e      |default value of the new parameter       |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### 入力形式

- simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
- name は新規パラメータの名前を指定する。既存のパラメータと重複するとエラー。
- type は新規パラメータの型を指定する。指定可能な値は "Integer", "Float", "String", "Boolean" の４種類。
- default は新規パラメータのデフォルト値を指定する。
    - type と整合性が取れていない場合はエラー
    - 既存のパラメータセットのパラメータはこの値で保存される。

#### 実行例

"p3" という名前の整数型のパラメータ（デフォルト値 0）を追加する。

{% highlight sh %}
./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n p3 -t Integer -e 0
{% endhighlight %}

#### 注意事項

既に作成済みのRunについては更新されない。


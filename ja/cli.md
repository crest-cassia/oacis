---
layout: default
title: "CLIの使い方"
lang: ja
---

# Command Line Interface(CLI)の使い方

Web browser経由で対話的な操作に加え、コマンドライン経由でSimulator, ParameterSet, Runの作成をするためのプログラム(CLI)が用意されている。
対話的な操作ではできないような多数のParameterSetやRunを一度に作成したい場合に有効であるだけでなく、他のプログラムからOACISを操作する用途にも利用可能である。
ここではCLIの基本的な使い方を説明する。

## CLIで利用可能な操作一覧

CLIで利用可能な操作は以下の通りである。

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
- Run再作成（replace_runs）
- Analysis作成用テンプレート作成 (analyses_template)
- Analysis作成（create_analyses）
- 作成済みAnalysisのステータス確認（analysis_status）
- Analysis削除（destroy_analyses）
- Analysis再作成（replace_analyses）
- 既存SimulatorへのParameterDefinition追加 (append_parameter_definition)

OACISのチェックアウトディレクトリ以下の bin/oacis_cli に引数を渡して実行する操作を指定する。
例えば

```
./bin/oacis_cli usage
```

このドキュメント内ではOACISのチェックアウトディレクトリから実行することを想定してコマンド例を示すが、どのディレクトリから実行しても良い。

### usage

CLIの各コマンドの使用方法を表示する

- 実行方法

```
./bin/oacis_cli usage
```

### show_host

登録済みHost一覧の情報を取得する

#### 実行方法

```
./bin/oacis_cli show_host -o host.json
```

#### オプション

+----------+--------+--------------------------------+-----------+
|Option    |alias   |description                     |required?  |
+==========+========+================================+===========+
|--output  |-o      |output file path                |yes        |
+----------+--------+--------------------------------+-----------+

- 出力
    - 以下の様に、登録済みhostの情報をObjectの配列としてJSON形式で出力する。
    - hostにはid, name, hostname, userの情報のみ出力される。

    .. code-block:: javascript

      [
        {
          "id": "522fe89a899e53ec05000005",
          "name": "localhost",
          "hostname": "localhost",
          "user": "murase"
        }
      ]

simulator_template
--------------------------------

create_simulatorの時に使用するsimulator.jsonファイルのテンプレートを作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli simulator_template -o simulator.json

- オプション

  +----------+--------+--------------------------------+-----------+
  |Option    |alias   |description                     |required?  |
  +==========+========+================================+===========+
  |--output  |-o      |output file path                |yes        |
  +----------+--------+--------------------------------+-----------+

- 出力
    - Simulatorの属性情報のテンプレートを出力する

    .. code-block:: javascript

      {
        "name": "b_sample_simulator",
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

create_simulator
--------------------------------

Simulatorを新規作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli create_simulator -h host.json -i simulator.json -o simulator_id.json

- オプション

  +----------+--------+--------------------------------+-----------+
  |Option    |alias   |description                     |required?  |
  +==========+========+================================+===========+
  |--host    |-h      |executable hosts                |no         |
  +----------+--------+--------------------------------+-----------+
  |--input   |-i      |input file path                 |yes        |
  +----------+--------+--------------------------------+-----------+
  |--output  |-o      |output file path                |yes        |
  +----------+--------+--------------------------------+-----------+

- 入力ファイル

    - hostファイルは show_host で出力されるJSON形式のファイルを指定する。
    - inputファイルは simulator_template で出力されるJSON形式のファイルを指定する。
        - JSONのパスを指定してもよいし、JSONの文字列をそのまま渡しても良い

- 出力
    - 新規作成されたsimulatorのidをObjectとしてJSON形式で出力する。

    .. code-block:: javascript

      {
        "simulator_id": "52b3bcd7b93f964178000001"
      }

parameter_sets_template
--------------------------------

create_parameter_setsの時に使用するparameter_sets.jsonファイルのテンプレートを作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli parameter_sets_template -s 5361e421b93f96bbc500000e -o parameter_sets.json

- オプション

  +-----------+--------+--------------------------------+-----------+
  |Option     |alias   |description                     |required?  |
  +===========+========+================================+===========+
  |--simulator|-s      |simulator                       |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--output   |-o      |output file path                |yes        |
  +-----------+--------+--------------------------------+-----------+

- 入力ファイル

    - simulatorはSimulatorのIDを渡すか、create_simulator で出力されるJSON形式のファイルを指定する。

- 出力
    - ParameterSet作成時に使用するパラメータ指定ファイルのテンプレートを出力する。

    .. code-block:: javascript

      [
        {"p1":0,"p2":5.0}
      ]

create_parameter_sets
--------------------------------

ParameterSetを新規作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json

  .. code-block:: sh

    ./bin/oacis_cli create_parameter_sets -s 5361e421b93f96bbc500000e -i '{"p1":1,"p2":[2.0,3.0}' -o parameter_set_ids.json

- オプション

  +-----------+--------+--------------------------------+-----------+
  |Option     |alias   |description                     |required?  |
  +===========+========+================================+===========+
  |--simulator|-s      |simulator                       |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--input    |-i      |input json                      |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--run      |-r      |run-option json                 |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--output   |-o      |output file path                |yes        |
  +-----------+--------+--------------------------------+-----------+

- 入力ファイル

    - simulatorはIDを渡すか、create_simulatorで出力されるJSON形式のファイルを指定する。
    - inputファイルは parameter_sets_template で出力されるJSON形式のファイルを指定する。
        - またはJSONの文字列を指定しても良い。
        - パラメータとして配列を指定すると、複数のパラメータセットを同時に作る事ができる。
    - runは、指定されたParameterSetに対してRunの作成をする場合に指定する。
        - JSON形式の文字列、またはJSONファイルのパスを指定する。
        - runのフォーマットは以下の通り。

        .. code-block:: javascript

          { "num_runs":1,"mpi_procs":1,"omp_threads":1,"priority":1,
            "submitted_to":"522fe89a899e53ec05000005",
            "host_parameters":{"nodes":"1","ppn":"1","walltime":"10:00"}
          }

        - "submitted_to"フィールドにはHostのIDを指定する。
        - "host_parameters"フィールドは、各ホストで必要とされるパラメータを入力する。
        - それぞれのParameterSetが "num_runs" 個のRunを持つまでRunが作成される。

- 出力
    - 新規作成されたParameterSetのidをObjectの配列としてJSON形式で出力する。

    .. code-block:: javascript

      [
        {"parameter_set_id":"52b3ddc7b93f969b8c000001"}
      ]

- その他
    - 同じParameterの値を持つParameterSetが既に存在する場合には、新規にParameterSetを作成せずに既存のParameterSetのidを出力として返す。エラーにはならない。

job_parameter_template
--------------------------------

create_runsの時に使用するjob_parameter.jsonファイルのテンプレートを作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli job_parameter_template -h host_id -o job_parameter.json

- オプション

  +----------+--------+--------------------------------+-----------+
  |Option    |alias   |description                     |required?  |
  +==========+========+================================+===========+
  |--host_id |-h      |host id (string)                |no         |
  +----------+--------+--------------------------------+-----------+
  |--output  |-o      |output file path                |yes        |
  +----------+--------+--------------------------------+-----------+

- 入力
    - host idはHostのidを文字列で指定する。指定が無い場合はmanualでのジョブを投入する。

- 出力
    - Run作成時に使用するジョブパラメータ指定ファイルのテンプレートを出力する。

    .. code-block:: javascript

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

create_runs
--------------------------------

Runを新規作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli create_runs -p parameter_set_ids.json -j job_parameter.json -n 1 -o run_ids.json

- オプション

  +----------------+--------+--------------------------------+-----------+
  |Option          |alias   |description                     |required?  |
  +================+========+================================+===========+
  |--parameter_sets|-p      |parameter set id file           |yes        |
  +----------------+--------+--------------------------------+-----------+
  |--job_parameters|-j      |job parameter file              |yes        |
  +----------------+--------+--------------------------------+-----------+
  |--number_of_runs|-n      |number of runs (Integer)        |no         |
  +----------------+--------+--------------------------------+-----------+
  |--seeds         |-s      |seeds array (Json String)       |no         |
  +----------------+--------+--------------------------------+-----------+
  |--output        |-o      |output file path                |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - parameter_setsファイルは create_parameter_sets で出力されるJSON形式のファイルまたは文字列を指定する。
    - job_parameterファイルは job_parameter_template で出力されるJSON形式のファイルまたは文字列を指定する。
    - number_of_runs はRunの数を数値で指定する。各ParameterSetごとに、ここで指定された数になるまでRunが作られる。デフォルトは1。
    - seeds はRunのseedを数値の配列で指定する(--seeds "[0, 1, 2, 3]")。number_of_runs以上のseedが指定された場合、number_of_runsで指定された数になるまで指定されたseedでRunが作られる。

- 出力
    - RunのidをObjectの配列としてJSON形式で出力する。
    - 新規作成されていないRunについても、各ParameterSetごとにnで指定された数の分だけRunのidを出力する。

    .. code-block:: javascript

      [
        {"run_id":"52b3eaebb93f96933f000001"}
      ]

- その他
    - 既に指定された数のRunが存在する場合には、新規にRunを作成せずに既存のRunのidを出力として返す。エラーにはならない。

run_status
--------------------------------

Runの実行状況を確認する

- 実効方法

  .. code-block:: sh

    ./bin/oacis_cli run_status -r run_ids.json

- オプション

  +----------------+--------+--------------------------------+-----------+
  |Option          |alias   |description                     |required?  |
  +================+========+================================+===========+
  |--run_ids       |-r      |run id file                     |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - run_idsファイルは create_runs で出力されるJSON形式のファイルを指定する

- 出力
    - 指定されたRunのステータスを集計し、標準出力に表示する

    .. code-block:: javascript

      {
        "total": 1,
        "created": 0,
        "submitted": 0,
        "running": 0,
        "failed": 1,
        "finished": 0
      }

job_include
--------------------------------

手動実行したRunの実行結果を取り込む

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli job_include -i 52cde935b93f969b07000005.tar.bz2

- オプション

  +----------------+--------+--------------------------------+-----------+
  |Option          |alias   |description                     |required?  |
  +================+========+================================+===========+
  |--input         |-i      |input archive files             |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - inputファイルは手動実行後に生成される結果のアーカイブファイル(.tar.bz2)を指定する。
        - アーカイブファイルは空白区切り、またはコンマ区切りで複数指定可能。

destroy_runs
--------------------------------

Runを削除する

- 実行方法

  .. code-block:: sh

    ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:failed

- オプション

  +----------------+--------+-----------------------------------------+-----------+
  |Option          |alias   |description                              |required?  |
  +================+========+=========================================+===========+
  |--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--query         |-q      |query for runs(Hash)                     |yes        |
  +----------------+--------+-----------------------------------------+-----------+

- 入力形式

    - simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
    - queryは連想配列で指定する。
        - 連想配列は {key}:{value} という形式で指定する。
        - keyとして可能な値は"status", "simulator_version"のみ。

- 実行例

    - simulator_versionが"1.0.0"のRunを削除する

    .. code-block:: sh

        ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0

    - simulator_version が存在しないRunを削除する。

    .. code-block:: sh

        ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:

    - statusが "created" （ジョブ投入前）のRunを削除する。

    .. code-block:: sh

        ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:created

replace_runs
--------------------------------

指定したRunを削除して、同じ設定で新しいRunを再作成する

- ユースケース
    | 例えば、ジョブを大量に流したが古いコードにバグが見つかり再実験が必要になった場合などに使える。
    | 以前のRunと同じジョブパラメータ（投入ホスト、MPIプロセス数、OMPスレッド数、ホストパラメータ）で実行される。
    | ただし、乱数の種 _seed は変更される。

- 実行方法

  .. code-block:: sh

    ../bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:0.0.1

- オプション

  +----------------+--------+-----------------------------------------+-----------+
  |Option          |alias   |description                              |required?  |
  +================+========+=========================================+===========+
  |--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--query         |-q      |query for runs(Hash)                     |yes        |
  +----------------+--------+-----------------------------------------+-----------+

- 入力形式

    - simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
    - queryは連想配列で指定する。
        - 連想配列は {key}:{value} という形式で指定する。
        - keyとして可能な値は"status", "simulator_version"のみ。
        - "simulator_version" が空のものを指定したい場合には "simulator_version:" と指定する。

- 実行例

    - simulator_versionが"1.0.0"のRunを削除し、同じ設定で新しいRunを再作成する。

    .. code-block:: sh

        ../bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0

analyses_template
--------------------------------

create_analysesの時に使用するanalysis_parameters.jsonファイルのテンプレートを作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli analyses_template -a 5226f430899e532cf6000009 -o analysis_parameters.json

- オプション

  +--------------+--------+--------------------------------+-----------+
  |Option        |alias   |description                     |required?  |
  +==============+========+================================+===========+
  |--analyzer_id |-a      |analyzer id                     |yes        |
  +--------------+--------+--------------------------------+-----------+
  |--output      |-o      |output file path                |yes        |
  +--------------+--------+--------------------------------+-----------+

- 入力ファイル

    - analyzer_id はIDの文字列を指定する。

- 出力
    - Analysis作成時に使用するパラメータ指定ファイルのテンプレートを出力する。

    .. code-block:: javascript

      [
        {"parameter1":50,"parametr2":1.0}
      ]

create_analyses
--------------------------------

Analysisを新規作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -o analysis_ids.json

- オプション

  +-----------------+--------+---------------------------------------------------+-----------+
  |Option           |alias   |description                                        |required?  |
  +=================+========+===================================================+===========+
  |--analyzer       |-a      |analyzer id                                        |yes        |
  +-----------------+--------+---------------------------------------------------+-----------+
  |--input          |-i      |input file path                                    |no         |
  +-----------------+--------+---------------------------------------------------+-----------+
  |--output         |-o      |output file path                                   |yes        |
  +-----------------+--------+---------------------------------------------------+-----------+
  |--first_run_only |        |only on first runs                                 |no         |
  +-----------------+--------+---------------------------------------------------+-----------+
  |--target         |-t      |on targets(parmeter_set_ids.json or run_ids.json)  |no         |
  +-----------------+--------+---------------------------------------------------+-----------+

- 入力ファイル

    - analyzerはanalyzerのIDを指定する。
    - inputは analyses_template で出力されるJSON形式のファイルまたはJSON形式の文字列を指定する。デフォルトは、Analyzerに登録されたパラメータのデフォルト値。

- 出力
    - AnalysisのidをObjectの配列としてJSON形式で出力する。
    - 新規作成されていないAnalysisについても、Analysisのidを出力する

    .. code-block:: javascript

      [
        {"analysis_id":"52b3eaebb93f96933f00000d"}
      ]

- 実行例
    - 各ParameterSet のRun 1つに対してのみanalyzer を実行する。

      .. code-block:: sh

        ./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -o analysis_ids.json --first_run_only

    - 指定したParameterSet に対してanalyzer(:on_parameter_set) を実行する。

      .. code-block:: sh

        ./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -o analysis_ids.json -t parameter_set_ids.json

    - 指定したRun に対してanalyzer(:on_run) を実行する。

      .. code-block:: sh

        ./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -o analysis_ids.json -t run_ids.json

- その他
    - 既にAnalysisが存在する場合には、新規にAnalysisを作成せずに既存のAnalysisのidを出力として返す。エラーにはならない。
    - ParamterSetに対するAnalyzerを実行するとき、status:finished のRunが存在しないParameterSetを対象としたAnalysisは作成されない。

analysis_status
--------------------------------

Analysisの実行状況を確認する

- 実効方法

  .. code-block:: sh

    ./bin/oacis_cli analysis_status -a analysis_ids.json

- オプション

  +----------------+--------+--------------------------------+-----------+
  |Option          |alias   |description                     |required?  |
  +================+========+================================+===========+
  |--analysis_ids  |-a      |analysis id file                |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - analysis_idsファイルは create_analyses で出力されるJSON形式のファイルを指定する

- 出力
    - 指定されたAnalysisのステータスを集計し、標準出力に表示する

    .. code-block:: javascript

      {
        "total": 100,
        "created": 50,
        "running": 0,
        "failed": 1,
        "finished": 49
      }

destroy_analyses
--------------------------------

Analysisを削除する

- 実行方法

  .. code-block:: sh

    ../bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:v0.1.0

- オプション

  +----------------+--------+-----------------------------------------+-----------+
  |Option          |alias   |description                              |required?  |
  +================+========+=========================================+===========+
  |--analyzer_id   |-a      |analyzer id                              |yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--query         |-q      |query for analyses(Hash)                 |yes        |
  +----------------+--------+-----------------------------------------+-----------+

- 入力形式

    - analyzer_id はIDの文字列を指定する。
    - queryは連想配列で指定する。
        - 連想配列は {key}:{value} という形式で指定する。
        - keyとして可能な値は"status","analyzer_version"のみ。
        - “analyzer_version” が空のものを指定したい場合には “analyzer_version:” と指定する。

- 実行例

    - statusが "failed" （解析失敗）かつanalyzer_versionが "nil"のAnalysisを削除する

      .. code-block:: sh

        ../bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:

replace_analyses
--------------------------------

指定したAnalysisを削除して、同じ設定で新しいAnalysisを再作成する

- ユースケース
    | 例えば、Analyzerを更新して、結果の図を差し替える場合などに使える。
    | 以前のAnalysisと同じAnalyzer、同じパラメータで実行される。

- 実行方法

  .. code-block:: sh

    ../bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished analyzer_version:v0.1.0

- オプション

  +----------------+--------+-----------------------------------------+-----------+
  |Option          |alias   |description                              |required?  |
  +================+========+=========================================+===========+
  |--analzyer_id   |-a      |analyzer id                              |yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--query         |-q      |query for analyses(Hash)                 |yes        |
  +----------------+--------+-----------------------------------------+-----------+

- 入力形式

    - analyzer_id はIDの文字列を指定する。
    - queryは連想配列で指定する。
        - 連想配列は {key}:{value} という形式で指定する。
        - keyとして可能な値は"status","analyzer_version"のみ。
        - “analyzer_version” が空のものを指定したい場合には “analyzer_version:” と指定する。

- 実行例

    - statusが"finished"のAnalysisを削除し、同じ設定で新しいAnalysisを再作成する。

      .. code-block:: sh

        ../bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished

append_parameter_definition
--------------------------------

指定したSimulatorに、新しいParameterを追加する。

- ユースケース
    | 既存のSimulatorを拡張したいが、既存のデータを破棄したくない場合に使用する。

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n "new_param" -t Float -e 0.0

- オプション

  +----------------+--------+-----------------------------------------+-----------+
  |Option          |alias   |description                              |required?  |
  +================+========+=========================================+===========+
  |--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--name          |-n      |name of the new parameter                |yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--type          |-t      |type of the new parameter                |yes        |
  +----------------+--------+-----------------------------------------+-----------+
  |--default       |-e      |default value of the new parameter       |yes        |
  +----------------+--------+-----------------------------------------+-----------+

- 入力形式

    - simulator_id はIDの文字列か、simulator_id.jsonのファイルのパスを指定する。
    - name は新規パラメータの名前を指定する。既存のパラメータと重複するとエラー。
    - type は新規パラメータの型を指定する。指定可能な値は "Integer", "Float", "String", "Boolean" の４種類。
    - default は新規パラメータのデフォルト値を指定する。
        - type と整合性が取れていない場合はエラー
        - 既存のパラメータセットのパラメータはこの値で保存される。

- 実行例

    - "p3" という名前の整数型のパラメータ（デフォルト値 0）を追加する。

      .. code-block:: sh

        ./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n p3 -t Integer -e 0

- 注意事項
    - 既に作成済みのRunについては更新されない。
簡単なシミュレータを実際に実行し、結果を参照するまでの最小の手順をここで示す。

---

## 手順

1. ここで扱うシミュレータについて
1. Host登録
1. Simulator登録
1. ParameterSet登録
1. ジョブ投入
1. 実行中のジョブの確認
1. 結果の確認

#### ここで扱うシミュレータについて

このチュートリアルでは、２つの浮動小数点型のパラメータ"p1", "p2"を持つとする。
このシミュレータは以下の様にパラメータと乱数の種を引数で受け取り実行できるように、各実行ホストでビルドをしておく。

```
~/path/to/simulator.out {p1} {p2} {seed}
```

パラメータをシミュレータに渡す方法として、JSONで渡す方法もある。Simulator登録の項目を参照の事。

## Host登録

シミュレータを実行するためのホストを登録する。
前提条件として、サーバーからシミュレータを実行するホストに鍵認証を使用してパスワード無しでSSHログインできるようにしておかなくてはいけない。
ここでは鍵認証でリモートホストにSSHログインできるという前提で話を進める。
また、ホストでジョブスケジューラ(xsub) が実行可能でなければならない。
xsub の設定方法については、https://github.com/crest-cassia/xsub を参照すること。

ナビゲーションバーの[Hosts]をクリックし、[New Hosts]のボタンを押すと新規Host登録画面が表示される。

![ホスト登録]({{ site.baseurl }}/images/hosts.png){:width="400px"}

このページの入力フィールドにホストの情報を登録する。登録する項目は以下の通り。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name                       | OACISの中で使われるHostの名前。任意の名前を指定できる。一意でなくてはならない。 |
| Hostname                   | ssh接続先のhostnameまたはIPアドレス。 |
| User                       | ssh接続時に使用するユーザー名。 |
| Port                       | ssh接続先のポート番号。デフォルトは22。 |
| SSH key                    | ssh接続時の鍵認証で使用する秘密鍵ファイルへのパス。デフォルトは *~/.ssh/id_rsa* |
| Scheduler Type             | ジョブスケジューラのタイプ。none(スケジューラ無し)、xsubから選択する。（その他はv1.14.0で廃止予定） |
| Work base dir              | ワークディレクトリとして利用するホスト上のパス。ここで指定したパス以下でジョブが実行される。 |
| Mounted work base dir      | localhostでジョブを実行する場合やホームディレクトリがNFSで共有されている場合など、直接ワークディレクトリが参照できる場合、ここで指定したディレクトリから直接ジョブの取り込みが行われパフォーマンスが向上する。 |
| Max num jobs               | このホストに投入可能なジョブの最大数。 |
| MPI processes              | MPIプロセス数の最小値と最大値。Runを作成するときにここで指定した範囲外の値を指定しようとするとエラーになる。 |
| OMP threads                | OMPスレッド数の最小値と最大値。Runを作成するときにここで指定した範囲外の値を指定しようとするとエラーになる。 |
| Executable simulators      | 実行可能なシミュレータをチェックボックスで指定。 |
|----------------------------|---------------------------------------------------------------------|


本チュートリアルでは以下のように設定する。その他はデフォルト。
Work base dir は任意のディレクトリで良いが、新規作成した（他のファイルが無い）ディレクトリを指定する事。

- Name: localhost
- Hostname: localhost
- User: <自分のユーザー名>
- Work base dir: <任意の新規作成したパス>

ホストの登録後、一覧画面で登録したホストを確認する事ができる。
一覧画面の表の各行はドラッグして移動する事ができ、見やすい順番に整理する事ができる。

## Simulator登録

扱うシミュレータは、言語やマシンを問わず自由に作成できる。（OACISは登録されたコマンドを実行するだけなので、どの言語で実装されているかは関係ない。）
ただし、以下の要件を満たす必要がある。

- 出力ファイルがカレントディレクトリ以下に作成される事
    - OACISは実行時にディレクトリを作り、その中でジョブを実行する。完了後、そのディレクトリ内のファイルすべてを出力結果として取り込む。
- パラメータの入力を引数またはJSONで受け付ける事
    - 引数渡しの場合はパラメータが定義された順番に引数で渡されて、最後の引数として乱数の種が渡される。
        - 例えば、param1=100, param2=3.0, seed(乱数の種)=12345 の場合、以下のコマンドが実行される
            ```
              ~/path/to/simulator.out 100 3.0 12345
            ```
    - JSON形式の場合、実行時に次のような形式のJSONファイルを *_input.json* というファイル名でOACISが実行時に配置する。シミュレータはカレントディレクトリの *_input.json* パースするように実装する必要がある。
        ```
          {"param1":100,"param2":3.0,"_seed":12345}
        ```
        - 乱数の種は _seed というキーで指定される。
        - 実行コマンドは以下のように引数なしで実行される。
            ```
              ~/path/to/simulator.out
            ```

- 以下の名前のファイルがカレントディレクトリにあっても問題なく動作し、これらのファイルを上書きしたりしないこと
    - *_input.json* , *_output.json* , *_status.json* , *_time.txt*, *_version.txt*
    - これらのファイルはOACISが使用するファイル名であるため干渉しないようにする必要がある
- 正常終了時にリターンコード０、エラー発生時に０以外を返す事
    - リターンコードによってシミュレーションの正常終了/異常終了が判定される。

シミュレータはあらかじめ実行ホスト上でビルドしておき実行可能な状態で配置しておく必要がある。
また複数のホストで実行する場合、シミュレータを同一のパスに配置する必要がある。
絶対パスで指定するよりもホームディレクトリからの相対パスで指定した方がホスト間の差異を吸収しやすい。

Simulator一覧ページ(/simulators)で[New Simulator]ボタンをクリックすると新規Simulator登録画面が表示される。

![ホスト登録]({{ site.baseurl }}/images/new_simulator.png){:width="400px"}

このページの入力フィールドにシミュレータの情報を登録する。登録する項目は以下の通り。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name                       | シミュレータの名前。Ascii文字、数字、アンダースコアのみ使用可。一意でなくてはならない。
| Definition of Parameters   | シミュレータの入力パラメータの定義。パラメータの名前、型(Integer, Float, String, Boolean)、デフォルト値、パラメータの説明（任意）を入力する。
| Preprocess Script          | ジョブの前に実行されるプリプロセスを記述するスクリプト。空の場合はプリプロセスは実行されない。
| Command                    | シミュレータの実行コマンド。リモートホスト上でのパスを絶対パスかホームディレクトリからの相対パスで指定する。（例. *~/path/to/simulator.out* ）
| Pirnt version command      | シミュレータのversionを標準出力に出力するコマンド。（例. *~/path/to/simulator.out --version* ）
| Input type                 | パラメータを引数で渡すか、JSONで渡すか指定する。
| Support mpi                | シミュレータがMPIで実行されるか。チェックを入れた場合、mpiexecコマンド付きで実行される。
| Support omp                | シミュレータがOpenMPで並列化されているか。チェックを入れた場合、環境変数OMP_NUM_THREADSで並列数を指定して実行される。
| Description                | シミュレータの説明を入力する。（markdownフォーマット[http://daringfireball.net/projects/markdown/syntax]で入力できる。）
| Executable_on              | 実行可能Hostを指定する。
|----------------------------|---------------------------------------------------------------------|

本チュートリアルでは以下のように設定する。その他はデフォルト。

- Name: a_sample_simulator
- Definition of Parameters: [[param1, Integer, 0], [param2, Float, 5.0]]
- Command: ~/path/to/simulator.out
- Executable_on: localhostにチェック

シミュレータの登録後、一覧画面で登録したシミュレータを確認する事ができる。
一覧画面の表の各行はドラッグして移動する事ができ、見やすい順番に整理する事ができる。



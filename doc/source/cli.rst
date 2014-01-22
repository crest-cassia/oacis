==========================================
Command Line Interface(CLI)の使い方
==========================================

| Web browser経由で対話的な操作に加え、コマンドライン経由でSimulator, ParameterSet, Runの作成をするためのプログラム(CLI)が用意されている。
| 対話的な操作ではできないような多数のParameterSetやRunを一度に作成したい場合に有効であるだけでなく、他のプログラムからOACISを操作する用途にも利用可能である。
| ここではCLIの基本的な使い方を説明する。

CLIで利用可能な操作一覧
===================================

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

OACISのチェックアウトディレクトリ以下の bin/oacis_cli に引数を渡して実行する操作を指定する。
例えば

::

  ./bin/oacis_cli usage

このドキュメント内ではOACISのチェックアウトディレクトリから実行することを想定してコマンド例を示すが、どのディレクトリから実行しても良い。

usage
--------------------------------

CLIの各コマンドの使用方法を表示する

- 実行方法

  .. code-block:: sh

     ./bin/oacis_cli usage

show_host
--------------------------------

登録済みHost一覧の情報を取得する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli show_host -o host.json

- オプション

  +----------+--------+--------------------------------+-----------+
  |Option    |alias   |description                     |required?  |
  +==========+========+================================+===========+
  |--output  |-o      |output file path                |yes        |
  +----------+--------+--------------------------------+-----------+

- 出力
    - 以下の様に、登録済みhostの情報をObjectの配列としてJSON形式で出力する。
    - hostにはid, name, hostname, userの情報のみ出力される

    .. code-block:: json

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

    .. code-block:: json

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

    - hostファイルは show_host で出力されるJSON形式のファイルを指定する
    - inputファイルは simulator_template で出力されるJSON形式のファイルを指定する

- 出力
    - 新規作成されたsimulatorのidをObjectとしてJSON形式で出力する。

    .. code-block:: json

      {
        "simulator_id": "52b3bcd7b93f964178000001"
      }

parameter_sets_template
--------------------------------

create_parameter_setsの時に使用するparameter_sets.jsonファイルのテンプレートを作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli parameter_sets_template -o simulator.json

- オプション

  +-----------+--------+--------------------------------+-----------+
  |Option     |alias   |description                     |required?  |
  +===========+========+================================+===========+
  |--simulator|-s      |simulator file                  |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--output   |-o      |output file path                |yes        |
  +-----------+--------+--------------------------------+-----------+

- 入力ファイル

    - simulatorファイルは create_simulator で出力されるJSON形式のファイルを指定する

- 出力
    - ParameterSet作成時に使用するパラメータ指定ファイルのテンプレートを出力する

    .. code-block:: json

      [
        {"p1":0,"p2":5.0}
      ]

create_parameter_sets
--------------------------------

ParameterSetを新規作成する

- 実行方法

  .. code-block:: sh

    ./bin/oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json

- オプション

  +-----------+--------+--------------------------------+-----------+
  |Option     |alias   |description                     |required?  |
  +===========+========+================================+===========+
  |--simulator|-s      |simulator file                  |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--input    |-i      |input file path                 |yes        |
  +-----------+--------+--------------------------------+-----------+
  |--output   |-o      |output file path                |yes        |
  +-----------+--------+--------------------------------+-----------+

- 入力ファイル

    - simulatorファイルは create_simulator で出力されるJSON形式のファイルを指定する
    - inputファイルは parameter_sets_template で出力されるJSON形式のファイルを指定する

- 出力
    - 新規作成されたParameterSetのidをObjectの配列としてJSON形式で出力する。

    .. code-block:: json

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
    - host idはHostのidを文字列で指定する。指定が無い場合はmanualでのジョブ投入。

- 出力
    - Run作成時に使用するジョブパラメータ指定ファイルのテンプレートを出力する

    .. code-block:: json

      {
        "host_id": "522fe89a899e53ec05000005",
        "host_parameters": {
          "nodes": "1",
          "ppn": "1",
          "walltime": "10:00"
        },
        "mpi_procs": 1,
        "omp_threads": 1
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
  |--output        |-o      |output file path                |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - parameter_setsファイルは create_parameter_sets で出力されるJSON形式のファイルを指定する
    - job_parameterファイルは job_parameter_template で出力されるJSON形式のファイルを指定する
    - number_of_runs はRunの数を数値で指定する。各ParameterSetごとに、ここで指定された数になるまでRunが作られる。デフォルトは1。

- 出力
    - RunのidをObjectの配列としてJSON形式で出力する。
    - 新規作成されていないRunについても、各ParameterSetごとにnで指定された数の分だけRunのidを出力する

    .. code-block:: json

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

    .. code-block:: json

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

- 実効方法

  .. code-block:: sh

    ./bin/oacis_cli job_include -i 52cde935b93f969b07000005.tar.bz2

- オプション

  +----------------+--------+--------------------------------+-----------+
  |Option          |alias   |description                     |required?  |
  +================+========+================================+===========+
  |--input         |-i      |input archive files             |yes        |
  +----------------+--------+--------------------------------+-----------+

- 入力ファイル

    - inputファイルは手動実行後に生成される結果のアーカイブファイル(.tar.bz2)を指定する
        - 空白区切り、またはコンマ区切りで複数指定可能

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

    - simulator_version が存在しないRunを削除する

    .. code-block:: sh

        ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:

    - statusが "created" （ジョブ投入前）のRunを削除する

    .. code-block:: sh

        ../bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:created

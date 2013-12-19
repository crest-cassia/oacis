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
- Simulator作成 (create_simulator)
- Simulator作成用テンプレート作成 (simulator_template)
- ParameterSet作成 (create_parameter_sets)
- ParameterSet作成用テンプレート作成 (parameter_sets_template)
- ジョブパラメータ指定用テンプレート作成 (job_parameter_template)
- Run作成 (create_runs)
- 作成済みRunのステータス確認 (run_status)

OACISのチェックアウトディレクトリ以下の bin/oacis_cli に引数を渡して実行するアクションを指定する。
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

  +----------+--------+--------------------------------+
  |Option    |alias   |description                     |
  +==========+========+================================+
  |--output  |-o      |output file path                |
  +----------+--------+--------------------------------+

実行例
===============================================

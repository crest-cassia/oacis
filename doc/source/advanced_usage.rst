==========================================
高度な使い方
==========================================

スケジューラを経由してジョブを実行する
==========================================

| ジョブスケジューラー（Torqueなど）を経由してジョブを実行する方法について説明する。
| Host登録時にジョブスケジューラを指定する事にって、スケジューラのジョブ投入コマンド経由でジョブが実行されるようになる。
| 現在サポートされているスケジューラはTorqueとPJM(Fujitsu FX10で採用されているジョブスケジューラ)のみである。
| 以降ではTorqueにジョブを投げるケースを想定して説明する。

ジョブスクリプトのヘッダに特別な指定がいらないケース
-----------------------------------------------------

| シングルスレッド、シングルプロセスのジョブでジョブスクリプトのヘッダに特別な記述が必要ない場合は、Hostの登録時にスケジューラタイプとして *Torque* を選択するだけでよい。
| このようにセットしておけば、workerがジョブスクリプトをqsubコマンドで実行し、その際に取得したTorqueのジョブIDはRunと紐付けて記録される。
| workerは定期的に qstat コマンドで得られた結果をパースしてジョブの状態をモニターし、ジョブの完了後に計算結果を取得する。
| 実行中に異常終了した場合、途中までの結果をサーバーにダウンロードしRunのステータスを *failed* として記録する。
| 実行中にユーザーによってRunが削除された場合は、qdelコマンドを使用してジョブを停止させる。

| PJMの場合には pjsub, pjstat, pjdel コマンドを使用してジョブの管理を行う。

ジョブスクリプトのヘッダに変数を指定するケース
----------------------------------------------

| ジョブスクリプトのヘッダにスケジューラのパラメータ（使用時間、占有するノード数、使用メモリ量など）を指定する必要があるケースについて説明する。
| ここでは例としてMPIで並列化しているシミュレータを、Torqueのスケジューラを使って占有時間を指定して実行することを考える。

| ジョブスクリプトのヘッダに指定する変数は以下のようになる。

.. code-block:: sh

  #!/bin/bash
  #PBS -l nodes=2:ppn=4
  #PBS -l walltime=10:00
  ...

| ここでnodesが使用するノード数、ppnは各ノード内のプロセス数、walltimeが実行制限時間である。
| 各ジョブによってこれらの値が異なるため、Runの作成時にこれらの値を指定できるようにする。

| そのためにはホストパラメータと呼ぶ仕組みを使用する。
| ホストパラメータとして指定した変数は各Runの作成時に個別に入力することができ、その変数がHostのテンプレート部分に展開される。

| 具体的には以下の手順でHostの "template", "Definition of Host Parameters" というフィールドを設定する。

1. templateの変数展開をしたい部分を *<%= ... %>* という記号で囲む。今回の例ではヘッダ部分を以下のように編集する。

  .. code-block:: sh

    #!/bin/bash
    #PBS -l nodes=<%= nodes %>:ppn=<%= ppn %>
    #PBS -l walltime=<%= walltime %>
    ...

2. "Definition of Host Parameter"の部分に展開したい変数の変数名、デフォルト値、フォーマット（入力可能な形式を正規表現で指定）を入力する。
今回の場合、以下のように設定する。（formatの部分は空でもよいが、設定しておくとRunの作成時に不正な値を入れるとエラーになるのでミスに気づきやすくなる。）

  * Name: nodes,    Default: 1, format: ^\d+$
  * Name: ppn,      Default: 1, format: ^\d+$
  * Name: walltime, Default: 10:00, format: ^(\d\d:)?\d\d:\d\d$

  .. image:: images/edit_host_template.png
    :width: 50%
    :align: center

  | この際、テンプレートとホストパラメータ定義が整合していないとエラーとなる。
  | テンプレートで展開する変数は必ずホストパラメータとして定義されている必要があり、ホストパラメータとして定義された変数はテンプレート中に現れなくてはならない。

| 以上でHostの設定は完了である。
| この設定後、Runの作成時に以下のようにホストパラメータを入力する箇所が現れる。
| 適切な値を入れて [Preview] ボタンをクリックするとジョブスクリプトのプレビューが表示される。
| [Create Run]をクリックするとRunが作成され、順番にジョブが投入される。

.. image:: images/new_run_with_host_params.png
  :width: 30%
  :align: center

MPI, OpenMPのジョブ
-------------------------------------------------------------

| MPI, OpenMPで並列化されたシミュレータの場合、実行時にMPIのプロセス数、OpenMPのスレッド数を指定することが必要となる。
| Simulator登録時に、 *Suppot MPI*, *Support OMP* のチェックを入れると、Runの作成時にプロセス数とスレッド数を指定するフィールドが表示されるようになる。

.. image:: images/new_run_mpi_omp_support.png
  :width: 30%
  :align: center

| ここで指定したプロセス数・スレッド数はテンプレートの中でそれぞれ *<%= mpi_procs %>*, *<%= omp_threads %>* という変数に展開される。
| Hostのテンプレートを確認すれば分かるとおり、OpenMPのスレッド数はジョブスクリプトの中で環境変数 *OMP_NUM_THREADS* に代入される。
| 同様にMPIのプロセス数は、mpiexec コマンドの -n オプションの引数に展開される。
| これによりシミュレータが指定したプロセス数・スレッド数で実行されるようにしている。

| つまりOpenMPで並列化しているシミュレータはOMP_NUM_THREADS環境変数を参照してスレッド数を決めるように実装されていなければならない。
| （ プログラム内で *omp_set_num_threads()* 関数で別途指定している場合は、当然ながらここで指定したスレッド数は適用されない）

| MPIで並列化している場合、プロセス数は *mpiexec* コマンドの引数で渡されるが、 *mpiexec* コマンド以外のMPIプロセス実行コマンドを指定したい場合はHostのテンプレートを編集すればよい。

| ジョブスクリプトのヘッダ部分でも <%= mpi_procs %>, <%= omp_threads %> 変数を展開することができる。
| これを利用するとMPIプロセス数に応じて確保するノード数を自動的に決めたりすることができる。
| 例として、Flat MPIのプログラムを、１ノードあたり８コアのマシンで実行することを考える。
| Hostのテンプレートに以下のように書くことで、ノード数が自動的に指定されるようになる。（ただし、プロセス数は８の倍数にする必要がある）

.. code-block:: sh

  #!/bin/bash
  #PBS -l nodes=<%= mpi_procs / 8 %>:ppn=8
  #PBS -l walltime=10:00
  ...

京コンピュータのPJMを利用するケース
----------------------------------------------

| 京コンピュータでジョブを実行する場合、ノード形状やelapse timeやステージング情報をジョブスクリプトに記載する必要がある。
| また、若干の修正(PRE-PROCESS, JOB EXECUTION)が必要である。
| 以下では、実行時ディレクトリからみて、 ./signals/ 以下の設定ファイルを読み込み、 ./result/inst/ 以下に結果を出力するシミュレータでの例を示す。(シミュレータ依存の操作はOptionalと示される。)

0. プリプロセスでの処理

  - 下記(1. 2. 3.)に続くジョブスクリプトへの修正を行うことで、プリプロセスが実行されるディレクトリ以下をステージイン可能となる。しかし、実行に必要なバイナリや設定ファイルをジョブスクリプト実行ディレクトリ以下に配置する作業や実行コマンドの微修正などをあらかじめ実行しておく必要がある。
  - 例えば、バイナリの移動(need)や設定ファイル群の移動(optional)には、下記のようにコマンドをプリプロセスに追加する。

  .. code-block:: sh

    cp ~/path/to/simulator.out . #(Need)
    cp -r ~/path/to/signals . #(Optional)

  - 例えば、シミュレータの実行コマンドをステージイン後のパスに変更するには、実行コマンドを *SIMCMD.txt* ファイルに書き出す処理をプリプロセスに追加し、ジョブスクリプトから読み込む。(Optional)

  .. code-block:: sh

    echo "./simulator.out" > SIMCMD.txt

1. ステージングへの対応

  - PJM --vset は、PJM内で利用する変数を定義する。ここでは、OACIS_RUN_IDとOACIS_WORK_BASE_DIRを定義している。
  - PJM --stgin-dir "./${OACIS_RUN_ID}/ ./${OACIS_RUN_ID}/"は、_input.jsonや設定ファイルを転送する。
  - PJM --stgin-basedir ${OACIS_WORK_BASE_DIR}は、ステージインするベースディレクトリを指示する。
  - PJM --stgin-dir "./${OACIS_RUN_ID}/signals/ ./${OACIS_RUN_ID}/signals/"は、signalsディレクトリ以下のファイルを転送する。(Optional)
  - PJM --stgout-basedir ${OACIS_WORK_BASE_DIR}は、ステージアウトするベースディレクトリを指示する。
  - PJM --stgout "./* ./"は、すべてのファイル(ディレクトリは含まない)を転送する。(デフォルトでは、${RUN_ID}.tar.bz2がステージアウトされる。)

  .. code-block:: sh

    #!/bin/bash -x
    #
    #PJM --rsc-list "node=1"
    #PJM --rsc-list "elapse=0:05:00"
    #PJM --vset OACIS_RUN_ID=<%= run_id %>
    #PJM --vset OACIS_WORK_BASE_DIR=<%= work_base_dir %>
    #PJM --stgin-basedir ${OACIS_WORK_BASE_DIR}
    #PJM --stgin-dir "./${OACIS_RUN_ID}/ ./${OACIS_RUN_ID}/"
    #PJM --stgin-dir "./${OACIS_RUN_ID}/signals/ ./${OACIS_RUN_ID}/signals/"
    #PJM --stgout-basedir ${OACIS_WORK_BASE_DIR}
    #PJM --stgout "./* ./"
    #PJM -s
    #
    LANG=C

2. PRE-PROCESSへの修正

  - mkdir -p result/instは、シミュレータの実行結果を出力するのに必要なフォルダを生成する。(Optional)

  .. code-block:: diff

    # PRE-PROCESS ---------------------
    + . /work/system/Env_base
    + mkdir -p result/inst
    - #mkdir -p ${OACIS_WORK_BASE_DIR}
    - #cd ${OACIS_WORK_BASE_DIR}
    - mkdir -p ${OACIS_RUN_ID}
    cd ${OACIS_RUN_ID}
    if [ -e ../${OACIS_RUN_ID}_input.json ]; then
    \mv ../${OACIS_RUN_ID}_input.json ./_input.json
    fi
    echo "{" > ../${OACIS_RUN_ID}_status.json
    echo "  \"started_at\": \"`date`\"," >> ../${OACIS_RUN_ID}_status.json
    echo "  \"hostname\": \"`hostname`\"," >> ../${OACIS_RUN_ID}_status.json

3. JOB EXECUTIONへの修正

  - SIMCMD=`cat SIMCMD.txt`は、シミュレータ実行コマンドを *SIMCMD.txt* から読み込む。SIMCMD.txtは、Simulatorのプリプロセスで生成しておく。(Optional)

  .. code-block:: diff

    # JOB EXECUTION -------------------
    + SIMCMD=`cat SIMCMD.txt` #SIMCMD.txt is created by _preprocess.sh
    if ${OACIS_IS_MPI_JOB}
    then
      export OMP_NUM_THREADS=${OACIS_OMP_THREADS}
    -  { time -p { { mpiexec -n ${OACIS_MPI_PROCS}  <%= cmd %>; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
    +  { time -p { { mpiexec -n ${OACIS_MPI_PROCS} ${SIMCMD}; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
    else
    -  { time -p { { <%= cmd %>; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
    +  { time -p { { ${SIMCMD}; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
    fi
    echo "  \"rc\": $?," >> ../${OACIS_RUN_ID}_status.json
    echo "  \"finished_at\": \"`date`\"" >> ../${OACIS_RUN_ID}_status.json
    echo "}" >> ../${OACIS_RUN_ID}_status.json


手動でジョブを実行する
==============================================

| OACIS上でRunを作るとworkerによってジョブ投入が自動で行われるが、ジョブの実行を手動で行う事もできる。
| Run作成時に手動実行を指定した場合、自動ジョブ投入は行われずジョブスクリプトの生成のみ行われる。
| そのジョブスクリプトをユーザーが手動で実行し、結果を後からOACISに取り込む事が可能である。

| 手動で実行することにより、手間は増えるが細かなスクリプトのカスタマイズが可能である。
| 例えば、以下の様な用途に利用できる。

    - 複数のRunを一つのジョブとしてスケジューラに投入する場合
        - スケジューラのジョブ数に制限がある場合などにまとめて投入する事ができる
            - 例：京のバルクジョブ
    - スケジューラの制限時間よりも長いジョブを実行する場合
        - 一度の実行ではジョブが完了せずジョブのリスタートが必要になる場合には、一つのRunに対して複数回ジョブ投入が必要になる
    - スケジューラに投入するジョブスクリプトに特殊な設定が必要な場合
        - OACISによって生成されたスクリプトを手動で編集する事によって、実効方法をカスタマイズできる

| 手動実行を行うためにはRunの作成時に投入Host選択フィールドで "manual submission" を選択する。
| Runの作成後に `${OACIS_ROOT}/public/Result_development/manual_submission` ディレクトリにシェルスクリプトが生成される。
| パラメータの入力形式がJSON形式の場合には、入力用JSONファイルも作成される。

.. image:: images/manual_submission.png
  :width: 30%
  :align: center

| ユーザーが以下のように生成されたジョブスクリプト実行すると、ジョブが実行される。

.. code-block:: sh

  bash 52cde935b93f969b07000005.sh

| シミュレーション実行結果のファイル（今回の例の場合 52cde935b93f969b07000005.tar.bz2）は以下のコマンドでデータベースに取り込む事ができる。

.. code-block:: sh

  ./bin/oacis_cli job_include -i 52cde935b93f969b07000005.tar.bz2

| 上記コマンドの入力ファイルはスペース区切りまたはコンマ区切りで複数ファイルを指定できる。

結果をMongoDB内に格納する
==============================================

| 通常シミュレータが出力したファイル群はそのままファイルとしてサーバー上に保存されるが、結果をMongoDB内に保存することもできる。
| 結果をMongoDB内に保存しておくと後で結果の値に対してクエリをかけることができる。
| 例えば、様々なジョブを実行したあとに結果がある値近傍のParameterSetを列挙するといったことができる。

| 結果をDB内に保存するためには、保存したいデータをJsonフォーマットでシミュレータから出力すればよい。
| `_output.json` という名前でカレントディレクトリ直下にJSONを作成すれば、データベースへの格納時にファイルがパースされDB内に保存される。

| 格納された結果は以下のようにブラウザから閲覧可能である。

.. image:: images/run_results.png
  :width: 40%
  :align: center

.. _manage_simulator_version:

シミュレーターのバージョンを記録する
==============================================

| シミュレーションの実行時にどのバージョンのシミュレーターで実行したかOACISに記録をさせておくことができる。
| RunとSimulatorのバージョンをひもづけて記録する事により、例えば、あるバージョンの実行結果の一括削除などの操作ができる様になる。

| バージョンを保存するには、Simulatorのバージョンを出力させるコマンドをOACISに登録する。
| 例えば

.. code-block:: sh

  ~/path/to/simulator.out --version

| というコマンドでバージョン情報を出力するシミュレーターがある場合、このコマンドをSimulator登録時に "Print version command" というフィールドに入力する。
| このコマンドを登録しておくと、ジョブスクリプトの中でこのコマンドを実行しその標準出力をバージョンとして記録することができる。

| Print version command の標準出力に出力された文字列がバージョンとして認識されるので、実行バイナリに引数を渡すだけでなく柔軟な指定が可能である。
| 例えば、以下のように手動でタグをつけたり、ビルドログを出力したり、バージョン管理システムのコミットIDを出力するような利用方法も考えられる。

.. code-block:: sh

  echo "v1.0.0"

.. code-block:: sh

  cat ~/path/to/build_log.txt

.. code-block:: sh

  cd ~/path/to; git describe --always

プリプロセスの定義
==============================================

| シミュレータによっては実際にシミュレーションジョブを開始する前に、入力ファイルを準備したりフォーマットを調整したりするプリプロセスが必要な場合がしばしばある。
| しかしプリプロセスを計算ジョブの中で行おうとすると以下のようなケースで問題になる。

  * スクリプト言語など入力ファイルの準備に使うプログラムが計算ノードにインストールされていないケース
  * 外部へのネットワークが遮断され入力用ファイルを準備するために外部からファイルを転送することができないケース
  * ファイルのステージングの都合により、ジョブの実行前にファイルをすべて用意する必要があるケース

| そこで、OACISにはジョブの実行前にプリプロセスを個別に実行する仕組みを用意してある。
| このプリプロセスはジョブの投入前にログインノードで実行されるため上記の問題は起きない。
| ここではプリプロセスの仕様と設定方法を説明する。

| プリプロセスはジョブの投入前にworkerによってssh経由で実行される。
| workerの実行手順は

  1. 各Runごとにワークディレクトリを作成する
  2. SimulatorがJSON入力の場合、_input.jsonを配置する。
  3. Simulatorの *pre_process_script* フィールドに記載されたジョブスクリプトをワークディレクトリに配置し実行権限をつける。(_preprocess.sh というファイル名で配置される)
  4. _preprocess.sh をワークディレクトリをカレントディレクトリとして実行する。

    * この際Simulatorが引数形式ならば、同様の引数を与えて _preprocess.sh を実行する。この引数から実行パラメータを取得することができる。
    * 標準出力、標準エラー出力は _stdout.txt, _stderr.txt にそれぞれリダイレクトされる。

  5. _preprocess.sh のリターンコードがノンゼロの場合には、SSHのセッションを切断しRunをfailedとする。

    * failedの時には、ワークディレクトリの内容をサーバーにコピーし、リモートサーバー上のファイルは削除する。

  6. _preprocess.sh を削除する
  7. シミュレーションジョブをサブミットする。

| ただし、 Simulatorの pre_process_script のフィールドが空の場合には、上記3~6の手順は実行されない。

Analyzerの登録と実行
==============================================

| ジョブの実行後、実行結果に対してポストプロセス（Analyzer）を定義することができる。
| OACISで定義できるAnalyzerには２種類存在する。
| 一つは各個別のRunに対して実行されるもの、もう一つはParameterSet内のすべてのRunに対して行われるものである。
| 前者の例としては、シミュレーションのスナップショットデータから可視化を行う、時系列のシミュレーション結果に対してフーリエ変換する、などがあげられる。
| 後者の例は、複数のRunの統計平均と誤差を計算することなどがあげられる。
| OACISの用語として、Analyzerによって得られた結果はAnalysisと呼ばれる。AnalyzerとAnalysisの関係は、SimulatorとRunの関係のようなものである。

| Analyzerはサーバー上でバックグラウンドプロセスとして実行される。(すなわち、Host上で実行されない点がプリプロセスと異なる。)よってサーバー上でanalyzerが適切に動くように事前にセットアップする必要がある。
| ユーザーはAnalyzerの登録時に実行されるコマンドを入力する。そのコマンドがバックグラウンドで呼ばれて解析が実行されることになる。
| Simulatorの場合と同じように、実行日時や実行時間などの情報が保存され、結果はブラウザ経由で確認できる。

| また、Analyzerは実行時に解析用のパラメータを指定して実行することもできる。
| 例えば、時系列データを解析するときに最初の何ステップを除外するか指定したい場合などに使える。
| Analyzerの登録時にパラメータの定義を登録することができる。

| 実行時には新規にそのAnalyzer専用のワーキングディレクトリが作られ、そこでAnalyzerとして定義されたコマンドが実行される。
| Simulatorの場合と同様にワーキングディレクトリ以下のファイルがそのままサーバー上に保存されるため、カレントディレクトリ以下に結果を出力するようにAnalyzerを実装する必要がある。
| 結果のファイルに `_output.json` というファイルが存在する場合に、パースされてデータベースに格納されるのもSimulatorと同様である。

| 解析対象となるRunの結果もワーキングディレクトリ以下に配置されるが、解析対象がRunかParameterSetかによって異なるため以下で個別に説明する。

Runに対する解析
----------------------------------------------

| ここではRunに対する解析の例として、時系列データを出すシミュレーションのanalyzerとして、時系列をグラフにプロットすることを考える。
| シミュレータが以下の形式のファイルをsample.datというファイル名で出力することとする。１列目が時刻、２列目がプロットするデータを表す。

.. code-block:: none

  1 0.25
  2 0.3
  3 0.4
  ...

| Analyzerの実行時には、Runの結果は *_input/* というディレクトリに保存される。
| Analyzerはそのディレクトリにあるファイルを解析できるように実装する。

| 例として、入力の時系列をgnuplotでプロットする。
| 次に示すようなgnuplot入力ファイルを作成し、どこかのパス（例として ~/path/to/plotfile.pltというパスにする）に保存する。

.. code-block:: none

  set term postscript eps
  set output "sample.eps"
  plot "_input/time_series.dat" w l

| これでAnalyzerの準備ができたので、OACISに登録する
| Simulatorの画面を開き、[About]タブをクリックするとAnalyzerを新規登録するためのリンク[New Analyzer]が表示される。
| そのリンクをクリックすると下図のような登録画面が現れる。

.. image:: images/new_analyzer.png
  :width: 30%
  :align: center

| このページの入力フィールドにAnalyzerの情報を登録する。入力する項目は以下の通り。

============================= ======================================================================
フィールド                     説明
============================= ======================================================================
Name                          OACISの中で使われるAnalyzerの名前。任意の名前を指定できる。各Simulator内で一意でなくてはならない。
Type                          Runに対する解析(on_run)、ParameterSetに対する解析(on_parameter_set)のどちらかから選ぶ
Definition of Parameters      解析時に指定するパラメータがあれば登録する。空でもよい。
Command                       Analyzerを実行するコマンド。
Pring version command         Analyzerのバージョンを標準出力に出力するコマンド。
Auto Run                      Runの終了後に解析が自動実行されるか指定する。
Description                   Analyzerに対する説明。入力は任意。
============================= ======================================================================

| ここでは、Nameを"plot_timeseries"、Typeをon_run、Definition of Parametersは空のまま、Auto Runはnoを指定する。
| コマンドには以下を入力する。

.. code-block:: sh

  gnuplot ~/path/to/plotfile.plt

| このようにAnalyzerを登録するとRunの実行後に"plot_timeseries"というAnalyzerを選択して実行できるようになる。
| 解析の結果は、runの結果同様にブラウザ上で閲覧することができる。

| Auto Runのフラグは yes, no, first_run_onlyから選択できる。
| 各項目の説明は以下の通り。

    - yes: 各Runが正常終了した場合に自動で解析が実行される。
    - no : 自動で実行されない。
    - first_run_only: 各ParameterSet内で最初に正常終了したRunに対してのみ自動実行される。データの可視化など、一つのRunに対してのみ実行したい解析処理に対して使用できる。

| 今回のサンプルでは示されていないが、パラメータを受け付けるAnalyzerの場合には `_input.json` というファイル内に解析のパラメータが記入される。
| Runに対する解析の場合、 `_input.json` のフォーマットは以下の通りである。
| "analysis_parameters", "simulation_parameters", "result" はそれぞれ解析パラメータ、シミュレーションパラメータ、Runの結果を表す。

.. code-block:: javascript

  {
   "analysis_parameters": {
     "x": 0.1,
     "y": 2
   },
   "simulation_parameters": {
     "L": 32,
     "T": 0.5
   },
   "result": {
     "magnetization": 0.5,
     "energy": 24.5,
     "another_analysis": {
         "maximum_energy": 28.1
     }
   }
  }

ParameterSetに対する解析
----------------------------------------------

| ParameterSetに対する解析もRunに対する解析とほぼ同様である。
| ただし、_input/ディレクトリに保存される形式と `_input.json` の形式が異なる。

| `_input/` ディレクトリ内のファイルの構成は以下の通り

.. code-block:: none

  _input/
    #{run_id1}/
      xxx.txt
      yyy.txt       # run_id1 の結果ファイル
    #{run_id2}/
      xxx.txt
      yyy.txt
   .....

| `_input.json` の形式は以下の通り

.. code-block:: javascript

  {
   "analysis_parameters": {
     "x": 0.1,
     "y": 2
   },
   "simulation_parameters": {
     "L": 32,
     "T": 0.5
   },
   "result": {
     "run_id1": {
       "magnetization": 0.5,
       "energy": 24.5,
       "analysis1": {
           "maximum_energy": 28.1
       }
     },
     "run_id2": {
       "magnetization": 0.32,
       "energy": 25.1,
       "analysis1": {
           "maximum_energy": 27.9
       }
     },
     "run_id3": {
       "magnetization": 0.2,
       "energy": 20.7,
       "analysis1": {
           "maximum_energy": 26.8
       }
     }
   }
  }

| ParaemterSetに対する解析の場合、Auto Runのフラグはyes, noの２択から選択可能である。
| yesの場合、ParameterSet内のすべてのRunが :finished または :failed になったときに自動実行される。

Analyzerのバージョンを記録する
----------------------------------------------

| Analyzer実行時に、どのバージョンのAnalyzerを実行したかをanalysisとひもづけてOACISに記録させておく>ことができる。
| バージョンを記録することにより、例えば、あるバージョンのanalysisを一括削除などの操作ができる様になる。

| Analyzerのバージョンを保存するには、Analyzerのバージョンを出力させるコマンドをOACISに登録する。
| 例えば、

.. code-block:: sh

  echo "v0.1.0"

| というコマンドでバージョン情報を出力する場合、このコマンドをAnalyzer登録時に"Print version command" というフィールドに入力する。
| その他、登録できるコマンドの書式は、 :ref:`シミュレーターのバージョンを記録する<manage_simulator_version>` を参照。


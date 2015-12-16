---
layout: default
title: "高度な使い方"
lang: ja
next_page: cli
---

# {{ page.title }}

* TOC
{:toc}

---

## スケジューラを経由してジョブを実行する

一般的にHPCやクラスタを使用するときにはTorqueなどのジョブスケジューラを経由してジョブを実行します。

ジョブスケジューラに投入する際には確保するノード数などを指定して実行する必要がありますが、ジョブの投入方法やパラメータの指定方法がシステムによって大きく異なります。
そこでOACISではジョブスケジューラの差異を吸収するために、 [xsub](https://github.com/crest-cassia/xsub) というラッパスクリプトを経由してジョブ投入します。
xsubは各実行ホストに事前に設定しておく必要があります。

xsubの導入方法は[xsub](https://github.com/crest-cassia/xsub)のページを参照してください。
インストール後には **xsub**, **xstat**, **xdel** というコマンドが利用可能になっているはずです。

（注）OACISはこれらのコマンドをbashのログインシェルから実行します。
(`bash -l`コマンド経由で実行される。）
PATHなどの環境変数の設定は".bash_profile"で行ってください。

![xsubの概念図]({{ site.baseurl }}/images/xsub.png){:width="500px"}

ジョブ投入時に指定する必要があるパラメータ（ノード数など）をホストパラメータと呼んでいます。
スケジューラのタイプごとに指定するホストパラメータは異なりますが、OACISはHostを登録する際に必要なホストパラメータについての情報をリモートホストから取得します。
ジョブ投入時に入力が求められるようになります。

![ホストパラメータを指定してのRun作成]({{ site.baseurl }}/images/new_run_with_host_params.png){:width="600px"}


## MPI, OpenMPのジョブ

Simulator登録時に、 **Suppot MPI**, **Support OMP** のチェックを入れると、Runの作成時にプロセス数とスレッド数を指定するフィールドが表示されるようになります。

![並列数の指定]({{ site.baseurl }}/images/new_run_mpi_omp_support.png){:width="500px"}

OpenMPのジョブのスレッド数を指定すると、ジョブスクリプトの中で **OMP_NUM_THREADS** の環境変数がセットされます。
つまりOpenMPで並列化しているシミュレータはOMP_NUM_THREADS環境変数を参照してスレッド数を決めるように実装されている必要があります。
（ プログラム内で *omp_set_num_threads()* 関数で別途指定している場合は、当然ながらここで指定したスレッド数は適用されません）

MPIで並列化して実行する場合、Runの作成時に指定したプロセス数は **OACIS_MPI_PROCS** の環境変数にセットされます。
Simulatorの実行コマンドとして、OACIS_MPI_PROCS環境変数を参照してmpiプロセスを起動するコマンドを指定する必要があります。
以下はコマンドの例です。

{% highlight sh %}
mpiexec -n $OACIS_MPI_PROCS ~/path/to/simulator.out
{% endhighlight %}

## プリプロセスの定義

シミュレータによっては実際にシミュレーションジョブを開始する前に、入力ファイルを準備したりフォーマットを調整したりするプリプロセスが必要な場合がしばしばあります。
しかしプリプロセスを計算ジョブの中で行うのが難しい場合があります。
例えば

- スクリプト言語など入力ファイルの準備に使うプログラムが計算ノードにインストールされていないケース
- 外部へのネットワークが遮断され入力用ファイルを準備するために外部からファイルを転送することができないケース
- ファイルのステージングの都合により、ジョブの実行前にファイルをすべて用意する必要があるケース

そこで、OACISにはジョブの実行前にプリプロセスを個別に実行する仕組みを用意しています。
このプリプロセスはジョブの投入前にログインノードで実行されるため上記の問題は起きません。

プリプロセスはジョブの投入前にworkerによってssh経由で実行されます。
workerの実行手順は

1. 各Runごとにワークディレクトリを作成する
1. SimulatorがJSON入力の場合、_input.jsonを配置する
1. Simulatorの **pre_process_script** フィールドに記載されたジョブスクリプトをワークディレクトリに配置し実行権限をつける。(_preprocess.sh というファイル名で配置される)
1. _preprocess.sh をワークディレクトリをカレントディレクトリとして実行する
    - この際Simulatorが引数形式ならば、同様の引数を与えて _preprocess.sh を実行する。この引数から実行パラメータを取得することができる。
    - 標準出力、標準エラー出力は _stdout.txt, _stderr.txt にそれぞれリダイレクトされる。
1. _preprocess.sh のリターンコードがノンゼロの場合には、SSHのセッションを切断しRunをfailedとする
    - failedの時には、ワークディレクトリの内容をサーバーにコピーし、リモートサーバー上のファイルは削除する
1. シミュレーションジョブをサブミットする。

ただし、 Simulatorの pre_process_script のフィールドが空の場合には、上記3~5の手順は実行されません。

## 京コンピュータを利用するケース

京コンピュータでジョブを実行する場合、実行するシミュレーターのファイルもステージングする必要があるため、他のホストとは異なる設定が必要になります。

実行コマンドは絶対パスやホームディレクトリからの相対パスで指定する事はできません。ステージング後のパスが異なるためです。
そこで、プリプロセスを使って実行ファイルをカレントディレクトリにコピーし、実行コマンドはカレントディレクトリからの相対パスで指定するようにします。

実行ファイルが `~/path/to/simulator.out` にある場合、プリプロセスには以下のように書きます。

{% highlight sh %}
cp ~/path/to/simulator.out .
{% endhighlight %}

xsubで実行すると、各ワークディレクトリが丸ごとステージインされるので、必要なファイルはすべてカレントディレクトリに事前にコピーしておきます。

実行コマンドは以下のように指定します。

{% highlight sh %}
./simulator.out
{% endhighlight %}

このように設定しておけば、xsubがカレントディレクトリを丸ごとステージインして実行してくれる。
実行結果は、他のホストの場合と同様にカレントディレクトリ以下に配置しておけば、ステージアウトして結果を取り込んでくれるので、特にステージアウトするファイルを指定する必要はありません。

また京に対してもxsubを導入する必要があります。現時点でxsubはrubyで実装されているので、ログインノードにrubyをインストールする必要があります。
rbenvやrvmなどのツールを使用すると比較的簡単にRubyを導入することができます。

## 手動でジョブを実行する

OACIS上でRunを作るとworkerによってジョブ投入が自動で行われるが、ジョブの実行を手動で行う事もできます。
Run作成時に投入先Hostとして**manual submission**を指定した場合、自動ジョブ投入は行われずジョブスクリプトの生成のみ行われます。
そのジョブスクリプトをユーザーが手動で実行し、結果を後からOACISに取り込む事ができます。

手動で実行することにより、手間は増えるが細かなスクリプトのカスタマイズが可能になります。
例えば、以下のようなユースケースが考えられます。

- 複数のRunを一つのジョブとしてスケジューラに投入する場合
    - スケジューラのジョブ数に制限がある場合などにまとめて投入する事ができる
        - 例：バルクジョブ
- スケジューラの制限時間よりも長いジョブを実行する場合
    - 一度の実行ではジョブが完了せずジョブのリスタートが必要になる場合には、一つのRunに対して複数回ジョブ投入が必要になる
- スケジューラに投入するジョブスクリプトに特殊な設定が必要な場合
    - OACISによって生成されたスクリプトを手動で編集する事によって、実効方法をカスタマイズできる

Runの作成後に *${OACIS_ROOT}/public/Result_development/manual_submission* ディレクトリにシェルスクリプトが生成されます。
パラメータの入力形式がJSON形式の場合には、入力用JSONファイルも作成される。

![manual submission]({{ site.baseurl }}/images/manual_submission.png){:width="400px"}

ユーザーが以下のように生成されたジョブスクリプト実行すると、ジョブが実行されます。

{% highlight sh %}
bash 52cde935b93f969b07000005.sh
{% endhighlight %}

シミュレーション実行結果のファイル（今回の例の場合 52cde935b93f969b07000005.tar.bz2）は以下のコマンドでデータベースに取り込む事ができます。

{% highlight sh %}
./bin/oacis_cli job_include -i 52cde935b93f969b07000005.tar.bz2
{% endhighlight %}

上記コマンドの入力ファイルはスペース区切りまたはコンマ区切りで複数ファイルを指定できます。

## 結果をOACIS上でプロットする

通常シミュレータが出力したファイル群はそのままファイルとしてサーバー上に保存されますが、結果をデータベース内に保存することもできます。
データベース内に保存されたデータはOACISのUI上からプロットをすることができるので、結果のスカラー値（例えば時系列データの平均値や分散）を保存しておくと便利です。

結果をDB内に保存するためには、保存したいデータをJSONフォーマットでシミュレータから出力すればよいです。
**_output.json** という名前でカレントディレクトリ直下にJSONファイルを作成すれば、データベースへの格納時にファイルがパースされDB内に保存されます。
例えば、以下のような結果を保存しておくことができます。

{% highlight json %}
{
  "average": 0.25,
  "variance": 0.02,
  "hash_value": {"a": 0.7, "b": 0.4}
}
{% endhighlight %}

（注）ただしMongoDBの制限により、"."を含むキーは使えません。ジョブがfailedになります。

格納された結果は各Runのページから確認することもできます。

![結果の閲覧]({{ site.baseurl }}/images/run_results.png){:width="400px"}

プロットはParameterSetのページからPlotタブをクリックすると、プロットの表示画面に移動します。

プロットの種類と、横軸、縦軸や系列などを指定してください。
必要なParameterSetを集めて平均や標準誤差を計算してプロットします。

右下のマップをドラッグすることで一部分を拡大したり、ログスケールに表示を切り替えることもできます。
データ点をクリックすると対象となるParameterSetのページを表示することもできます。
画面右に表示されているURLを開くと、今表示しているプロットを再度開くことができます。

![プロット]({{ site.baseurl }}/images/lineplot.png){:width="400px"}

## シミュレーターのバージョンを記録する

シミュレーションの実行時にどのバージョンのシミュレーターで実行したかOACISに記録をさせておくことができます。

例えば、シミュレーションを実行していくうちにシミュレーションコードにバグが見つかり、一部のシミュレーションを再実行したい場合などがあります。
RunとSimulatorのバージョンをひもづけて記録する事により、あるバージョンの実行結果を一括削除したり再実行したりすることができるようになります。

バージョンを保存するには、Simulatorのバージョンを出力させるコマンドをOACISに登録します。
例えば

{% highlight sh %}
~/path/to/simulator.out --version
{% endhighlight %}

というコマンドでバージョン情報を出力されるシミュレーターがあるとします。
このコマンドをSimulator登録時に "Print version command" というフィールドに登録しておくと、ジョブ実行時にこのコマンドを実行し、その標準出力をバージョン情報として記録することができます。

Print version command の標準出力に出力された文字列がバージョンとして認識されるので、実行バイナリに引数を渡すだけでなく柔軟な指定が可能です。
例えば、ビルドログの一部をバージョン情報として記録したり、バージョン管理システムのコミットIDを出力するような利用方法も考えられます。

{% highlight sh %}
head -n 1 ~/path/to/build_log.txt
{% endhighlight %}
{% highlight sh %}
cd ~/path/to; git describe --always
{% endhighlight %}

Runの一括削除や一括置換はCommand Line Interface(CLI)から実行できます。
詳細はCLIのページを参照してください。

## Analyzerの登録と実行

ジョブの実行後、実行結果に対してポストプロセス（Analyzer）を定義することができます。
OACISで定義できるAnalyzerには２種類存します
一つは各Runに対して実行されるもの、もう一つはParameterSet内のすべてのRunに対して行われるものです。
前者の例としては、シミュレーションのスナップショットデータから可視化を行う、時系列のシミュレーション結果に対してフーリエ変換する、などがあげられます。
後者の例は、複数のRunの統計平均と誤差を計算することなどがあげられます。

OACISの用語として、Analyzerによって得られた結果はAnalysisと呼ばれており、AnalyzerとAnalysisの関係は、SimulatorとRunの関係のようなものです。

Analyzerの実行フローはSimulatorととても似ています。
Analyzerを実行するためのスクリプトが生成され、workerプロセスからSSH経由でリモートホストにジョブ投入されます。
実行可能なホストの一覧はAnalyzer登録時に指定します。
実行時に一時ディレクトリが作成され、その中にできたファイルは結果のファイルとして全て取り込まれ、ブラウザ経由で確認できるようになります。
Simulatorの場合と同じように、実行日時や実行時間などの情報が保存されますし、プリプロセスやバージョンの記録も同様に可能です。
出力ファイルに**_output.json**というファイル名のJSONファイルがあれば、それをデータベースに取り込みプロットすることも可能です。

また、Analyzerは実行時に解析用のパラメータを指定して実行することもできます。
例えば、時系列データを解析するときに最初の何ステップを除外するか指定したい場合などに使えます。
Analyzerの登録時にパラメータの定義を登録することができます。

Simulatorと異なるのは、Analyzerには解析対象となるRunのデータに実行時にアクセスできます。
ジョブの実行時に作られる一時ディレクトリに、Runの結果のファイルが配置されます。
解析対象がRunかParameterSetかによって配置の仕方が異なるため以下で個別に説明します

### Runに対する解析

ここではRunに対する解析の例を示します。

時系列データを出すシミュレーションのanalyzerとして、時系列をグラフにプロットすることを考えます。
シミュレータが以下の形式のファイルをsample.datというファイル名で出力することとします。１列目が時刻、２列目がプロットするデータです。

{% highlight text %}
1 0.25
2 0.3
3 0.4
{% endhighlight %}

Analyzerの実行時には、Runの結果は実行ディレクトリ以下の *_input/* というディレクトリに配置されます。
Analyzerはそのディレクトリにあるファイルを解析できるように実装する必要があります。

Runの結果のファイルすべてがAnalyzerには必要ではない場合、`Files to Copy`というフィールドに必要なファイル名を指定するとそのファイルだけが_inputディレクトリにコピーされます。
不要なファイル転送が減るのでAnalyzerの実行が速くなる場合があります。
ファイル名の指定にはワイルドカード('\*')が利用でき、デフォルトの値は'\*'になっています。
複数のファイルを指定する場合は、複数行に分けて入力してください。

上記の例にあるような入力の時系列をgnuplotでプロットしましょう。
次に示すようなgnuplot入力ファイルを作成し、どこかのパス（例として ~/path/to/plotfile.pltというパスにする）に保存します。

{% highlight gnuplot %}
set term postscript eps
set output "sample.eps"
plot "_input/time_series.dat" w l
{% endhighlight %}

これでAnalyzerの準備ができたので、OACISに登録します。
Simulatorの画面を開き、[About]タブをクリックするとAnalyzerを新規登録するためのリンク[New Analyzer]が表示されます。
そのリンクをクリックすると下図のような登録画面が現れます。

![Analyzerの登録]({{ site.baseurl }}/images/new_analyzer.png){:width="400px"}

このページの入力フィールドにAnalyzerの情報を登録します。入力する項目は以下の通り。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name                       | OACISの中で使われるAnalyzerの名前。任意の名前を指定できる。各Simulator内で一意でなくてはならない。  |
| Type                       | Runに対する解析(on_run)、ParameterSetに対する解析(on_parameter_set)のどちらかから選ぶ               |
| Definition of Parameters   | 解析時に指定するパラメータがあれば登録する。空でも可。 |
| Pre process script         | プリプロセスとして実行するスクリプトを入力します。空白可。|
| Command                    | Analyzerを実行するコマンド。 |
| Print version command      | Analyzerのバージョンを標準出力に出力するコマンド。 |
| Input type                 | JSON入力か引数入力か指定する。 |
| Files to Copy              | 解析時に_inputディレクトリにコピーするファイルを指定する。 |
| Support MPI                | MPI並列の場合はチェックを入れる。Analysis作成時に並列数を指定できるようになる。 |
| Support MPI                | OpenMP並列の場合はチェックを入れる。Analysis作成時に並列数を指定できるようになる。 |
| Auto Run                   | Runの終了後に解析が自動実行されるか指定する。(後述) |
| Description                | Analyzerに対する説明。入力は任意。 |
| Executable on              | 実行可能なホスト。Analyzerを実行できるホストにチェックを入れる |
| Host for Auto Run          | 自動実行で作成されるAnalysisが実行されるHost (後述) |
|----------------------------|---------------------------------------------------------------------|

ここでは、Nameを"plot_timeseries"、Typeをon_run、他はデフォルトのまま、コマンドには以下を入力します。

{% highlight sh %}
gnuplot ~/path/to/plotfile.plt
{% endhighlight %}

このようにAnalyzerを登録するとRunの実行後に"plot_timeseries"というAnalyzerを選択してAnalysisを作成できるようになります。
Analysisが作成されるとRunと同様にバックグラウンドで処理され、完了後の解析結果はブラウザ上で閲覧できるようになります。

今回のサンプルでは示されていないが、パラメータを受け付けるAnalyzerの場合には `_input.json` というファイル内に解析のパラメータが記入されます。
Runに対する解析の場合、 `_input.json` のフォーマットは以下の通りです。
"analysis_parameters", "simulation_parameters" はそれぞれ解析パラメータ、シミュレーションパラメータを表します。

{% highlight sh %}
{
 "analysis_parameters": {
   "x": 0.1,
   "y": 2
 },
 "simulation_parameters": {
   "L": 32,
   "T": 0.5,
   "_seed": 1787809130
 }
}
{% endhighlight %}

### ParameterSetに対する解析

ParameterSetに対する解析もRunに対する解析とほぼ同様です。
ただし、_input/ディレクトリに保存される形式と `_input.json` の形式が異なります。

**_input/**ディレクトリ内のファイルの構成は以下の通り

{% highlight text %}
_input/
  #{run_id1}/     # run_id1 の結果のファイル
    xxx.txt
    yyy.txt
  #{run_id2}/     # run_id2 の結果のファイル
    xxx.txt
    yyy.txt
 .....            # 以後、ParameterSet内で"finished"になっている全てのRunの結果が同様に配置される
{% endhighlight %}

*_input.json*ファイルの形式は以下の通り

{% highlight json %}
{
  "analysis_parameters": {
    "x": 0.1,
    "y": 2
  },
  "simulation_parameters": {
    "L": 32,
    "T": 0.5
  },
  "run_ids": [   // runのIDの一覧
    "run_id1",
    "run_id2",
    "run_id3"
  ]
}
{% endhighlight %}

Runに対するAnalyzerの場合と同じように、`Files to Copy`というフィールドに必要なファイル名を指定するとそのファイルだけが_inputディレクトリにコピーされます。
例えば、"xxx.txt"というファイル名を指定した場合のディレクトリ構成は以下のようになります。

{% highlight text %}
_input/
  #{run_id1}/     # run_id1 の結果のファイル。xxx.txt以外のファイルは含まれない。
    xxx.txt
  #{run_id2}/
    xxx.txt
 .....            # 以後、ParameterSet内で"finished"になっている全てのRunの結果が同様に配置される
{% endhighlight %}

AnalyzerからRunの結果ファイルを取得する例(言語：ruby)

{% highlight ruby %}
require 'json'
require 'pathname'
persed = JSON.load(open('_input.json'))
RESULT_FILE_NAME = 'time_series.dat'
result_files = persed["run_ids"].map do |id|
  Pathname.new("_input").join(id).join(RESULT_FILE_NAME)
end
# => ["_input/526638c781e31e98cf000001/time_series.dat", "_input/526638c781e31e98cf000002/time_series.dat"]
{% endhighlight %}

### Analyzerの自動実行

AnalyzerはRunの完了後に自動で実行することもできます。
各RunおよびParameterSetに対して毎回手動でAnalysisを作成する必要がなくなるので便利です。
自動実行するにはAnalyzerのAuto Runのフラグを設定します。

Runに対するAnalyzerの場合、Auto Runのフラグは **yes**, **no**, **first_run_only**から選択できます。

- yes: 各Runが正常終了した場合に自動で解析が実行される。
- no : 自動で実行されない。
- first_run_only: 各ParameterSet内で最初に正常終了したRunに対してのみ自動実行される。
    - データの可視化など、一つのRunに対してのみ実行したい解析処理に対して使用できる。

ParaemterSetに対する解析の場合、Auto Runのフラグは**yes**, **no**の２択から選択可能です。
yesの場合、ParameterSet内のすべてのRunが :finished または :failed になったときに自動実行ます。


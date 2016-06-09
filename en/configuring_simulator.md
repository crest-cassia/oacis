---
layout: default
title: "Configuring Simulator"
lang: en
next_page: configuring_analyzer
---

# {{ page.title }}

In this page, we are going to demonstrate how to setup a simulator on OACIS.

In order to execute an existing simulator from OACIS, the simulator must be prepared to conform to the requirements by OACIS.
For example, OACIS gives input parameters to simulators by command-line arguments or JSON. Your must prepare a small script in order to adjust the interface of input parameters.
In this page, how to prepare a simulator as well as a few samples are demonstrated.

* TOC
{:toc}

---

## Job Execution Sequence

First, the job execution sequence are explained in detail.

When you register a simulator on OACIS, you save the command line string, not the execution program itself. By this specification, OACIS can run various programs written in any programming language. It also means that the simulation program must be compiled on computational hosts before submitting a job.
OACIS generates a shell script including the command line to execute the program. We call this script "job script". For each run, one job script is created. Job scripts created by OACIS are submitted to the job schedulers (such as Torque) on computational hosts via SSH.
Just before submitting job scripts, a temporary directory is created for each job. We call it "work directory". Jobs are executed in their work directories. Work directories are created under the "work base dir" directory which was specified when registering a computational host.

Here is the summary of the job sequence.

```text

OACIS-server                                  |     computational host              |   computation node
----------------------------------------------|-------------------------------------|---------------------------------------
                                           ---|-->  SSH login                       |
                                              |     create a work directory         |
                                              |     prepare _input.json             |
                                              |     create a job script             |
                                              |     execute preprocess              |
                                              |     submit job script               |
                                              |                                     |   (when job script start)
                                              |                                     |   execute print-version command
                                              |                                     |   save execution logs to a file
                                              |                                     |   execution of the simulation program
                                              |                                     |   compress the work directory
                                              |                                     |
                                              |     (after the job finished)        |
                                           ---|-->  SSH login                       |
                                              |     download the compressed results |
extract the results                           |                                     |
move the output files to specified directory  |                                     |
parse logs and save them in MongoDB           |                                     |
```

First, OACIS login to the computational host and create a work directory for the job.
Then, put `_input.json` file if the simulator's input format is JSON. This file contains the input parameters for the job.

You can define a process which is executed before submitting a job. We call it "pre-process".
This is useful when you prepare the necessary files before conducting simulations. For example, you can use pre-process to copy some configuration files to the current directory.
Pre-processes are executed after `_input.json` was created. The details of pre-process are also shown later.

Then, the job is submitted to a job scheduler. After the job is submitted to the scheduler, the scheduler handles the job queue.

When a job script is executed, it records various logs to files in addition to the simulation execution. For example, execution date, executed host, and elapsed time are recorded. To record these information, shell commands like `date`, `hostname`, and `time` are used.
These logs are stored in `_status.json` file. This file is parsed when jobs are included into OACIS database.

As we will explain later, OACIS can record the version information of the simulators. When you register a simulator, you can set "print-version command", which is a command to print the version information of the simulator.
If the print version command is defined, the command is embedded in the shell script. The command is executed just before executing the simulation to record the current version of the simulator. This information is saved in the file `_version.txt` and parsed by OACIS when the job is included.

After the simulation finished, the work directory is compressed into a single file. By compressing the result, we can reduce the time to download the file.

## Requirements for simulators

To execute simulator from OACIS, simulators must satisfy the following requirements.

1. The output files or directories must be created in the current directory.
    - OACIS creates a work directory for each job and executes the job in that directory. All the files and directories in the work directory are stored in OACIS as the simulation outputs.
2. Simulator must receive input parameters as either command line arguments or JSON file. You can choose one of these when registering the simulator on OACIS.
    - If you choose the former one as a way to set input parameters, the parameters are given as the command line arguments in the defined sequence with a trailing random number seed.
        - For example, if an input parameter is "*param1=100, param2=3.0, random number seed=12345*", the following command is embedded in the shell script.
            -  `~/path/to/simulator.out 100 3.0 12345`
    - If you choose JSON format as a way to set input parameters, a JSON file named **_input.json** is prepared in the temporary directory before execution of the jobs. Simulator must be implemented such that it reads the json file in the current directory.
        - `{"param1":100,"param2":3.0,"_seed":12345}`
            - Random number seed is specified by the key *"_seed"*.
        - The command is executed without command line argument as follows.
            - `~/path/to/simulator.out`
3. The simulator must work even with the files listed below in the current directory. These files must not be overwritten.
    - *_input.json* , *_output.json* , *_status.json* , *_time.txt*, *_version.txt*
    - These files are used by OACIS in order to record the information of the job. Avoid conflicts with these files.
4. The simulator must return 0 when finished successfully. The return code must be non-zero when an error occurs during the simulation.
    - OACIS judges if the job finished successfully or not based on the return code.

## Sample scripts for configuring simulators

As we mentioned in the previous section, the program must receive input parameters either from command-line arguments or from JSON.
Probably most of your simulation programs do not conform to the format of input parameters. In order to implement your simulators, you need to prepare a scritp that wraps your simulation program in order to adjust the I/O format. Let us call the script "wrap script" from now on.
It is easier to prepare a wrap script using a light-weight scripting language such as a shell script, Python, or Ruby.
After you prepared a wrap script, register the path to the wrap script as the simulation command in OACIS. OACIS executes the wrap script, which in turn executes the actual simulation program.

We are going to show a few samples for wrap scripts.

### Example 1: changing the command line argument

Suppose you have a simulation program which has four input parameters. You can set these input parametes by command line options.
Let us assume that the options to set parameters are "-l", "-v", "-t", "--tmax". In addition to these, we can set the seed of random number generator by "--seed" option.
A command for this simulator would look like

```bash
~/my_proj/my_simulator.out -l 8 -v 0.25 -t 1234 --tmax 2000 --seed 1234
```

You can not run this program directly since the format of the command line is different from the one given by OACIS.
To adjust the input format, we prepare a shell script `wrapper.sh` as follows:

```bash
#!/bin/bash

set -e
script_dir=$(cd $(dirname $BASH_SOURCE); pwd)
$script_dir/my_simulator.out -l $1 -v $2 -t $3 --tmax $4 --seed $5
```

Put this shell script in the directory where the simulation program exists. By running this wrap script from OACIS, you can execute the simulation program with the input parameters given by OACIS.

The tips for this script are

- Put `set -e` within the script, which makes the return code of `wrapper.sh` to a non zero value when the simulation program returns non-zero code.
    - OACIS checks the return code of `wrapper.sh` to judge if the job finished successfully or not. Without `set -e`, you always get a return code 0 even if the actual simulation program fails, which results in a misjudgement of the job status.
- When you execute the actual simulation program (`my\_simulator.out`), you need to specify the absolute path of the executable.
    - Since OACIS executes a job from its work directory, the path of the executable must be written in the absolute path.

### 例2. パラメータを別の形式の外部ファイルで実行する場合

別の例として、既存のシミュレーションプログラムがパラメータをXML形式で受け取る場合を考えましょう。

３つのパラメータ("length","velocity","time")と乱数の種をXMLで指定して、そのXMLファイルを実行コマンドの引数として指定するプログラムがあったとします。例えば、

```xml
<configuration>
    <input>
        <length value="8" />
        <velocity value="25.0"/>
        <time value="2000"/>
        <seed value="1234"/>
    </input>
</configuration>
```

というXMLを用意して、

```sh
~/my_proj/my_simulator.xml -c configuration.xml
```

という形で引数としてそのXMLファイルを指定して実行するとします。

このプログラムをOACISのシミュレーターとして実行するために、例えば以下のようなpythonスクリプト`wrapper.py`を準備します。
pythonから扱いやすいように、OACISにシミュレーターを登録する際には**Input type**としてJSONを選択したとしましょう。
また`wrapper.py`は実行プログラムと同じディレクトリ(`~/my_proj/`)に配置してあるものとします。

```python
import os, sys, json, subprocess

# Load JSON file
fp = open( '_input.json' )
params = json.load( fp )

# Prepare input file
f = open('configuration.xml', 'w')
param_txt = """<configuration>
    <input>
        <length value="%d" />
        <velocity value="%f"/>
        <time value="%d"/>
        <seed value="%d"/>
    </input>
</configuration>
""" % (params['length'], params['velocity'], params['time'], params['_seed'])
f.write(param_txt)
f.flush()

# Execution of the simulator
simulator = os.path.abspath(os.path.dirname(__file__)) + "/my_simulator.out"
cmd = [simulator, '-c', 'configuration.xml']
sys.stderr.write("Running: %s\n" % cmd)
subprocess.check_call(cmd)
sys.stderr.write("Successfully finished\n")
```

#### スクリプトの処理の流れ

1. パラメータの書かれたJSONファイル (_input.json) をロードする。
    - このファイルはOACISによって実行時に用意される。
2. ファイル `configuration.xml` を出力する。
    - この際、ファイル出力した後に必ず`flush()`を呼んで、シミュレーター実行時に確実に内容が書き込まれているようにする。
3. `my_simulator.out`を実行する。
    - スクリプト(`wrapper.py`)と同じディレクトリ上に`my_simulator.out`があるので、その絶対パスを使います。
        - 例1でもあったように `my_simulator.out`のパスは絶対パスで指定します。
    - シミュレーションが失敗したかどうかをリターンコードで確認して、もし０でない場合は例外を投げる。
        - OACISは `wrapper.py`自体のリターンコードが０かどうかで、Runが失敗したかどうかの判定を行っている。外部プロセスでエラーが起きた場合には、スクリプト自体も異常終了させるとよい。
        - pythonでは`subprocess.check_call`メソッドで実行すると、外部プロセスのリターンコードが０でない時に例外を送出する。

## Simulatorの設定項目 {#simulator_specification}

OACISにSimulator登録する際に登録する項目の一覧を見ていきましょう。設定項目は以下の通りです。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name *                     | シミュレータの名前。Ascii文字、数字、アンダースコアのみ使用可。空白不可。他のSimulatorとの重複は不可。 |
| Definition of Parameters * | シミュレータの入力パラメータの定義。パラメータの名前、型(Integer, Float, String, Boolean)、デフォルト値、パラメータの説明（任意）を入力する。 |
| Preprocess Script          | ジョブの前に実行されるプリプロセスを記述するスクリプト。空の場合はプリプロセスは実行されない。|
| Command *                  | シミュレータの実行コマンド。リモートホスト上でのパスを絶対パスかホームディレクトリからの相対パスで指定する。(例. *~/path/to/simulator.out*) |
| Pirnt version command      | シミュレータのversionを標準出力に出力するコマンド。（例. *~/path/to/simulator.out --version* ）|
| Input type                 | パラメータを引数形式で渡すか、JSON形式で渡すか指定する。|
| Support mpi                | シミュレータがMPIで実行されるか。チェックを入れた場合、Runの作成時にMPI並列数を指定することができる。 |
| Support omp                | シミュレータがOpenMPで並列化されているか。チェックを入れた場合、Runの作成時にOMP並列数を指定することができる。 |
| Sequential seed            | Runの作成時に指定されるseedをランダムな順番に与えるか、各ParameterSetごとに1から順番に与えるか指定することができる。 |
| Description                | シミュレータの説明を入力する。[markdownフォーマット](http://daringfireball.net/projects/markdown/syntax) で入力できる。|
| Executable\_on *            | 実行可能Hostを指定する。ここで指定したホストがジョブ投入時に投入先ホストとして指定できる。  |
|----------------------------|---------------------------------------------------------------------|

入力必須な項目は(*)で示されています。

**Definition of Parameters** の入力の際には、指定した型とデフォルト値の値が整合するように入力してください。
例えば、型がIntegerなのにデフォルト値として文字列を指定するとエラーになります。

**Preprocess Script** を指定すると、ジョブ投入前に実行されるプリプロセスを指定することができます。
シミュレーターの入力を準備したり、ジョブ投入ノードでしか実行できない処理を指定するとよいでしょう。
詳細は[プリプロセスの定義](#preprocess)を参照してください。

**Command** で指定された文字列がシェルスクリプトに埋め込まれて実行されます。
OACISがジョブを実行する際には、各ジョブごとに一時的なディレクトリを作成し、その中でコマンドを実行します。
そのため、コマンドは**フルパス**で指定する必要があります。
様々なホストで同じように実行できるようにホームディレクトリからの相対パスで指定するとよいです。（例. *~/path/to/simulator.out* ）

**Pirnt version command** を指定すると、各Runの実行時にSimulatorのバージョンも記録されます。
ここで指定したコマンドがジョブ実行用シェルスクリプトの中に埋め込まれ実行されます。その標準出力として得られた文字列がバージョンとして記録されます。
バージョンを記録すると、指定のバージョンのシミュレーターで実行されたRunを一括で削除したり、実行し直したりできます。
詳細は[シミュレーターのバージョンを記録する](#record_simulator_version)を参照してください。

**Input type** はパラメータの渡し方を指定します。
引数渡しかJSONか２種類から選択できます。



## MPI, OpenMPのジョブ

Simulator登録時に、 **Suppot MPI**, **Support OMP** のチェックを入れると、Runの作成時にプロセス数とスレッド数を指定するフィールドが表示されるようになります。

![並列数の指定]({{ site.baseurl }}/images/new_run_mpi_omp_support.png){:width="500px"}

OpenMPのジョブのスレッド数を指定すると、ジョブスクリプトの中で **OMP_NUM_THREADS** の環境変数がセットされます。
つまりOpenMPで並列化しているシミュレータはOMP_NUM_THREADS環境変数を参照してスレッド数を決めるように実装されている必要があります。
（ プログラム内で *omp_set_num_threads()* 関数で別途指定している場合は、当然ながらここで指定したスレッド数は適用されません）

MPIで並列化して実行する場合、Runの作成時に指定したプロセス数は **OACIS_MPI_PROCS** の環境変数にセットされます。
Simulatorの実行コマンドとして、OACIS_MPI_PROCS環境変数を参照してmpiプロセスを起動するコマンドを指定する必要があります。
以下はコマンドの例です。

```shell
mpiexec -n $OACIS_MPI_PROCS ~/path/to/simulator.out
```

## プリプロセスの定義 {#preprocess}

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


## 結果をOACIS上でプロットする

通常シミュレータが出力したファイル群はそのままファイルとしてサーバー上に保存されますが、結果をデータベース内に保存することもできます。
データベース内に保存されたデータはOACISのUI上からプロットをすることができるので、結果のスカラー値（例えば時系列データの平均値や分散）を保存しておくと便利です。

結果をDB内に保存するためには、保存したいデータをJSONフォーマットでシミュレータから出力すればよいです。
**_output.json** という名前でカレントディレクトリ直下にJSONファイルを作成すれば、データベースへの格納時にファイルがパースされDB内に保存されます。
（既存のプログラムがJSONを出力するようになっていない場合は、ラップスクリプトの中でJSON形式の出力に変換するのがよいでしょう。）

例えば、以下のような結果を保存しておくことができます。

```json
{
  "average": 0.25,
  "variance": 0.02,
  "hash_value": {"a": 0.7, "b": 0.4}
}
```

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


## シミュレーターのバージョンを記録する {#record_simulator_version}

シミュレーションの実行時にどのバージョンのシミュレーターで実行したかOACISに記録をさせておくことができます。

例えば、シミュレーションを実行していくうちにシミュレーションコードにバグが見つかり、一部のシミュレーションを再実行したい場合などがあります。
RunとSimulatorのバージョンをひもづけて記録する事により、あるバージョンの実行結果を一括削除したり再実行したりすることができるようになります。
シミュレーターのソースコードを変更する可能性がある時は、バージョンを記録しておくと効率的にやり直しができるようになります。

バージョンを保存するには、Simulatorのバージョンを出力させるコマンドをOACISに登録します。
例えば

```shell
~/path/to/simulator.out --version
```

というコマンドでバージョン情報を出力されるシミュレーターがあるとします。
このコマンドをSimulator登録時に "Print version command" というフィールドに登録しておくと、ジョブ実行時にこのコマンドを実行し、その標準出力をバージョン情報として記録することができます。

Print version command の標準出力に出力された文字列がバージョンとして認識されるので、実行バイナリに引数を渡すだけでなく柔軟な指定が可能です。
例えば、ビルドログの一部をバージョン情報として記録したり、バージョン管理システムのコミットIDを出力するような利用方法も考えられます。

```shell
head -n 1 ~/path/to/build_log.txt
```
```shell
cd ~/path/to; git describe --always
```

Runの一括削除や一括置換はCommand Line Interface(CLI)から実行できます。
詳細は[CLI]({{ site.baseurl }}/ja/cli.html)のページを参照してください。


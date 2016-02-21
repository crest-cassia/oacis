---
layout: default
title: "基本の使い方"
lang: ja
next_page: advanced_usage
---

# {{ page.title }}

簡単なシミュレータを実際に実行し、結果を参照するまでの最小の手順をここで示します。

---

## 手順

1. シミュレーターの準備
1. Host登録
1. Simulator登録
1. ParameterSet登録
1. ジョブ投入
1. 実行中のジョブの確認
1. 結果の確認

## 1. Simulatorの準備

このチュートリアルでは、２つの浮動小数点型のパラメータ"p1", "p2"を持つとします。

シミュレータは以下の様にパラメータと乱数の種を引数で受け取り実行できるように、各実行ホストで事前にビルドをしておいてください。

{% highlight sh %}
~/path/to/simulator.out {p1} {p2} {seed}
{% endhighlight %}

本チュートリアルでは、説明のために実際のシミュレーションコマンドの代わりにechoコマンドをシミュレーターとして登録します。

パラメータをシミュレータに渡す方法として、JSONで渡す方法もあります。Simulator登録の項目を参照の事。

## 2. Host登録

シミュレータを実行するためのホストを登録します。

前提条件として、サーバーからシミュレータを実行するホストに鍵認証を使用してパスワード無しでSSHログインできるようにしておかなくてはいけません。
ここでは鍵認証でリモートホストにSSHログインできるようになっているという前提で話を進めます。

また、ホストでジョブスケジューラ（xsub) が実行可能でなければなりません。
xsub の設定方法については、https://github.com/crest-cassia/xsub を参照してください。

Dockerの仮想環境で導入した場合、localhostに対して以上の設定はすでに完了しています。
最初に試す場合は、localhostを登録するのがわかりやすいでしょう。

ナビゲーションバーの[Hosts]をクリックし、[New Hosts]のボタンを押すと新規Host登録画面が表示される。

![ホスト登録]({{ site.baseurl }}/images/hosts.png){:width="600px"}

このページの入力フィールドにホストの情報を登録します。登録する項目は以下の通り。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name                       | OACISの中で使われるHostの名前。任意の名前を指定できる。一意でなくてはならない。 |
| Hostname                   | ssh接続先のhostnameまたはIPアドレス。 |
| Polling Status             | サーバーを使用するかどうかのフラグ。サーバーのメンテナンス時など、一時的にジョブの投入を止めたい場合に disabled を指定する。 |
| User                       | ssh接続時に使用するユーザー名。 |
| Port                       | ssh接続先のポート番号。デフォルトは22。 |
| SSH key                    | ssh接続時の鍵認証で使用する秘密鍵ファイルへのパス。デフォルトは *~/.ssh/id_rsa* |
| Work base dir              | ワークディレクトリとして利用するホスト上のパス。ここで指定したパス以下でジョブが実行される。 |
| Mounted work base dir      | localhostでジョブを実行する場合やホームディレクトリがNFSで共有されている場合など、OACISが実行中のサーバーからWork base dirを直接参照できる場合のパス。マウントされていない場合は空白にしておく |
| Max num jobs               | このホストに投入可能なジョブの最大数。 |
| Polling interval           | ジョブのステータスを確認するインターバル。ここで指定した時間間隔でSSH接続しジョブの状態を確認する。 |
| MPI processes              | MPIプロセス数の最小値と最大値。Runを作成するときにここで指定した範囲外の値を指定しようとするとエラーになる。 |
| OMP threads                | OMPスレッド数の最小値と最大値。Runを作成するときにここで指定した範囲外の値を指定しようとするとエラーになる。 |
| Executable simulators      | 実行可能なSimulatorをチェックボックスで指定。 |
| Executable analyzers       | 実行可能なAnalyzerをチェックボックスで指定。 |
|----------------------------|---------------------------------------------------------------------|

- (注) Mounted work base dirを指定するとホストとのファイル転送にSFTP接続ではなく、マウントされたパスからコピーを行います。パフォーマンスが向上する場合があります。

本チュートリアルでは以下のように設定します。その他はデフォルトのままにしてください。
Work base dir は任意のディレクトリで良いが、新規作成した（他のファイルが無い）ディレクトリを指定する事。

- Name: localhost
- Hostname: localhost
- User: oacis （仮想環境でない場合は自分のユーザー名）
- Work base dir: ~/work （仮想環境でない場合は任意の新規作成したディレクトリへのパス）
- Polling interval: 5 （挙動を早く確認したいので短めに設定しています）

ホストの登録後、一覧画面で登録したホストを確認する事ができます。ジョブが流れていない状態であれば登録した設定の再編集も可能です。

## 3. Simulator登録

扱うシミュレータは、言語やマシンを問わず自由に作成できます。
OACISは登録されたコマンドを実行するだけなので、どの言語で実装されているかは関係ありません。
ただし、以下の要件を満たす必要があります。

- 出力ファイルが実行時のディレクトリ以下に作成される事
    - OACISは実行時にそのジョブ用の一時的なディレクトリを作り、その中でジョブを実行する。完了後、そのディレクトリ内のファイルすべてを出力結果として取り込む。
- パラメータの入力を引数またはJSONで受け付ける事
    - 引数渡しの場合はパラメータが定義された順番に引数で渡されて、最後の引数として乱数の種が渡される。
        - 例えば、param1=100, param2=3.0, seed(乱数の種)=12345 の場合、以下のコマンドが実行される
            -  `~/path/to/simulator.out 100 3.0 12345`
    - JSON形式の場合、実行時に次のような形式のJSONファイルを *_input.json* というファイル名でOACISが実行時に配置する。シミュレータはカレントディレクトリの *_input.json* パースするように実装する必要がある。
        - `{"param1":100,"param2":3.0,"_seed":12345}`
        - 乱数の種は _seed というキーで指定される。
        - 実行コマンドは以下のように引数なしで実行される。
            - `~/path/to/simulator.out`
- 以下の名前のファイルがカレントディレクトリにあっても問題なく動作し、これらのファイルを上書きしたりしないこと
    - *_input.json* , *_output.json* , *_status.json* , *_time.txt*, *_version.txt*
    - これらのファイルはOACISが使用するファイル名であるため干渉しないようにする必要がある
- 正常終了時にリターンコード０、エラー発生時に０以外を返す事
    - リターンコードによってシミュレーションの正常終了/異常終了が判定される。

シミュレータはあらかじめ実行ホスト上でビルドしておき実行可能な状態で配置しておく必要があります。
また複数のホストで実行する場合、シミュレータを同一のパスに配置する必要があります。
そのためには絶対パスで指定するよりもホームディレクトリからの相対パスで指定するとよいです。

Simulator一覧ページ(/simulators)で[New Simulator]ボタンをクリックすると新規Simulator登録画面が表示されます。

![ホスト登録]({{ site.baseurl }}/images/new_simulator.png){:width="400px"}

このページの入力フィールドにシミュレータの情報を登録します。登録する項目は以下の通り。

|----------------------------|---------------------------------------------------------------------|
| フィールド                 | 説明                                                                |
|:---------------------------|:--------------------------------------------------------------------|
| Name                       | シミュレータの名前。Ascii文字、数字、アンダースコアのみ使用可。空白不可。他のSimulatorとの重複は不可。 |
| Definition of Parameters   | シミュレータの入力パラメータの定義。パラメータの名前、型(Integer, Float, String, Boolean)、デフォルト値、パラメータの説明（任意）を入力する。 |
| Preprocess Script          | ジョブの前に実行されるプリプロセスを記述するスクリプト。空の場合はプリプロセスは実行されない。|
| Command                    | シミュレータの実行コマンド。リモートホスト上でのパスを絶対パスかホームディレクトリからの相対パスで指定する。（例. *~/path/to/simulator.out* ）|
| Pirnt version command      | シミュレータのversionを標準出力に出力するコマンド。（例. *~/path/to/simulator.out --version* ）指定するとジョブの実行時にSimulatorのバージョンも記録される。|
| Input type                 | パラメータを引数形式で渡すか、JSON形式で渡すか指定する。|
| Support mpi                | シミュレータがMPIで実行されるか。チェックを入れた場合、Runの作成時にMPI並列数を指定することができる。 |
| Support omp                | シミュレータがOpenMPで並列化されているか。チェックを入れた場合、Runの作成時にOMP並列数を指定することができる。 |
| Sequential seed            | Runの作成時に指定されるseedをランダムな順番に与えるか、各ParameterSetごとに1から順番に与えるか指定することができる。 |
| Description                | シミュレータの説明を入力する。[markdownフォーマット](http://daringfireball.net/projects/markdown/syntax) で入力できる。|
| Executable_on              | 実行可能Hostを指定する。                                            |
|----------------------------|---------------------------------------------------------------------|

本チュートリアルでは以下のように設定します。その他はデフォルト。

- Name: sample_simulator
- Definition of Parameters: [[param1, Integer, 0], [param2, Float, 5.0]]
- Command: echo
- Input type: Argument
- Executable_on: localhostにチェック

(注) "Add Parameter" と書かれたリンクをクリックすると、パラメータ定義を入力するためのフィールドが出現する。任意の個数のパラメータ定義を登録することができる。

シミュレータの登録後、一覧画面で登録したシミュレータを確認する事ができます。

## 4. ParameterSet登録

Simulator一覧ページで登録したシミュレータ名のリンクをクリックすると、ParameterSet一覧画面が出ます。
現時点では、ParameterSetが何も作られていないので空のテーブルが表示されるだけだが、ParameterSetを作成して行くと下図のように一覧で表示されます。

![PS一覧]({{ site.baseurl }}/images/parameter_sets.png){:width="500px"}

ParameterSetを新規作成するために[New Parameter Set]のボタンをクリックします。

![PS登録]({{ site.baseurl }}/images/new_parameter_set.png){:width="500px"}

上の様に登録フォームが現れるので、シミュレーションを実行したいパラメータを入力して[Create]をクリックします。
（この画面からRunも作成する事ができるが、今回は「# of Runs」のフィールドは０のままにしておきます。

ちなみにこのときにコンマで区切って複数の値を入力すると、複数のParameterSetを同時に作成する事ができます。
ただし同時に作ることができるParameterSetの数は100以下に制限しており、それを超えるとエラーになります。
既に存在するパラメータセットと同じものを作ろうとすると、エラーとなりエラーメッセージが表示されます。

## 5. Run作成

Runを作成してシミュレーションを実行します。
Create New Runsと書かれている箇所でRunの数と投入Host（Simulator登録時に実行可能ホストとして指定されたHostしか選択できない）を選択して[Create Run]ボタンを押します。
実行可能Hostが一つも表示されない場合は、Simulatorの登録時に実行可能Hostを指定し忘れたと考えられます。
Simulatorを確認しで確認しEditボタンから設定を変更すること。

![Run登録]({{ site.baseurl }}/images/new_run.png){:width="400px"}

SimulatorがMPI, OpenMPに対応している場合にはここでMPIプロセス数、OpenMPスレッド数を入力するためのフィールドも表示されます。
Hostに登録したMPIプロセス数、OpenMPスレッド数の最小値・最大値と整合しない場合はRunの作成時にエラーになります。

投入するホストによっては、ジョブスケジューラに応じたパラメータHostの場合も、ここでホストパラメータの入力が要求されます。（ホストパラメータについての詳細は次章）

また[Preview]ボタンをクリックすると、実際に投入されるジョブスクリプトをプレビューできます。
ジョブがうまく実行できない場合はこちらを確認すると良いです。

Runを作成するとバックグラウンドでリモートホストにジョブが投入されます。
ただしHostで指定された max_num_jobs がジョブの上限数で、それ以上のジョブは投入されません。
実行中のジョブが完了し次第、順次ジョブが投入されます。

## 6. 実行中のジョブの確認

ナビゲーションバーの[Jobs]をクリックすると、実行中(running)、スケジューラに投入済み(submitted)、実行待ち（created）のジョブ一覧を確認できます。
この情報はバックグラウンドプロセスが１分ごとにリモートホストをポーリングして取得しているのでタイムラグがある場合があります。
[Update]ボタンをクリックすると最新の情報に更新されます。

![Job確認]({{ site.baseurl }}/images/jobs.png){:width="400px"}

## 7. 結果の確認

ジョブの実行が完了すると自動的に結果がサーバー内のデータベースに取り込まれます。
Runの作成時のページに移動するとRunの一覧が表示され、そのRunのステータスが *finished* になっている事が確認できます。
(実行に失敗した場合、 *failed* というステータスになります。その際も結果のファイルはデータベースに格納されるので、そこからエラーの発生原因を調査できます。）

各RunをクリックするとRunの結果のファイルをブラウザから確認できます。
カレントディレクトリ直下に作成されたファイルは、ブラウザが対応していれば直接参照できます。
（シミュレータによって作成されたディレクトリやその中身については、Download Archiveボタンをクリックしダウンロードできます。）
Aboutタブをクリックすると、実行日時・CPU時間などの詳細な情報を取得できます。
データが格納されたパスも表示されるため、ブラウザ経由だけではなく直接そのパスから結果を取得する事もできます。

![Run確認]({{ site.baseurl }}/images/show_run.png){:width="400px"}

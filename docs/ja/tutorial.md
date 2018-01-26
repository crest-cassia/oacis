---
layout: default
title: "チュートリアル"
lang: ja
next_page: configuring_host
---

# {{ page.title }}

ここでは簡単なシミュレーターをOACISに登録してジョブを実行し、結果を参照するまでの手順を示します。

* TOC
{:toc}
---

## ここで登録するシミュレーターについて

このチュートリアルでは、例として交通流のシミュレーションモデルであるNagel-Schreckenbergモデルを実行しましょう。
このモデルは1990年代に提案されたシンプルなモデルで、１次元のレーンを移動する車をセルオートマトンとしてモデル化しています。
モデルの詳細については[こちら](https://en.wikipedia.org/wiki/Nagel%E2%80%93Schreckenberg_model)を参照してください。

シミュレーターのソースコードはgithub上の[リポジトリ](https://github.com/yohm/nagel_schreckenberg_model)にあります。
READMEに書いてある通りにセットアップして、`run.sh`というスクリプトにパラメータを引数として渡すとシミュレーションが実行されます。
結果のファイルは実行したカレントディレクトリに作成されます。
試しに手元で実行して、どのような挙動になるか確認してみるのもよいでしょう。

以後、この実行スクリプトが `~/nagel_schreckenberg_model/run.sh` に存在するとします。

## 手順

1. Host登録
2. Simulator登録
3. ParameterSet登録
4. ジョブ投入
5. 実行中のジョブの確認
6. 結果の確認
7. パラメータスイープ

**Docker環境の場合はSimulator登録まで完了しています。"ParameterSet登録"から始めてください。**

## 1. Host登録

シミュレータを実行するためのホストを登録します。ここではローカルホストを実行ホストとして登録していきましょう。


前提条件として、サーバーからシミュレータを実行するホストに鍵認証を使用してパスワード無しでSSHログインできるようにする必要があります。
ここでは鍵認証でリモートホストにSSHログインできるようになっているという前提で話を進めます。
SSHの設定については別ページを参照してください。

また、実行ホストでxsubコマンドを使えるようにセットアップする必要があります。
xsub の設定方法については、https://github.com/crest-cassia/xsub を参照してください。

ナビゲーションバーの[Hosts]をクリックし、[New Hosts]のボタンを押すと新規Host登録画面が表示されます。

<iframe width="420" height="315" src="https://www.youtube.com/embed/PooTP9GTroc" frameborder="0" allowfullscreen class="youtube" ></iframe>

このページの入力フィールドにホストの情報を登録します。OACISはここで登録された情報をもとにSSH接続しジョブを投入します。

本チュートリアルでは以下の通りに設定してください。指定されていない項目はデフォルトのままにしてください。

- Name: localhost
    - OACIS内で使う名前。任意のわかりやすい文字列でよい。
- Hostname: localhost
    - SSHの時に利用する接続先ホストの端末名。
- User: [自分の端末のユーザー名]
    - SSH接続時に利用する
- SSH key: [自分の端末にログインする時に使用するSSH鍵のパス]
    - SSH接続時に利用する
- Work base dir: `~/oacis_work`
    - ジョブがこのディレクトリ内で実行される
- Mounted work base dir: `~/oacis_work`
    - ここではWork base dirと同じ内容を指定する。
- Polling interval: 5 
    - workerがステータスをチェックする時間間隔。本チュートリアルでは早く挙動を確認したいので短めに設定しています。

各項目の詳細は [別ページ]({{ site.baseurl }}/{{ page.lang }}/configuring_host.html#host_specification) で説明しています。
他の実行ホストを登録する際にはこちらを参照してください。

## 2. Simulator登録

OACISにシミュレーターを登録する際にはシミュレーターの実行コマンドを登録します。
このコマンドをシェルスクリプトに埋め込んで実行するので、シミュレーターがどの言語で実装されているかということには依存しません。
ただし、シミュレーターは以下の要件を満たす必要があります。

- すべての出力ファイルが実行時のディレクトリ以下に作成される事
    - OACISは実行時にそのジョブ用の一時的なディレクトリを作り、その中でジョブを実行し、完了後にその中のファイルすべてを取り込みます。仮にそれ以外の場所に結果を保存する仕様にした場合、それらの結果は保存されません。
- パラメータの入力を引数またはJSONで受け付ける事
    - 引数渡しの場合、パラメータが定義された順番に引数で渡されて、最後の引数として乱数の種が渡されます。
        - 例えば、param1=100, param2=3.0, seed(乱数の種)=12345 の場合、以下のコマンドが実行されます。
            -  `~/path/to/simulator.out 100 3.0 12345`
    - JSON形式の場合、OACISは*_input.json* というファイルを自動的に生成してから、`~/path/to/simulator.out`のように引数なしのコマンドを実行します。シミュレータはカレントディレクトリの *_input.json* をパースするよう実装してください。*_input.json*の形式は以下のとおりです。
        - `{"param1":100,"param2":3.0,"_seed":12345}`
        - `_seed`というキーで乱数の種を指定できます。
- *_output.json*を出力するように実装すること(optional)
    - *_output.json*が出力されていればOACISによってパースされ、webインターフェース上で手軽に結果を確認できるほか、結果がデータベースに自動的に登録されます(詳しくは後述の __5. 結果の確認__ を御覧ください)。出力しなければ何も表示されず、実行自体には問題ありません。
- 以下の名前のファイルを実行中に読み書きしないこと。また、その有無によって動作が変わらないこと
    - *_status.json* , *_time.txt*, *_version.txt*
    - *_input.json*と*output.json_*のほか、これらのファイル名もOACISによって予約されています。干渉を防ぐため、シミュレータ内ではこれらの文字列をファイル操作・読み書きの目的で使用してはなりません。



- 正常終了時にリターンコード０、エラー発生時に０以外を返す事
    - リターンコードによってシミュレーションの正常終了/異常終了が判定されます。

シミュレータはあらかじめ実行ホスト上でビルドしておき実行可能な状態で配置してください。
また複数のホストで実行する場合、シミュレータを同一のパスに配置する必要があります。
そのためには絶対パスで指定するよりもホームディレクトリからの相対パスで指定するとよいです。

本チュートリアルで登録する交通流シミュレーターは上記の要件を満たしています。OACISに登録していきましょう。

<iframe width="420" height="315" src="https://www.youtube.com/embed/tF_9EYMxVoA" frameborder="0" allowfullscreen class="youtube"></iframe>

Simulator一覧ページ(/simulators)で[New Simulator]ボタンをクリックすると新規Simulator登録画面が表示されます。

このページの入力フィールドにシミュレータの情報を登録します。登録する項目は [シミュレーターの仕様]({{ site.baseurl }}/{{ page.lang }}/configuring_simulator.html#simulator_specification) のページで説明しています。

本チュートリアルでは以下のように設定します。その他はデフォルトにしてください。

- Name: NS\_model
- Definition of Parameters:
    - [L, Integer, 100]
    - [Vmax, Integer, 5]
    - [density, Float, 0.3]
    - [p\_d, Float, 0.1]
    - [t\_init, Integer, 100]
    - [t\_measure, Integer, 100]
- Command: `~/nagel_schreckenberg_model/run.sh` （シミュレーターを配置したパス）
- Input type: Argument （パラメータは引数で渡す）
- Executable_on: localhostにチェック

（注）パラメータの型とデフォルト値が整合しない場合はエラーになります。

## 3. ParameterSet登録

Simulator一覧ページで登録したシミュレータ名のリンクをクリックすると、ParameterSet一覧画面が出ます。
現時点では、ParameterSetが何も作られていないので空のテーブルが表示されるだけですが、ParameterSetを作成した後はここに一覧で表示されます。

ParameterSetを新規作成するために[New Parameter Set]のボタンをクリックします。

<iframe width="420" height="315" src="https://www.youtube.com/embed/hzVnuW2M7oc" frameborder="0" allowfullscreen class="youtube"></iframe>

上の様に登録フォームが現れるので、シミュレーションを実行したいパラメータを入力し、"Target # of Runs"を0にします。最後に[Create]をクリックします。
（この画面からRunも作成する事ができますが、今回は簡単のため「# of Runs」のフィールドは０のままにしておきましょう。）

（注）ちなみにこのときにコンマで区切って複数の値を入力すると、複数のParameterSetを同時に作成する事ができます。
ただし同時に作ることができるParameterSetの数は100以下に制限しており、それを超えるとエラーになります。

ここではデフォルトの値のままParameterSetを作ってみましょう。

## 4. Run作成

作成したParameterSetに対してRunを作成してシミュレーションを実行します。
Create New Runsと書かれている箇所でRunの数と投入Host（Simulator登録時に実行可能ホストとして指定されたHostしか選択できない）を選択して[Create Run]ボタンを押します。

<iframe width="420" height="315" src="https://www.youtube.com/embed/p6q9FYIxAIQ" frameborder="0" allowfullscreen class="youtube"></iframe>

（注）実行可能Hostが一つも表示されない場合は、Simulatorの登録時に実行可能Hostを指定し忘れたと考えられます。
その場合はSimulatorのEditボタンで設定を修正してください。

SimulatorがMPI, OpenMPに対応している場合にはここでMPIプロセス数、OpenMPスレッド数を入力するためのフィールドも表示されます。
Hostに登録したMPIプロセス数、OpenMPスレッド数の最小値・最大値と整合しない場合はRunの作成時にエラーになります。
また投入するホストによっては、ジョブスケジューラのパラメータの入力が要求されます。（詳細はホストの仕様のページを参照）

ここでは１本のRunを作成してみましょう。

（注）この時、[Preview]ボタンをクリックすると実際に投入されるジョブスクリプトをプレビューできます。
ジョブがうまく実行できない場合はこちらを確認すると良いです。

Runを作成するとバックグラウンドでリモートホストにジョブが順次投入されます。

## 5. 結果の確認

ジョブの実行が完了すると自動的に結果がサーバー内のデータベースに取り込まれます。
今回のシミュレーターの場合、10秒ほどでRunのステータスが *finished* になっている事が確認できます。
(実行に失敗した場合、 *failed* というステータスになります。その際も結果のファイルはデータベースに格納されるので、そこからエラーの発生原因を調査できます。）

各RunをクリックするとRunの結果のファイルをブラウザから確認できます。
ジョブ実行時にカレントディレクトリ内に作成されるファイルは全て結果のファイルとして保存されます。
画像のファイルはブラウザ上で直接参照することもできます。

出力ファイルの中に"_output.json"という特殊な名前で結果をJSONフォーマットで保存すると、結果をデータベースに保存することができ後述するようなプロットツールを使って閲覧することもできます。

またAboutタブをクリックすると、実行日時・CPU時間などの詳細な情報を取得できます。
データが格納されたパスも表示されるため、ブラウザ経由だけではなく直接そのパスから結果を取得する事もできます。

## 6. 他のパラメータでの実行

ParameterSetとRunを作ってジョブを実行し、結果を確認する方法を学びました。
次はパラメータの値を変えながら多数のジョブをまとめて作る方法を試してみましょう

ここでは車両密度と最大速度の値をそれぞれ５種類ずつ変えていき、結果がどう変わるかみていきます。

<iframe width="420" height="315" src="https://www.youtube.com/embed/Lnta80r7vCA" frameborder="0" allowfullscreen class="youtube"></iframe>

ParameterSetの新規作成ボタンをクリックしてください。値をコンマ区切りで入力すると複数のParameterSetを同時に作ることができます。
Vmaxに「3,4,5,6,7」、densityに「0.05,0.1,0.2,0.3,0.4,0.5」をそれぞれ入力してください。
こうすると、合計30種類のParameterSetが作成されます。
（より正確に言うと、さきほど作成したParameterSetが一つ含まれるので新規作成されるのは29個です。）

（注）一度に作成できるParameterSetの数は100個に制限されています。それ以上、多数のParameterSetを作る場合はCommand Line Interfaceを使用します。

さらに "Target # of Runs"の値を1にします。すると30個のParameterSetそれぞれの配下にRunが１つになるまで作成されます。
"Create"ボタンを押すと、ParameterSetとRunが作成されたことがわかると思います。

ナビゲーションバーの[Runs]をクリックすると、実行中(running)、スケジューラに投入済み(submitted)、実行待ち（created）のジョブ一覧を確認できます。
多くのRunを作成した場合、こちらで実行状況を確認するとよいでしょう。

これらの結果を一つ一つ確認していくのは手間がかかります。OAICSはパラメータを変えた時に結果がどのように変わるか素早く結果を確認するためのツールを用意しています。

<iframe width="420" height="315" src="https://www.youtube.com/embed/QXOycX9fnOw" frameborder="0" allowfullscreen class="youtube"></iframe>

まず流量がパラメータによってどのように変化していくか見ていきましょう。
あるParameterSetを選んで、プロットのタブを選択します。
[Line plot]-[density]-[flow]を選択してプロットします。
現在選択されているParameterSetに対してdensityのみが異なるParameterSetを集めてきて、flowのdensity依存性をプロットすることができます。
自動車の密度を上げていくとある値までは流量が増えるものの、ある閾値を超えてしまうと渋滞が発生して逆に流量が下がっていくことがわかります。
各点をダブルクリックするとそのParameterSetのページが異なるタブで開きます。詳細を確認する時に役に立つでしょう。

パラメータを変えていくとスナップショットがどのように変わるかも見てみましょう。
[Figure viewer]-[density]-[Vmax]-[/traffic.png] と選択します。
横軸に密度、縦軸に車の最高速度としてスナップショットが散布図上に表示されます。
画像をマウスオーバーすると拡大画像も見ることができます。
このようにして渋滞の様子がパラメータを変えていくとどのように変化していくかを直感的に確認することができるようになっています。

さらに流量が最大になる付近の様子を詳細に調べましょう。

<iframe width="560" height="315" src="https://www.youtube.com/embed/BBdLcDwtLcI" frameborder="0" allowfullscreen class="youtube"></iframe>

ParameterSetの新規作成画面に行って、Vmaxを[3,4,5,6,7]、densityを[0.05, 0.1, 0.15, 0.2, 0.25, 0.3] と入力します。
また統計誤差を少なくするために "Number of Runs" を5にして実行しましょう。
実行が終わるとより詳細に流量が最大になる様子が見られると思います。


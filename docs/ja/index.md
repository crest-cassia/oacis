---
layout: default
title: "はじめに"
lang: ja
next_page: overview
---

# {{ page.title }}

---

## OACISとは？

「OACIS」はオープンソースのシミュレーション実行管理フレームワークです。

計算機シミュレーションによって研究を行う際には「ある決められたパラメータやモデルで一度計算したら終わり」というようなことはほとんどなく、パラメータやモデルを試行錯誤的に変えながら計算していくことが多いです。
しかし、パラメータを変えながら数値実験しているとすぐに数百から数万もの実験結果がまれ、それらを手動で管理するのは効率が悪いだけでなく、間違いのもとになりかねません。
例えば、手動でシミュレーションを実行する場合の典型的な手順は以下のようになるでしょう

1. リモートホストにログイン
1. 実行用ディレクトリを作成
1. ジョブ実行用スクリプト（ジョブスクリプトと呼ぶ）を作成。実行時のパラメータを記入
1. スケジューラにサブミット
1. ジョブ実行完了まで待つ
1. 結果をローカルホストに転送
1. 結果の解析
1. （他のパラメータでの計算が必要であれば）最初に戻る

上記の手続きの大部分をOACISによって自動化することができます。
研究者が計算したいシミュレーターを登録することにより、実行時の記録（パラメータ、実行日時、ホスト、シミュレーターのバージョン）を結果とひも付けて自動的にDBに保存することができます。
またジョブの実行や結果の閲覧をブラウザ上から効率的に行うことができ、研究者はより本質的な作業に集中できるようになります。

OACISはRubyとPythonのAPIを持っており、パラメータの選択やジョブの実行を自動化することができます。
これらを利用するとパラメータスイープや最適化、感度解析などを簡単に行うことができます。

## スクリーンショット

<div id="carousel-screen-shot" class="carousel slide" data-ride="carousel">
  <!-- Indicators -->
  <ol class="carousel-indicators">
    <li data-target="#carousel-screen-shot" data-slide-to="0" class="active"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="1"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="2"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="3"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="4"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="5"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="6"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="7"></li>
  </ol>

  <!-- Wrapper for slides -->
  <div class="carousel-inner" role="listbox">
    <div class="item active">
      <img src="{{ site.baseurl }}/images/screenshots/1.png" alt="1">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/2.png" alt="2">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/3.png" alt="3">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/4.png" alt="4">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/5.png" alt="5">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/6.png" alt="6">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/7.png" alt="7">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/8.png" alt="8">
      <div class="carousel-caption">
      </div>
    </div>
  </div>

  <!-- Controls -->
  <a class="left carousel-control" href="#carousel-screen-shot" role="button" data-slide="prev">
    <span class="glyphicon glyphicon-chevron-left" aria-hidden="true"></span>
    <span class="sr-only">Previous</span>
  </a>
  <a class="right carousel-control" href="#carousel-screen-shot" role="button" data-slide="next">
    <span class="glyphicon glyphicon-chevron-right" aria-hidden="true"></span>
    <span class="sr-only">Next</span>
  </a>
</div>

## APIのサンプル

例えば、あるシミュレーターの"p1"と"p2"というパラメータを変化させながらジョブを実行したいとします。
OACISのAPIを使って書く場合、以下のようになります。
詳細は [How to use APIs]({{ site.baseurl }}/en/api.html) をみてください。

```ruby
sim = Simulator.where(name: "my_simulator").first

p1_values = [1.0,2.0,3.0,4.0,5.0]                                         # a standard way to make an array
p2_values = [2.0,4.0,6.0,8.0,10.0]
base_param = sim.default_parameters                                  # => {"p1"=>1.0, "p2"=>2.0, "p3"=>3.0}

host = Host.where(name: "localhost").first
host_param = host.default_host_parameters

# We are going to fix the parameters other than "p1" and "p2"
p1_values.each do |p1|                  # iterate over p1
  p2_values.each do |p2|                # iterate over p2
    param = base_param.merge({"p1"=>p1,"p2"=>p2})           #   => {"p1"=>p1, "p2"=>p2, "p3"=>3.0}
    ps = sim.find_or_create_parameter_set( param )          #   => ParameterSet of the given parameters
    runs = ps.find_or_create_runs_upto(5, submitted_to: host, host_param: host_param)  # creating runs under given parameter sets
  end
end
```

## このドキュメントの構成

本ドキュメントではOACISの使い方を説明します。構成は以下のようになっています。

- システム概要
- インストール
- 基本的な使い方
- 高度な使い方
- Command Line Interface(CLI)の使い方
- Tips

とりあえず使ってみたい場合は「基本的な使い方」の章までを見れば使い始められるようになっています。
それ以降の章は必要に応じて読んでください。

## コンタクト

質問、機能リクエスト、バグ報告は oacis-dev _at_ googlegroups.com までメールを送ってください。


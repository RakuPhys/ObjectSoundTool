# ObjectSoundTool
[こちらの記事](https://raku-phys.hatenablog.com/entry/object_with_ambi)に対応した、オブジェクト音にアンビソニックスに基づく反響音を付加するために用いるスクリプト等をまとめています。

## Position Recorderの使い方
- PositionRecorder.prefabをシーンの受聴位置に設置します
- 位置を記録する全てのオブジェクト (またはその親オブジェクト) をインスペクタに設定します
- 位置の記録間隔を必要に応じて変更します
- 時間の基準となるタイムラインを設定します
- CSVファイルの保存先フォルダを設定します

なお本スクリプトはC#で記述されており、Unity上での動作を想定したものです。

## Ambisonics Player (追加)
AmbiconisのクリップはUnity Timeline上に配置することが出来ません。そのため、Ambisonicsのクリップを適用したAudioSourceを`Play on Awake`で用意して、これをTimelineからActiveにすることで再生を行います。ただし、この方法ではLate Joinerに同期しない他、再生がずれることがあることも確認されています。AmbisonicsPlayerは、このAmbisonicsの再生をタイムラインの進行に同期させるために導入されます。
### 使い方
- AmbisonicsPlayer.prefabをシーンに追加します
- 時間の基準となるタイムラインを設定します
- Timeline上でのAmbisonicsのActive時間を設定します
- 再生ずれを検出するしきい値を設定します
    - しきい値が大きいと、同期後も最大でそのしきい値分ずれて再生される可能性があります
    - しきい値が小さすぎると、同期が繰り返され、再生が不安定になります (ずれが不安定にうごく原因はよくわかっていませんが、再生そのものというよりUdonでの時刻の取得がふらついているものと思います。)
    - ずれ検出のためのずれの値は、フレーム間での移動平均をとっています (これにより多少安定化が図られています)

## ReaperToolsの使い方
CSVファイルを受け取って、Reaperのオートメーションを作るためのReaScriptです。あまり公開向けに整備されていないため使いづらいところが多いと思います。あくまでも参考までに公開します。

### SetEnvelopeFromCSV.lua
CSVを入力としてEnvelopeを作成するメインのluaファイルです。エンベロープの作成前に、事前作成したテンプレートを元に各オブジェクト用のトラック生成も併せて行います。また、スコアが設定されている場合には、スコアに従ってAudioClipを配置します。

### EnvelopeUtils.lua
SetEnvelopeFromCSVにインポートする形で使われるUtilsです。CSVで記録された値から0-1のエンベロープ値に変換する関数などが用意されています。

### Reaperプロジェクトの想定構成
SetEnveloopeFromCSVを実行する前提条件として、オブジェクトごとのルーティング・FX設定のテンプレートとなるトラックを作っておく必要があります。
テンプレートトラックは次のような構成です。なお、各サブトラックの[Template]の部分は、SetEnvelopeFromCSVによって各オブジェクト毎にコピーされる際にはオブジェクト名に置き換わります。

![TemplateTrack](https://github.com/user-attachments/assets/87675e19-849a-4c8e-92ff-7f9204a2eac6)

- Source_Template: このトラックに配置されたAudioClipがCinematic RoomやHaloUpmixを通じてサラウンド化します
- Center_Template: SourceTemplateでサラウンド化された音のうちCenterチャンネルをここに送ります
- ReverbAmbi_Template: SourceTemplateでサラウンド化された音のうち、Center以外のチャンネルをここに送り、IEM MultiEncoder等でアンビソニックス形式に変換します。なお、実際には全てのチャンネルを送った後にMultiEncoder上でミュートする方がシンプルになります。

### CSVファイルフォルダの想定構成
CSVファイルの格納ディレクトリは下記のフォルダ構成である必要があります。
````
CSVFiles
├── SourcePos
│   ├── [#1 ObjectName].csv
│   ├── [#2 ObjectName].csv
│   └── ...
├── Score
│   ├── [#1 ObjectName]_Score.csv
│   ├── [#2 ObjectName]_Score.csv
│   └── ...
└── SourceInfo.csv
````
#### SourceInfo.csvの仕様
````objectName,trackType,envName,envFunc,loadScore,useScore````

- objectName: オブジェクト名
- trackType: Source/ReverbAmbiのいずれか
- envName: 適用するエンベロープの名前 
- envFunc: CSVの値からエンベロープ値(0-1)に変換する関数の名前 (EnvelopeUtils内に定義)
- loadScore, useScore: スコアに従ってクリップを自動的に配置する場合にそのオブジェクトのloadScore=1にする。一つのオブジェクトあたりtrackType=Sourceの行を1行だけloadScore=1とする。[未整備機能]

#### SourcePos/[ObjectName].csvの仕様
````time,x,y,z,azimuth,elevation,distance````
- time: Timelineの時刻
- x,y,z: オブジェクトのリスニングポイントからの相対座標
- azimuth, elevation, distance: オブジェクトのリスニングポイントからの相対極座標

#### Score/[ObjectName]_Score.csvの仕様
````bar,step,clipSuffix,objNum,volume,volume3D````
- bar: クリップを配置する小節
- step: クリップを配置する拍 (1小節を0-15に16分割している)
- clipSuffix: 各クリップは[ObjectName]_[clipSuffix].wavとして保存し、このclipSuffixで特定のクリップを指定する。
- volume: 配置するクリップにかかるボリューム[dB]
- objNum, volume3D: VRC内でCSVに従って音を再生するために必要な変数だがこのリポジトリで公開されている範囲の機能としては使用しない

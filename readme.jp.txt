
ドット絵エディタ Dharl 
======================

これは何？
----------

Dharlは少機能のドット絵エディタで、フリーソフトウェアです。

かつて存在した「キャラクタレイザー1999」というソフトウェアを念頭に置いて設計されています。


使い方
------

Dharlのウィンドウは、大まかにいって次の二つの領域に分割されています。

    +----------+----------+
    |          |          |
    | ペイント | イメージ |
    |  エリア  |  リスト  |
    |          |          |
    +----------+----------+

ペイントエリアは、実際に描画作業を行える領域と、そのためのツールを備えています。

イメージリストは、幾つかの画像のビューワのように機能します。このリストから画像を"ポップ"してペイントエリアに転送したり、ペイントエリアから描画中のデータを"プッシュ"してイメージリスト上のイメージに反映させたりする事ができます。

あなたの作業手順は、例えば次のようになるでしょう。

 1. 画像を開く、または新規作成します。その画像はイメージリスト上に表示されます。
 2. イメージリスト内の画像の上で右クリックし、画像をポップします。その画像の描画データとパレットがペイントエリアに表示されます。
 3. ペイントエリア上で、描画ツールを使って画像を編集します。
 4. イメージリスト内の画像の上で左クリックし、編集した画像をプッシュします。
 5. Ctrl+Sを押して、画像を保存します。


ビルド方法
----------

32ビット:

    dub build --arch=x86

64ビット:

    dub build

コンソールを除く場合は`--build=gui`を、リリースビルド時には`--build=release`を追加で指定して下さい。

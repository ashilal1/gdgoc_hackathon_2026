# AnyWear (by Team: ファイヤーマンジャケット)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![MediaPipe](https://img.shields.io/badge/MediaPipe-00BFFF.svg?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/mediapipe)

> **"Brand New Hello World." へのアンサー**
> プログラミングの世界への第一歩である「Hello World」。私たちはこの概念をアパレル業界に持ち込みました。スマートフォン一つで、いつでもどこでも服を試着できる世界。
> **「AnyWear（エニウェア）」**は、試着のために店舗へ赴くこれまでの常識を覆し、アパレルECにおける**「新しい常識（ニュー・スタンダード）」**を定義します。

---

## デモ動画 (Demo Video)

[![AnyWear Demo](https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)

> ※画像をクリックするとYouTube動画が再生されます。

---

## 解決する社会的課題

現在のオンラインショッピングには、消費者が超えられない**「試着の壁」**が存在します。

- 「オンライン限定の服、自分に合うサイズ感が分からない…」
- 「試着せずに買ったらサイズが合わず、結局返品してしまった」

これにより、ユーザー体験が損なわれるだけでなく、EC事業者にとっても**「高い返品率による多大なコストと環境負荷（廃棄問題）」**が深刻な課題となっています。
`AnyWear` は、スマートフォン向けAR技術によるリアルタイムな仮想試着を提供し、この課題を根本から解決します。

## コア体験・機能 (MVP)

本ハッカソンでは、「スマートフォン実機で滑らかに動く、圧倒的な体験」にフォーカスして開発しました。

1. **アイテム・サイズ選択 (Home Screen)**
   直感的なUIで、試着したい服とベースとなるサイズを選択します。
2. **リアルタイムAR仮想試着 (AR Camera Screen) 🚀最重要機能**
   スマートフォンのフロントカメラ映像から、Google MediaPipeを用いてユーザーの骨格（肩・腰などの特徴点）をリアルタイムに検知。数学的な座標変換（アスペクト比の補正等）を行い、2Dの服画像をユーザーの動きにピタリと追従させて重畳表示します。
3. **ワンタップ・サイズ切り替え**
   画面下の「S, M, L, XL」ボタンをタップすると、動的スケール計算によりAR上の服が瞬時に拡大縮小。「着丈が長すぎる」「肩幅がタイト」といったサイズ感の違いを、視覚的かつ即座に確認できます。

## アーキテクチャと技術スタック

単なるライブラリの組み合わせではなく、数学的アプローチによる空間的なAR試着処理を独自に実装しています。

- **フロントエンド:** `Flutter` (iOS/Androidクロスプラットフォームでの高速なプロトタイピングと滑らかなUI描画)
- **AI / コンピュータービジョン:** `MediaPipe Pose Detection` (オンデバイスでの超低遅延な姿勢・骨格推定の実装)
- **バックエンド / DB:** `Firebase` (Firestore / Auth)を用いたリアルタイムなデータ同期
- **AI エージェント構想:** `Agent Development Kit (ADK)` / `Gemini API` _(※将来構想として組み込みを予定)_

## 動作環境とセットアップ (How to Run)

審査員の皆様のお手元でデモを動かしていただくための手順です。
_(※カメラ機能とリアルタイム推論を使用するため、実機でのテストを強く推奨します)_

```bash
# 1. リポジトリのクローン
git clone https://github.com/YOUR_GITHUB_ORG/gdgoc_hackathon_2026.git
cd gdgoc_hackathon_2026

# 2. パッケージのインストール
flutter pub get

# 3. アプリの起動 (iOS実機 または Android実機を接続した状態で実行)
flutter run
```

## 未来の展望 (Future Vision)

現在のMVPをベースに、私たちは以下の「理想のプロダクト」への進化を目指しています。

1. **Gemini & ADKによる専属AIエージェント**
   「しゃがむと少し太ももがキツイですね、Lサイズを取り寄せましょうか？」など、ユーザーの細かい動きや骨格データから、AIが自律的に最適なサイズや着こなしを提案する機能の実装。
2. **Body Passport (分散型体型ID)**
   一度取得した正確な骨格データを安全に保存し、どのECサイトでもワンタップで最適サイズが購入できる社会インフラとしての実装。

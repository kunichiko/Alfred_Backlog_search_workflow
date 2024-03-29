# Alfred Backlog検索ワークフローについて

Alfred上で直接 Backlogの課題検索を行うためのワークフローです。バックログプロジェクトが複数に跨っている場合でも横断検索が可能です。

ただし、検索をシリアルに実行している関係で、実用上は３プロジェクトくらいが限界かなと思います。余力ができたら非同期呼び出し化するなどして並列に検索をかけられるようにしたいと思います。

# インストール方法

とにかく動かしてみたいという方は以下のようにしてください。

## Step 1. ワークフローのインストール

リポジトリのルートにある `BacklogIssueSearch.alfredworkflow` 開くとBacklogにインポートされます。

## Step 2. config.json の設定

Alfread Preferencesにワークフローが取り込まれたら、ワークフローを右クリックして「Open in Finder」を実行し、ファイルの場所を開きます。

そのフォルダに `config.json` というファイルがありますので、そちらを開いて、以下の項目を設定してください。検索対象のプロジェクトが複数ある場合は配列の要素をコピーして増やしてください。

```
[
    {
        "apiKey": "Backlog上で発行したあなたのAPI Keyを設定してください",
        "projectId": "対象のプロジェクトのIDを入れます。数字のIDです。(後述)",
        "projectUrl": "https://xxxx.backlog.jp", ← 対象プロジェクトのベースURLを入れてください
        "projectCode": "ABC" ← 対象プロジェクトのキーを入れてください
    },
```

### apiKeyの取得方法

`https://xxxx.backlog.jp/EditProfile.action` の `xxxx` 部分をあなたのプロジェクトに変更して開くと、個人設定のページが開きます。そのページの「API」タブの中でAPIキーが発行できます。

### プロジェクトIDの調べ方

「プロジェクト設定」というページを開き、ブラウザのURLを確認してください。以下のような形をしていると思います。
```
https://xxxx.backlog.jp/EditProject.action?project.id=12345
```
URL最後にある数字がこのプロジェクトのIDです。

### プロジェクトキー

チケット番号 `ABC-123` の `ABC` の部分です。

## Step 3. アイコンの設定

 `config.json` と同じ階層に `thumbs/` というフォルダがあり `ABC.png` や `DEF.png` というファイルがあると思います。このフォルダに `プロジェクトキー` + `.png` というファイル名でアイコンを置いておくと、検索結果の頭にアイコンが出るようになります。

## Step 4. nkfのインストール

Macから Alfredに入力された Unicode文字列は NFDになっています。NFDとは、例えば平仮名の「が」が「か」と「濁点」のコンビネーションとして表現する手法です。
一方、Backlog内部は NFCという手法を使っているようで、「が」は１文字の「が」として扱われています。

そのため、NFDで表現された文字列を Backlog APIに渡すとうまく検索文字がマッチしません。Backlog内部で NFD → NFC変換をしてくれると良いのですが、呼び出し側で行うことにしました。

PHPの国際化パッケージ(PHP-intl)があれば簡単にできそうだったのですが、Macにには PHP-intlが標準でインストールされておらず、ちょっと面倒です。

ひとまずコマンドラインの `nkf` を呼び出してお茶を濁していますので、Homebrewなどを使って nkf をインストールしてください。

```
> brew install nkf
```

余力があれば PHP-intlにも nkfにも依存しない解決方法を探します（それか Backlog側で対応してくれると嬉しいのですが……）。

## Step 5. PHPのインストール

macOS Monterey 以降、PHPがデフォルトでインストールされなくなってしまいました。こちらも Homebrewでインストール可能です。

```
> brew search php
==> Formulae
brew-php-switcher   php@7.2             phplint             pcp
php                 php@7.3             phpmd               pup
php-code-sniffer    php@7.4             phpmyadmin
php-cs-fixer        php@8.0             phpstan
php-cs-fixer@2      phpbrew             phpunit

==> Casks
eclipse-php 
```

ひとまず、7.4あたりでいいと思います。

```
> brew install php@7.4
```

```
> brew link php
```

インストールされたPHPは `/opt/homebrew/opt/php@7.4/bin/php` や `/opt/homebrew/bin` あたりに入りますので、パスを通しておきます。
zshを使っている場合は、`.zshrc` あたりに以下を書いておいてください。

```
# PHP
#If you need to have php@7.4 first in your PATH, run:
export PATH="/opt/homebrew/opt/php@7.4/bin:$PATH"
export PATH="/opt/homebrew/opt/php@7.4/sbin:$PATH"
```

## Step 6. Alfred キーワードの変更

デフォルトでは Alfred上で `bs` と入力すると検索できるように設定されていますが、ワークフローの設定を開いて好きなキーワードに変更してください。

# 機能説明

* 検索文字に適当な1文字だけ(例えば`.`など)を入れると、プロジェクトホームを開気ます
* 検索結果は各プロジェクト最大10件にしています（更新日が最新のもの10件）。修正したい場合はスクリプトをいじってください。
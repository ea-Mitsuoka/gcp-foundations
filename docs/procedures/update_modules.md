# 既存のモジュールを更新する際の注意点

このドキュメントは、このリポジトリで利用されているTerraformモジュール（ローカル・外部問わず）を安全に更新するための手順と注意点を説明します。

モジュールは複数の場所から参照される共有部品のため、その変更は予期せぬ広範囲な影響を及ぼす可能性があります。手順を慎重に守ってください。

## I. ローカルモジュールの更新

`terraform/modules/`配下に格納されているモジュールを更新する場合の手順です。

### 1. モジュールのコードを編集

`terraform/modules/<your-module-name>/`内の`.tf`ファイルを直接編集します。

### 2. ドキュメントを更新 (`terraform-docs`)

入力変数（`variables.tf`）や出力（`outputs.tf`）に変更を加えた場合は、**必ず`terraform-docs`を実行して`README.md`を更新してください。**

```bash
# 更新したモジュールのディレクトリを指定
terraform-docs markdown table --output-file README.md terraform/modules/<your-module-name>/
```

この更新を忘れると、CIの`docs`ジョブが失敗します。

### 3. 影響範囲の確認 (`plan`の実行)

モジュールの変更が、それを呼び出している既存のインフラにどのような影響を与えるかを確認します。

1. **影響を受けるディレクトリを特定します。**
   `grep`コマンドなどで、変更したモジュールを`source`として指定しているディレクトリをすべて洗い出します。

   ```bash
   # 例: project-factoryモジュールを使っている場所を探す
   grep -r "source.*project-factory" terraform/
   ```

1. **特定したすべてのディレクトリで`plan`を実行します。**
   洗い出したディレクトリそれぞれに移動し、`terraform plan`を実行して、意図しない変更（`destroy`など）が発生しないかを慎重に確認してください。

### 4. コミット & プルリクエスト

変更内容をコミットし、プルリクエストを作成します。
プルリクエスト上ではCIが実行されますが、ご自身でも`plan`の結果をよく確認し、レビュー担当者にもその内容を伝えるようにしてください。

## II. 外部モジュールの更新

`git::`で参照している外部モジュール（例: `string_utils`）を更新する場合の手順です。

### 1. 外部リポジトリで変更・コミット

まず、`ea-Mitsuoka/terraform-modules`のような、対象の外部モジュールが格納されているリポジトリでコードの変更を行い、コミットします。

### 2. 新しいコミットハッシュを取得

`git log`コマンドなどで、上記で作成したコミットのハッシュ（40文字の英数字）を取得します。

### 3. モジュール参照(`ref`)を更新

この`gcp-foundations`リポジトリ内で、更新したい外部モジュールを呼び出している箇所をすべて探し、`source`の`ref=`パラメータを、**手順2で取得した新しいコミットハッシュ**に書き換えます。

参照箇所は`grep`で特定します。

```bash
# 例: string_utilsモジュールを使っている場所を探す
grep -r "source.*string_utils" terraform/
```

**修正前:**
`source = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=610dae0"`

**修正後:**
`source = "git::https://github.com/ea-Mitsuoka/terraform-modules.git//string_utils?ref=535a37e77566e68ab35b1f5266cb1872405f15a2"`

### 4. 引数の変更を確認

外部モジュールの更新に伴い、インターフェース（入力変数や出力）が変更されていないかを確認します。もし変更があれば、モジュールを呼び出している箇所の引数も合わせて修正する必要があります。（私たちが`organization_id`から`organization_name`へ修正したのがこの例です）

### 5. 影響範囲の確認とPR作成

ローカルモジュールの更新時と同様に、影響を受けるすべてのディレクトリで`terraform plan`を実行して影響範囲を確認した後、コミットとプルリクエストの作成に進みます。

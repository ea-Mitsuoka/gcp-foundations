# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "openpyxl==3.1.2",
# ]
# ///
"""
納品物（構築設定明細書）生成スクリプト。

SSoT である gcp-foundations.xlsx と common.tfvars / domain.env から、
日本のシステム開発における一般的な「設計・設定明細書」様式の Excel を生成する。
`make delivery`（handover）の直前に実行され、生成物は delivery/ 配下に出力される。

メタ情報（顧客名・作成者・版数等）は環境変数で上書き可能:
  DELIVERY_CUSTOMER / DELIVERY_VENDOR / DELIVERY_AUTHOR / DELIVERY_VERSION / DELIVERY_DOCNO
"""
import os
import datetime

import openpyxl
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Border, Side, Alignment
from openpyxl.utils import get_column_letter

# ------------------------------------------------------------------------------
# パス設定
# ------------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../.."))
XLSX_PATH = os.path.join(ROOT_DIR, "gcp-foundations.xlsx")
COMMON_TFVARS = os.path.join(ROOT_DIR, "terraform", "common.tfvars")
DOMAIN_ENV = os.path.join(ROOT_DIR, "domain.env")
OUTPUT_DIR = os.path.join(ROOT_DIR, "delivery")

# ------------------------------------------------------------------------------
# スタイル定義（日本のベンダー様式に寄せた配色・罫線）
# ------------------------------------------------------------------------------
FONT_NAME = "Meiryo"
C_HEADER_BG = "1F3864"   # 濃紺（表ヘッダ）
C_HEADER_FG = "FFFFFF"
C_SECTION_BG = "2E5395"  # セクション見出し
C_LABEL_BG = "D9E1F2"    # ラベル列（薄い青）
C_TITLE_FG = "1F3864"
C_DONE = "375623"        # 「完了」文字色（緑）

THIN = Side(style="thin", color="9CA3AF")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

F_TITLE = Font(name=FONT_NAME, size=22, bold=True, color=C_TITLE_FG)
F_SUBTITLE = Font(name=FONT_NAME, size=12, color="595959")
F_SECTION = Font(name=FONT_NAME, size=12, bold=True, color="FFFFFF")
F_HEADER = Font(name=FONT_NAME, size=10, bold=True, color=C_HEADER_FG)
F_LABEL = Font(name=FONT_NAME, size=10, bold=True, color="1F3864")
F_BODY = Font(name=FONT_NAME, size=10, color="000000")
F_DONE = Font(name=FONT_NAME, size=10, bold=True, color=C_DONE)
F_NOTE = Font(name=FONT_NAME, size=9, color="808080", italic=True)

FILL_HEADER = PatternFill("solid", fgColor=C_HEADER_BG)
FILL_SECTION = PatternFill("solid", fgColor=C_SECTION_BG)
FILL_LABEL = PatternFill("solid", fgColor=C_LABEL_BG)

AL_CENTER = Alignment(horizontal="center", vertical="center", wrap_text=True)
AL_LEFT = Alignment(horizontal="left", vertical="center", wrap_text=True)
AL_TOP = Alignment(horizontal="left", vertical="top", wrap_text=True)


# ------------------------------------------------------------------------------
# 入力読み込み
# ------------------------------------------------------------------------------
def read_tfvars(path):
    """common.tfvars からトップレベルのスカラー値を素朴に読む（key = value）。"""
    data = {}
    if not os.path.exists(path):
        return data
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.split("#", 1)[0].strip().strip('"').strip()
            # リスト/マップ行はスキップ（複数行構造は対象外）
            if val.startswith(("[", "{")) or not key.replace("_", "").isalnum():
                continue
            data[key] = val
    return data


def read_domain(path):
    if not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("domain="):
                return line.split("=", 1)[1].strip().strip('"')
    return ""


def read_sheet(wb, name):
    """シートを (headers, [dict,...]) で返す。無ければ ([], [])。"""
    if name not in wb.sheetnames:
        return [], []
    ws = wb[name]
    headers = [c.value for c in ws[1]]
    rows = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if not any(v not in (None, "") for v in row):
            continue
        rows.append(dict(zip(headers, row)))
    return headers, rows


# ------------------------------------------------------------------------------
# シート構築ヘルパ
# ------------------------------------------------------------------------------
def _set_widths(ws, widths):
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w


def section_title(ws, row, text, span):
    """セクション見出し（塗りつぶし帯）を row に書き、次の行番号を返す。"""
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=span)
    c = ws.cell(row=row, column=1, value=text)
    c.font = F_SECTION
    c.fill = FILL_SECTION
    c.alignment = AL_LEFT
    ws.row_dimensions[row].height = 22
    for col in range(1, span + 1):
        ws.cell(row=row, column=col).fill = FILL_SECTION
    return row + 1


def table(ws, row, headers, records, col_keys=None, done_col=None):
    """表ヘッダ＋明細を描画し、次の行番号を返す。
    headers: 表示用ヘッダ名リスト
    records: dict のリスト
    col_keys: 各列に対応する dict キー（None なら headers と同じ）
    done_col: 「完了」など緑表示にする列キー
    """
    col_keys = col_keys or headers
    span = len(headers)
    # ヘッダ行
    for j, h in enumerate(headers, start=1):
        c = ws.cell(row=row, column=j, value=h)
        c.font = F_HEADER
        c.fill = FILL_HEADER
        c.alignment = AL_CENTER
        c.border = BORDER
    ws.row_dimensions[row].height = 20
    row += 1
    # 明細行
    if not records:
        ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=span)
        c = ws.cell(row=row, column=1, value="（定義なし）")
        c.font = F_NOTE
        c.alignment = AL_CENTER
        for col in range(1, span + 1):
            ws.cell(row=row, column=col).border = BORDER
        return row + 2
    for rec in records:
        for j, key in enumerate(col_keys, start=1):
            val = rec.get(key, "")
            if val is None:
                val = ""
            c = ws.cell(row=row, column=j, value=val)
            c.border = BORDER
            c.alignment = AL_TOP
            c.font = F_DONE if (done_col and key == done_col and str(val) == "完了") else F_BODY
        row += 1
    return row + 1


def kv_table(ws, row, pairs, label_w=2):
    """ラベル/値の2列（または span 結合値）テーブル。pairs=[(label, value), ...]。"""
    for label, value in pairs:
        lc = ws.cell(row=row, column=1, value=label)
        lc.font = F_LABEL
        lc.fill = FILL_LABEL
        lc.alignment = AL_LEFT
        lc.border = BORDER
        ws.merge_cells(start_row=row, start_column=2, end_row=row, end_column=label_w + 2)
        vc = ws.cell(row=row, column=2, value="" if value is None else value)
        vc.font = F_BODY
        vc.alignment = AL_LEFT
        for col in range(1, label_w + 3):
            ws.cell(row=row, column=col).border = BORDER
        row += 1
    return row + 1


def yn(flag):
    return "有効" if str(flag).lower() == "true" else "無効"


# ------------------------------------------------------------------------------
# 各シート生成
# ------------------------------------------------------------------------------
def build_cover(wb, meta):
    ws = wb.create_sheet("表紙")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [4, 22, 30, 16, 16])

    ws.cell(row=3, column=2, value="Google Cloud Platform").font = F_SUBTITLE
    t = ws.cell(row=5, column=2, value="基盤構築 設定明細書")
    t.font = F_TITLE
    ws.merge_cells("B5:E6")
    ws.cell(row=8, column=2, value="GCP Foundations 納品ドキュメント").font = F_SUBTITLE

    pairs = [
        ("顧客名", meta["customer"]),
        ("対象組織ドメイン", meta["org_domain"]),
        ("組織 ID", meta["org_id"]),
        ("文書番号", meta["doc_no"]),
        ("版数", meta["version"]),
        ("作成日", meta["date"]),
        ("作成者", meta["author"]),
        ("提供元", meta["vendor"]),
    ]
    row = 12
    for label, value in pairs:
        lc = ws.cell(row=row, column=2, value=label)
        lc.font = F_LABEL
        lc.fill = FILL_LABEL
        lc.alignment = AL_LEFT
        lc.border = BORDER
        ws.merge_cells(start_row=row, start_column=3, end_row=row, end_column=5)
        vc = ws.cell(row=row, column=3, value=value)
        vc.font = F_BODY
        vc.alignment = AL_LEFT
        for col in range(2, 6):
            ws.cell(row=row, column=col).border = BORDER
        ws.row_dimensions[row].height = 22
        row += 1

    # 承認欄（押印枠）
    row += 1
    ws.cell(row=row, column=2, value="承認").font = F_LABEL
    row += 1
    appr_headers = ["承認", "確認", "作成"]
    for j, h in enumerate(appr_headers, start=3):
        c = ws.cell(row=row, column=j, value=h)
        c.font = F_HEADER
        c.fill = FILL_HEADER
        c.alignment = AL_CENTER
        c.border = BORDER
    lc = ws.cell(row=row, column=2, value="役職／氏名")
    lc.font = F_LABEL
    lc.fill = FILL_LABEL
    lc.border = BORDER
    lc.alignment = AL_CENTER
    for r in range(row + 1, row + 3):
        ws.cell(row=r, column=2).border = BORDER
        ws.row_dimensions[r].height = 30
        for j in range(3, 6):
            ws.cell(row=r, column=j).border = BORDER


def build_revision(wb, meta):
    ws = wb.create_sheet("改訂履歴")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [10, 16, 50, 18, 14])
    row = section_title(ws, 2, "改訂履歴", 5)
    records = [{
        "版数": meta["version"],
        "改訂日": meta["date"],
        "改訂内容": "初版作成（GCP 基盤構築の納品）",
        "作成者": meta["author"],
        "承認": "",
    }]
    table(ws, row, ["版数", "改訂日", "改訂内容", "作成者", "承認"], records)


def build_summary(wb, meta, ctx):
    """構築項目一覧（実施サマリ）— 顧客が一目で「何を実施したか」を確認できる総括表。"""
    ws = wb.create_sheet("1.構築項目一覧")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [5, 30, 46, 12])
    row = section_title(ws, 2, "1. 構築項目一覧", 4)

    items = [
        ("組織への取り込み", "組織なしプロジェクトを GCP 組織配下へ移管し Terraform 管理下に統制",
         "完了" if ctx["adopted_projects"] else "—"),
        ("Cloud Identity 認証", "Cloud Identity による組織アカウント／ID 認証基盤の整備", "完了"),
        ("請求先アカウントのリンク", "対象プロジェクトと請求先アカウントの紐付け", "完了"),
        ("管理フォルダ構成", "admin／network 等の管理用フォルダ階層の構築",
         "完了" if ctx["folders"] else "—"),
        ("管理プロジェクト構築", "ログ集約・モニタリング用の管理プロジェクト作成",
         "完了" if ctx["mgmt_projects"] else "—"),
        ("組織ポリシー設定", "セキュア・バイ・デフォルトの組織ポリシー適用",
         "完了" if ctx["org_policies"] else "—"),
        ("ログ集約シンク設定", "監査ログ等を集約ログプロジェクト(BigQuery等)へエクスポート",
         "完了" if ctx["log_sinks"] else "—"),
        ("集中モニタリング設定", "対象プロジェクトをモニタリング対象スコープへ登録",
         "完了" if ctx["monitoring_targets"] else "—"),
        ("予算アラート設定", "予算しきい値超過時のアラート通知設定",
         "完了" if ctx["budget_projects"] else "—"),
        ("ネットワーク構成", "Shared VPC / VPC Service Controls の構成",
         "完了" if (ctx["subnets"] or ctx["perimeters"]) else "—"),
    ]
    records = [{"No": i, "構築項目": n, "概要": d, "実施状況": s}
               for i, (n, d, s) in enumerate(items, start=1)]
    row = table(ws, row, ["No", "構築項目", "概要", "実施状況"], records,
                col_keys=["No", "構築項目", "概要", "実施状況"], done_col="実施状況")
    c = ws.cell(row=row, column=1,
                value="※「—」は本案件の SSoT（gcp-foundations.xlsx）に定義がない項目です。")
    c.font = F_NOTE


def build_overview(wb, meta, ctx):
    ws = wb.create_sheet("2.構築概要")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [22, 30, 18, 18])
    row = section_title(ws, 2, "2. 構築概要（環境情報）", 4)
    tv = ctx["tfvars"]
    pairs = [
        ("組織ドメイン", meta["org_domain"]),
        ("組織 ID", meta["org_id"]),
        ("プロジェクト ID 接頭辞", tv.get("project_id_prefix", "")),
        ("請求先アカウント", tv.get("billing_account_id", "")),
        ("既定リージョン", tv.get("default_region", tv.get("gcp_region", tv.get("region", "")))),
        ("Shared VPC", yn(tv.get("enable_shared_vpc", "false"))),
        ("VPC ホストプロジェクト", yn(tv.get("enable_vpc_host_projects", "false"))),
        ("組織ポリシー適用", yn(tv.get("enable_org_policies", "true"))),
        ("リソース削除許可", yn(tv.get("allow_resource_destruction", "false"))),
    ]
    row = kv_table(ws, row, pairs, label_w=2)

    row = section_title(ws, row, "管理プロジェクト一覧", 4)
    records = [{"用途": p[0], "プロジェクト ID（規約）": p[1], "説明": p[2]}
               for p in ctx["mgmt_projects"]]
    table(ws, row, ["用途", "プロジェクト ID（規約）", "説明"], records,
          col_keys=["用途", "プロジェクト ID（規約）", "説明"])


def build_folders(wb, ctx):
    ws = wb.create_sheet("3.フォルダ構成")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [30, 30])
    row = section_title(ws, 2, "3. フォルダ構成", 2)
    records = [{"フォルダ名": f["resource_name"], "親": f["parent_name"]}
               for f in ctx["folders"]]
    table(ws, row, ["フォルダ名", "親（フォルダ／組織）"], records,
          col_keys=["フォルダ名", "親"])


def build_projects(wb, ctx):
    ws = wb.create_sheet("4.プロジェクト一覧")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [22, 18, 10, 26, 12, 12, 14, 14])
    row = section_title(ws, 2, "4. プロジェクト一覧", 8)
    records = []
    for p in ctx["projects"]:
        records.append({
            "表示名": str(p.get("resource_name") or ""),
            "配置先": str(p.get("parent_name") or ""),
            "環境": str(p.get("environment") or ""),
            "既存ID(取り込み)": str(p.get("existing_project_id") or ""),
            "集中監視": "○" if str(p.get("central_monitoring")).lower() == "true" else "",
            "集中ログ": "○" if str(p.get("central_logging")).lower() == "true" else "",
            "予算(円)": p.get("budget_amount") or "",
            "予算通知先": str(p.get("budget_alert_emails") or ""),
        })
    table(ws, row,
          ["表示名", "配置先", "環境", "既存ID(取り込み)", "集中監視", "集中ログ", "予算(円)", "予算通知先"],
          records,
          col_keys=["表示名", "配置先", "環境", "既存ID(取り込み)", "集中監視", "集中ログ", "予算(円)", "予算通知先"])


def build_org_policies(wb, ctx):
    ws = wb.create_sheet("5.組織ポリシー")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [22, 40, 12, 30, 12])
    row = section_title(ws, 2, "5. 組織ポリシー設定一覧", 5)
    records = []
    for p in ctx["org_policies"]:
        records.append({
            "適用対象": str(p.get("target_name") or ""),
            "ポリシーID": str(p.get("policy_id") or ""),
            "強制": "ON" if str(p.get("enforce")).lower() == "true" else "OFF",
            "許可リスト": str(p.get("allow_list") or ""),
            "適用モード": str(p.get("apply_mode") or "live"),
        })
    table(ws, row, ["適用対象", "ポリシーID", "強制", "許可リスト", "適用モード"], records,
          col_keys=["適用対象", "ポリシーID", "強制", "許可リスト", "適用モード"])


def build_log_sinks(wb, ctx):
    ws = wb.create_sheet("6.ログ集約シンク")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [20, 40, 16, 30, 12])
    row = section_title(ws, 2, "6. ログ集約シンク設定", 5)
    records = []
    for s in ctx["log_sinks"]:
        records.append({
            "ログ種別": str(s.get("log_type") or ""),
            "フィルタ": str(s.get("filter") or ""),
            "宛先種別": str(s.get("destination_type") or ""),
            "宛先": str(s.get("destination_parent") or ""),
            "保持日数": s.get("retention_days") or "",
        })
    table(ws, row, ["ログ種別", "フィルタ", "宛先種別", "宛先", "保持日数"], records,
          col_keys=["ログ種別", "フィルタ", "宛先種別", "宛先", "保持日数"])


def build_monitoring(wb, ctx):
    ws = wb.create_sheet("7.監視・予算")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [24, 30, 36])

    row = section_title(ws, 2, "7-1. アラート定義", 3)
    records = [{
        "アラート名": str(a.get("alert_display_name") or a.get("alert_name") or ""),
        "条件(metric filter)": str(a.get("metric_filter") or ""),
        "説明": str(a.get("alert_documentation") or ""),
    } for a in ctx["alert_defs"]]
    row = table(ws, row, ["アラート名", "条件(metric filter)", "説明"], records,
                col_keys=["アラート名", "条件(metric filter)", "説明"])

    row = section_title(ws, row, "7-2. 通知先", 3)
    records = [{
        "アラート名": str(n.get("alert_name") or ""),
        "通知先メール": str(n.get("user_email") or ""),
        "受信": "受信する" if str(n.get("receive_alerts")).lower() == "true" else "受信しない",
    } for n in ctx["notifications"]]
    row = table(ws, row, ["アラート名", "通知先メール", "受信可否"], records,
                col_keys=["アラート名", "通知先メール", "受信"])

    row = section_title(ws, row, "7-3. 予算アラート", 3)
    records = []
    for p in ctx["budget_projects"]:
        records.append({
            "プロジェクト": str(p.get("resource_name") or ""),
            "予算額(円)": p.get("budget_amount") or "",
            "通知先": str(p.get("budget_alert_emails") or ""),
        })
    table(ws, row, ["プロジェクト", "予算額(円)", "通知先メール"], records,
          col_keys=["プロジェクト", "予算額(円)", "通知先"])


def build_network(wb, ctx):
    ws = wb.create_sheet("8.ネットワーク")
    ws.sheet_view.showGridLines = False
    _set_widths(ws, [20, 24, 20, 24])

    row = section_title(ws, 2, "8-1. Shared VPC サブネット", 4)
    records = [{
        "ホスト環境": str(s.get("host_project_env") or ""),
        "サブネット名": str(s.get("subnet_name") or ""),
        "リージョン": str(s.get("region") or ""),
        "CIDR": str(s.get("ip_cidr_range") or ""),
    } for s in ctx["subnets"]]
    row = table(ws, row, ["ホスト環境", "サブネット名", "リージョン", "CIDR"], records,
                col_keys=["ホスト環境", "サブネット名", "リージョン", "CIDR"])

    row = section_title(ws, row, "8-2. VPC Service Controls 境界", 4)
    records = [{
        "境界名": str(p.get("perimeter_name") or ""),
        "タイトル": str(p.get("title") or ""),
        "制限サービス": str(p.get("restricted_services") or ""),
        "モード": "ドライラン" if str(p.get("dry_run")).lower() == "true" else "適用",
    } for p in ctx["perimeters"]]
    table(ws, row, ["境界名", "タイトル", "制限サービス", "ドライラン/適用"], records,
          col_keys=["境界名", "タイトル", "制限サービス", "モード"])


# ------------------------------------------------------------------------------
# メイン
# ------------------------------------------------------------------------------
def derive_mgmt_projects(prefix, tfvars):
    prefix = prefix or "<prefix>"
    items = [
        ("中央ログ集約", f"{prefix}-logsink", "監査ログ等を集約・保管する管理プロジェクト"),
        ("中央モニタリング", f"{prefix}-monitoring", "各プロジェクトを監視対象とするモニタリング管理プロジェクト"),
    ]
    if str(tfvars.get("enable_vpc_host_projects", "false")).lower() == "true":
        items.append(("共有VPCホスト(本番)", f"{prefix}-vpc-host-prod", "本番系 Shared VPC ホストプロジェクト"))
        items.append(("共有VPCホスト(開発)", f"{prefix}-vpc-host-dev", "開発系 Shared VPC ホストプロジェクト"))
    return items


def main():
    today = datetime.date.today().strftime("%Y-%m-%d")
    stamp = datetime.date.today().strftime("%Y%m%d")

    tfvars = read_tfvars(COMMON_TFVARS)
    domain = read_domain(DOMAIN_ENV)
    org_domain = tfvars.get("organization_domain") or domain or "（未設定）"

    meta = {
        "customer": os.environ.get("DELIVERY_CUSTOMER", "（顧客名を記入）"),
        "vendor": os.environ.get("DELIVERY_VENDOR", "株式会社イー・エージェンシー"),
        "author": os.environ.get("DELIVERY_AUTHOR", "（作成者を記入）"),
        "version": os.environ.get("DELIVERY_VERSION", "1.0"),
        "doc_no": os.environ.get("DELIVERY_DOCNO", f"GCP-FND-{stamp}"),
        "date": today,
        "org_domain": org_domain,
        "org_id": tfvars.get("organization_id", "（未設定）"),
    }

    if not os.path.exists(XLSX_PATH):
        print(f"⚠️  SSoT '{XLSX_PATH}' が見つかりません。`make template`→`make generate` 後に実行してください。")
        return

    wb_src = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    _, resources = read_sheet(wb_src, "resources")
    _, org_policies = read_sheet(wb_src, "org_policies")
    _, log_sinks = read_sheet(wb_src, "log_sinks")
    _, alert_defs = read_sheet(wb_src, "alert_definitions")
    _, notifications = read_sheet(wb_src, "notifications")
    _, subnets = read_sheet(wb_src, "shared_vpc_subnets")
    _, perimeters = read_sheet(wb_src, "vpc_sc_perimeters")

    folders = [r for r in resources if str(r.get("resource_type")).strip().lower() == "folder"]
    projects = [r for r in resources if str(r.get("resource_type")).strip().lower() == "project"]
    adopted = [p for p in projects if str(p.get("existing_project_id") or "").strip()]
    budget_projects = [p for p in projects if str(p.get("budget_amount") or "").strip()]
    monitoring_targets = [p for p in projects if str(p.get("central_monitoring")).lower() == "true"]

    ctx = {
        "tfvars": tfvars,
        "resources": resources,
        "folders": folders,
        "projects": projects,
        "adopted_projects": adopted,
        "budget_projects": budget_projects,
        "monitoring_targets": monitoring_targets,
        "org_policies": org_policies,
        "log_sinks": log_sinks,
        "alert_defs": alert_defs,
        "notifications": notifications,
        "subnets": subnets,
        "perimeters": perimeters,
        "mgmt_projects": derive_mgmt_projects(tfvars.get("project_id_prefix"), tfvars),
    }

    wb = Workbook()
    wb.remove(wb.active)
    build_cover(wb, meta)
    build_revision(wb, meta)
    build_summary(wb, meta, ctx)
    build_overview(wb, meta, ctx)
    build_folders(wb, ctx)
    build_projects(wb, ctx)
    build_org_policies(wb, ctx)
    build_log_sinks(wb, ctx)
    build_monitoring(wb, ctx)
    build_network(wb, ctx)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"GCP基盤構築_設定明細書_{stamp}.xlsx")
    wb.save(out_path)
    rel = os.path.relpath(out_path, ROOT_DIR)
    print(f"✅ 納品物（構築設定明細書）を生成しました: {rel}")
    print(f"   - 対象組織: {meta['org_domain']}  プロジェクト数: {len(projects)}  フォルダ数: {len(folders)}")
    print("   ℹ️  表紙のメタ情報は環境変数で上書きできます: "
          "DELIVERY_CUSTOMER / DELIVERY_AUTHOR / DELIVERY_VERSION / DELIVERY_DOCNO")


if __name__ == "__main__":
    main()

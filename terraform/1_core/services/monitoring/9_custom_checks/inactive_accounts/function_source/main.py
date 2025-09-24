# inactive_accounts/function_source/main.py

import os
from google.cloud import bigquery
from google.cloud import monitoring_v3
from google.protobuf.timestamp_pb2 import Timestamp

# Terraformから環境変数として渡される値
LOGSINK_PROJECT_ID = os.environ.get('LOGSINK_PROJECT_ID', 'gcp-project-id')
MONITORING_PROJECT_ID = os.environ.get('MONITORING_PROJECT_ID', 'gcp-project-id')

def check_inactive_accounts(event, context):
    """
    BigQueryのViewをクエリし、非アクティブなアカウント数を取得して
    Cloud Monitoringのカスタム指標として書き込む関数。
    Cloud Schedulerによってトリガーされることを想定。
    """
    
    bq_client = bigquery.Client(project=LOGSINK_PROJECT_ID)
    
    # Terraformで作成したViewから非アクティブなアカウント数を取得
    query = f"""
        SELECT COUNT(*) as inactive_count
        FROM `{LOGSINK_PROJECT_ID}.security_analytics.inactive_users_view`
    """
    
    try:
        query_job = bq_client.query(query)
        results = query_job.result()
        
        inactive_count = 0
        # クエリ結果は1行だけ返ってくる
        for row in results:
            inactive_count = row.inactive_count
            break

        print(f"Detected {inactive_count} inactive accounts.")
        
        # 結果をCloud Monitoringのカスタム指標として書き込む
        write_custom_metric(MONITORING_PROJECT_ID, inactive_count)
        
    except Exception as e:
        print(f"An error occurred: {e}")
        # エラーが発生した場合でも、関数を正常終了させることで再試行を防ぐ
        # 必要に応じてエラー通知の仕組みをここに追加する


def write_custom_metric(project_id, value):
    """指定された値をCloud Monitoringのカスタム指標として書き込む"""
    
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/{project_id}"
    
    # 時系列データを作成
    series = monitoring_v3.TimeSeries()
    
    # カスタム指標のタイプ（名前）を定義
    series.metric.type = "custom.googleapis.com/security/inactive_account_count"
    # リソースタイプは「global」を使用
    series.resource.type = "global"
    
    # 現在時刻を取得
    now = Timestamp()
    now.GetCurrentTime()
    
    # 指標の値を設定
    point = monitoring_v3.Point()
    point.value.int64_value = value
    point.interval.end_time = now
    series.points = [point]

    # APIを呼び出して時系列データを書き込む
    client.create_time_series(name=project_name, time_series=[series])
    print(f"Successfully wrote metric with value: {value}")

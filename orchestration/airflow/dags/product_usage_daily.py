"""
Daily product-usage pipeline.

    wait_for_new_jobs  ->  run_dbt_production_job  ->  check_marts_refreshed

1. Wait until the day's recipe jobs have landed in Snowflake (so dbt never
   runs on half-loaded data).
2. Trigger the dbt Cloud production job (source freshness + dbt build:
   all models, snapshots and tests) and wait for it to finish.
3. Check the marts actually received fresh data.

Any failure retries with backoff, then calls alert_on_failure.

Airflow connections needed (Admin -> Connections):
    snowflake_default   Snowflake (DBT_USER / TRANSFORMER / TRANSFORMING_WH)
    dbt_cloud_default   dbt Cloud (account id + API token)
"""

from datetime import datetime, timedelta

from airflow.providers.common.sql.operators.sql import SQLCheckOperator
from airflow.providers.common.sql.sensors.sql import SqlSensor
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator
from airflow.sdk import dag

DBT_PROD_JOB_ID = 12345  # replace with your dbt Cloud production job id
PROD_MARTS_SCHEMA = "product_usage.analytics_marts"  # where the prod job builds marts


def alert_on_failure(context):
    """Called when a task fails after all retries.
    In production this posts to Slack (#data-alerts) with the task, the run date
    and a link to the logs; here it writes the same message to the task log."""
    ti = context["task_instance"]
    print(
        f"ALERT: {ti.dag_id}.{ti.task_id} failed for {context['ds']} "
        f"after {ti.try_number} tries. Logs: {ti.log_url}"
    )


default_args = {
    "owner": "analytics-engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,   # 5, then 10 minutes
    "execution_timeout": timedelta(hours=1),
    "on_failure_callback": alert_on_failure,
}


@dag(
    dag_id="product_usage_daily",
    description="Wait for raw data, run the dbt production job, check the marts.",
    schedule="0 1 * * *",            # 01:00 UTC = 06:30 IST, every day
    start_date=datetime(2026, 11, 1),
    catchup=False,                   # don't backfill missed days automatically
    max_active_runs=1,               # never two runs at once
    default_args=default_args,
    tags=["product-usage", "dbt", "snowflake"],
)
def product_usage_daily():

    # 1. Wait for today's data. "reschedule" frees the worker between checks.
    wait_for_new_jobs = SqlSensor(
        task_id="wait_for_new_jobs",
        conn_id="snowflake_default",
        sql="""
            select count(*)
            from product_usage.raw.recipe_jobs
            where loaded_at >= '{{ ds }}'
        """,
        mode="reschedule",
        poke_interval=10 * 60,       # check every 10 minutes
        timeout=6 * 60 * 60,         # give up after 6 hours and alert
    )

    # 2. Run the dbt Cloud production job and wait for the result.
    run_dbt_production_job = DbtCloudRunJobOperator(
        task_id="run_dbt_production_job",
        dbt_cloud_conn_id="dbt_cloud_default",
        job_id=DBT_PROD_JOB_ID,
        wait_for_termination=True,
        check_interval=60,
        timeout=60 * 60,
        additional_run_config={"cause": "Airflow run for {{ ds }}"},
    )

    # 3. Fail loudly if the daily mart didn't get today's rows.
    check_marts_refreshed = SQLCheckOperator(
        task_id="check_marts_refreshed",
        conn_id="snowflake_default",
        sql=f"""
            select count(*) > 0
            from {PROD_MARTS_SCHEMA}.fct_recipe_jobs
            where loaded_at >= '{{{{ ds }}}}'
        """,
    )

    wait_for_new_jobs >> run_dbt_production_job >> check_marts_refreshed


product_usage_daily()
-- Grain: one row per recipe job run.
--
-- Incremental: each run only processes jobs LOADED recently, not the full history.
-- We filter on loaded_at (when the row arrived), not job_date (when the job ran),
-- so a job that ran days ago but arrived late is still picked up.
-- The lookback window re-reads the last few days to catch rows that land out of order;
-- merge on job_id means re-read rows are updated, never duplicated.

{{ config(
    materialized = 'incremental',
    unique_key = 'job_id',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    cluster_by = ['job_date']
) }}

with jobs as (
    select * from {{ ref('int_recipe_jobs__cleaned') }}

    {% if is_incremental() %}
    where loaded_at > (
        select {{ dbt.dateadd('day', -var('lookback_days', 3), 'max(loaded_at)') }}
        from {{ this }}
    )
    {% endif %}
),

workspaces as (
    select workspace_id, account_id, is_internal
    from {{ ref('dim_workspaces') }}
)

select
    jobs.job_id,
    jobs.recipe_id,
    jobs.workspace_id,
    workspaces.account_id,
    jobs.job_date,
    jobs.job_status,
    jobs.is_success,
    jobs.is_workspace_backfilled,
    workspaces.is_internal,
    jobs.started_at,
    jobs.finished_at,
    jobs.duration_seconds,
    jobs.tasks_used,
    jobs.loaded_at
from jobs   
left join workspaces
    on jobs.workspace_id = workspaces.workspace_id
-- Grain: one row per recipe job run.
-- Built as a table for now; made incremental on Day 4.

with jobs as (
    select * from {{ ref('int_recipe_jobs__cleaned') }}
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
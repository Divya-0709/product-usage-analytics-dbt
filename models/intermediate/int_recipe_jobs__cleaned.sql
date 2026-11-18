-- Fixes two known problems in the job data:
--   1. missing workspace_id: recovered from the recipe the job belongs to
--   2. null job_status: labelled 'unknown' so it is counted, not silently dropped

with jobs as (
    select * from {{ ref('stg_product__recipe_jobs') }}
),

recipes as (
    select recipe_id, workspace_id
    from {{ ref('stg_product__recipes') }}
),

cleaned as (
    select
        jobs.job_id,
        jobs.recipe_id,
        coalesce(jobs.workspace_id, recipes.workspace_id) as workspace_id,
        jobs.workspace_id is null as is_workspace_backfilled,
        coalesce(jobs.job_status, 'unknown') as job_status,
        coalesce(jobs.job_status = 'succeeded', false)as is_success,
        jobs.started_at,
        jobs.finished_at,
        jobs.job_date,
        jobs.duration_seconds,
        jobs.tasks_used,
        jobs.loaded_at
    from jobs
    left join recipes
        on jobs.recipe_id = recipes.recipe_id
)

select * from cleaned
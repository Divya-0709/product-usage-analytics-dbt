with source as (
    select * from {{ source('product', 'recipe_jobs') }}
),

renamed as (
    select
        job_id,
        recipe_id,
        workspace_id,
        lower(status) as job_status,
        started_at,
        finished_at,
        cast(started_at as date) as job_date,
        datediff('second', started_at, finished_at) as duration_seconds,
        tasks_used,
        loaded_at
    from source
)

select * from renamed
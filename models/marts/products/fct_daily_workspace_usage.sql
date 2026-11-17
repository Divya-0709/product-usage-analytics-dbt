-- Grain: one row per customer workspace per day with any activity.
-- Internal (employee) workspaces are excluded here, in one place,
-- so no dashboard has to remember to filter them out.

with jobs as (
    select
        workspace_id,
        job_date as activity_date,
        count(*)                                              as jobs_run,
        sum(case when job_status = 'succeeded' then 1 else 0 end) as successful_jobs,
        sum(case when job_status = 'failed' then 1 else 0 end)    as failed_jobs,
        sum(case when job_status = 'unknown' then 1 else 0 end)   as unknown_status_jobs,
        sum(tasks_used)                                       as tasks_used,
        count(distinct recipe_id)                             as active_recipes
    from {{ ref('fct_recipe_jobs') }}
    group by 1, 2
),

events as (
    select
        workspace_id,
        event_date as activity_date,
        count(distinct user_id)                                               as active_users,
        sum(case when event_name = 'ai_agent_action' then 1 else 0 end)       as ai_agent_actions,
        sum(case when event_name = 'mcp_server_called' then 1 else 0 end)     as mcp_server_calls
    from {{ ref('int_events__deduplicated') }}
    group by 1, 2
),

combined as (
    select
        coalesce(jobs.workspace_id, events.workspace_id)       as workspace_id,
        coalesce(jobs.activity_date, events.activity_date)     as activity_date,
        coalesce(jobs.jobs_run, 0)                             as jobs_run,
        coalesce(jobs.successful_jobs, 0)                      as successful_jobs,
        coalesce(jobs.failed_jobs, 0)                          as failed_jobs,
        coalesce(jobs.unknown_status_jobs, 0)                  as unknown_status_jobs,
        coalesce(jobs.tasks_used, 0)                           as tasks_used,
        coalesce(jobs.active_recipes, 0)                       as active_recipes,
        coalesce(events.active_users, 0)                       as active_users,
        coalesce(events.ai_agent_actions, 0)                   as ai_agent_actions,
        coalesce(events.mcp_server_calls, 0)                   as mcp_server_calls
    from jobs
    full outer join events
        on jobs.workspace_id = events.workspace_id
       and jobs.activity_date = events.activity_date
),

workspaces as (
    select workspace_id, account_id, is_internal
    from {{ ref('dim_workspaces') }}
)

select
    combined.workspace_id || '-' || cast(combined.activity_date as varchar) as workspace_day_id,
    combined.workspace_id,
    workspaces.account_id,
    combined.activity_date,
    combined.jobs_run,
    combined.successful_jobs,
    combined.failed_jobs,
    combined.unknown_status_jobs,
    combined.tasks_used,
    combined.active_recipes,
    combined.active_users,
    combined.ai_agent_actions,
    combined.mcp_server_calls
from combined
inner join workspaces
    on combined.workspace_id = workspaces.workspace_id
where not workspaces.is_internal
{#
    Generic test: flags days whose row count DROPPED sharply compared with
    the average of the days before it. A sudden drop usually means data is
    missing (a failed load, a broken source), which other tests can't see.

    Days with no rows at all count as 0, so a completely missing day is caught too.
    Only the most recent `check_last_days` days are checked.
#}

{% test daily_volume_drop(model, column_name, max_drop_pct=0.5, trailing_days=7, check_last_days=30) %}

with daily as (
    select
        cast({{ column_name }} as date) as activity_date,
        count(*) as row_count
    from {{ model }}
    group by 1
),

bounds as (
    select max(activity_date) as last_date from daily
),

calendar as (
    select date_day as activity_date
    from {{ ref('dim_date') }}, bounds
    where date_day <= bounds.last_date
      and date_day > {{ dbt.dateadd('day', -(check_last_days + trailing_days), 'bounds.last_date') }}
),

filled as (
    select
        calendar.activity_date,
        coalesce(daily.row_count, 0) as row_count
    from calendar
    left join daily on calendar.activity_date = daily.activity_date
),

scored as (
    select
        activity_date,
        row_count,
        avg(row_count) over (
            order by activity_date
            rows between {{ trailing_days }} preceding and 1 preceding
        ) as trailing_avg
    from filled
)

select
    activity_date,
    row_count,
    round(trailing_avg, 0) as trailing_avg,
    round(1 - row_count / trailing_avg, 2) as drop_pct
from scored, bounds
where activity_date > {{ dbt.dateadd('day', -check_last_days, 'bounds.last_date') }}
  and trailing_avg > 0
  and row_count < trailing_avg * (1 - {{ max_drop_pct }})

{% endtest %}
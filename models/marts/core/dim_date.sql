-- One row per calendar day. Used to join facts to calendar attributes
-- and to show days with zero activity.

with days as (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2025-01-01' as date)",
        end_date="cast('2027-01-01' as date)"
    ) }}
)

select
    cast(date_day as date)                              as date_day,
    extract(year from date_day)                         as year_number,
    extract(month from date_day)                        as month_number,
    cast(date_trunc('month', date_day) as date)         as month_start,
    cast(date_trunc('week', date_day) as date)          as week_start,
    cast(date_trunc('quarter', date_day) as date)       as quarter_start,
    dayofweekiso(date_day) in (6, 7)                    as is_weekend
from days
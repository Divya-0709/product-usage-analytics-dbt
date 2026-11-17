-- Removes re-delivered duplicate events.
-- When the same event_id arrives more than once, keep the copy loaded last.

with events as (
    select * from {{ ref('stg_product__events') }}
),

deduplicated as (
    select *
    from events
    qualify row_number() over (
        partition by event_id
        order by loaded_at desc
    ) = 1
)

select * from deduplicated
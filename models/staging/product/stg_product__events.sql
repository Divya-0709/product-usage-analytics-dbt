with source as (
    select * from {{ source('product', 'events') }}
),

renamed as (
    select
        event_id,
        user_id,
        workspace_id,
        event_name,
        event_ts as event_at,
        cast(event_ts as date) as event_date,
        loaded_at
    from source
)

-- duplicate event_ids (re-delivered events) are kept here on purpose.
-- they are removed in the intermediate layer.
select * from renamed
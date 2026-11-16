with source as (
    select * from {{ source('product', 'users') }}
),

renamed as (
    select
        user_id,
        workspace_id,
        role as user_role,
        created_at as created_date,
        is_internal
    from source
)

select * from renamed
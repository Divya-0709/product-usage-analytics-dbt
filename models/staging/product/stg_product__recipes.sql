with source as (
    select * from {{ source('product', 'recipes') }}
),

renamed as (
    select
        recipe_id,
        workspace_id,
        created_by_user_id,
        trigger_type,
        created_at as created_date,
        is_active
    from source
)

select * from renamed
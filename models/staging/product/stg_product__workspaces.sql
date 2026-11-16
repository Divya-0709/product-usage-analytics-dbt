with source as (
    select * from {{ source('product', 'workspaces') }}
),

renamed as (
    select
        workspace_id,
        account_id,
        environment,
        created_at as created_date,
        is_internal
    from source
)

select * from renamed
with source as (
    select * from {{ source('product', 'accounts') }}
),

renamed as (
    select
        account_id,
        account_name,
        segment,
        region,
        created_at as created_date
    from source
)

select * from renamed
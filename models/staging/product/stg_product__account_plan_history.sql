with source as (
    select * from {{ source('product', 'account_plan_history') }}
),

renamed as (
    select
        account_id,
        plan as plan_name,
        mrr,
        valid_from,
        valid_to,
        valid_to is null as is_current_plan
    from source
)

select * from renamed
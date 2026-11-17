-- One row per customer account, with its current plan.
-- An account whose latest plan period has ended is treated as churned.

with accounts as (
    select * from {{ ref('stg_product__accounts') }}
),

latest_plan as (
    select *
    from {{ ref('stg_product__account_plan_history') }}
    qualify row_number() over (partition by account_id order by valid_from desc) = 1
),

final as (
    select
        accounts.account_id,
        accounts.account_name,
        accounts.segment,
        accounts.region,
        accounts.created_date,
        case when latest_plan.is_current_plan then latest_plan.plan_name else 'Churned' end as current_plan,
        case when latest_plan.is_current_plan then latest_plan.mrr else 0 end              as current_mrr,
        not coalesce(latest_plan.is_current_plan, false)                                   as is_churned,
        case when latest_plan.is_current_plan then null else latest_plan.valid_to end      as churned_date
    from accounts
    left join latest_plan
        on accounts.account_id = latest_plan.account_id
)

select * from final
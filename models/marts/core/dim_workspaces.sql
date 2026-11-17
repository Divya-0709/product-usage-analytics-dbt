-- One row per workspace, with the account attributes analysts filter by most.

with workspaces as (
    select * from {{ ref('stg_product__workspaces') }}
),

accounts as (
    select account_id, segment, region, current_plan, is_churned
    from {{ ref('dim_accounts') }}
)

select
    workspaces.workspace_id,
    workspaces.account_id,
    workspaces.environment,
    workspaces.created_date,
    workspaces.is_internal,
    accounts.segment,
    accounts.region,
    accounts.current_plan,
    accounts.is_churned as is_account_churned
from workspaces
left join accounts
    on workspaces.account_id = accounts.account_id
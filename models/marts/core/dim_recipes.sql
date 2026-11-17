-- One row per recipe, with how many distinct connectors it uses.

with recipes as (
    select * from {{ ref('stg_product__recipes') }}
),

connector_counts as (
    select recipe_id, count(*) as connector_count
    from {{ ref('int_recipe_connectors__deduplicated') }}
    group by recipe_id
)

select
    recipes.recipe_id,
    recipes.workspace_id,
    recipes.created_by_user_id,
    recipes.trigger_type,
    recipes.created_date,
    recipes.is_active,
    coalesce(connector_counts.connector_count, 0) as connector_count
from recipes
left join connector_counts
    on recipes.recipe_id = connector_counts.recipe_id
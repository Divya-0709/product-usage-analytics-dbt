-- One row per recipe and connector. Removes connectors listed twice in the same recipe.

with recipe_connectors as (
    select * from {{ ref('stg_product__recipe_connectors') }}
),

deduplicated as (
    select distinct
        recipe_id,
        connector_name
    from recipe_connectors
)

select
    recipe_id || '-' || connector_name as recipe_connector_id,
    recipe_id,
    connector_name
from deduplicated
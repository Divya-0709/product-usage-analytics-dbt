with source as (
    select * from {{ source('product', 'recipe_connectors') }}
),

renamed as (
    select
        recipe_id,
        lower(trim(connector)) as connector_name
    from source
)

-- duplicates are kept here on purpose: staging stays 1:1 with the source.
-- they are removed in the intermediate layer.
select * from renamed
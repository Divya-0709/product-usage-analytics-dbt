{#
    Drops every schema whose name starts with `prefix`.
    Used by CI to clean up the temporary schemas built for a pull request,
    so test builds never pile up in the warehouse.

    Usage:  dbt run-operation drop_ci_schemas --args '{prefix: ci_pr_12}'
#}

{% macro drop_ci_schemas(prefix) %}

    {% if not prefix.lower().startswith('ci_') %}
        {{ exceptions.raise_compiler_error("Refusing to drop schemas that don't start with ci_: " ~ prefix) }}
    {% endif %}

    {# Snowflake's list_schemas returns several columns (created_on, name, ...);
       other warehouses return just the schema name. Pick the right one. #}
    {% set result = list_schemas(target.database) %}
    {% set lower_names = result.column_names | map('lower') | list %}
    {% if 'name' in lower_names %}
        {% set name_column = result.column_names[lower_names.index('name')] %}
    {% else %}
        {% set name_column = result.column_names[0] %}
    {% endif %}
    {% set all_schemas = result.columns[name_column].values() %}

    {% for schema in all_schemas %}
        {# exact prefix match: ci_pr_1 must not also drop ci_pr_12's schemas #}
        {% if schema.lower() == prefix.lower() or schema.lower().startswith(prefix.lower() ~ '_') %}
            {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=schema)) %}
            {{ log('Dropped schema ' ~ schema, info=true) }}
        {% endif %}
    {% endfor %}

{% endmacro %}
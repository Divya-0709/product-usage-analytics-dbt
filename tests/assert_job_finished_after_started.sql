-- A job cannot finish before it starts. Any row returned here is a data error.
select job_id, started_at, finished_at
from {{ ref('fct_recipe_jobs') }}
where finished_at < started_at
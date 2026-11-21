{# Reusable descriptions. Write a definition once here, then use it in any
   YAML file with {{ doc('name') }}, so the same column means the same thing everywhere. #}

{% docs account_id %}
Customer account identifier, e.g. `A0042`. One account can own several workspaces.
{% enddocs %}

{% docs workspace_id %}
Workspace identifier, e.g. `W00017`. A workspace belongs to exactly one account and is where recipes run.
{% enddocs %}

{% docs recipe_id %}
Recipe identifier, e.g. `R000123`. A recipe is an automated workflow that connects one or more apps.
{% enddocs %}

{% docs is_internal %}
`true` for workspaces used by our own employees (testing, demos).
These are **excluded from every customer metric**. `fct_daily_workspace_usage` already filters them out;
anything built on `fct_recipe_jobs` must filter `where not is_internal`.
{% enddocs %}

{% docs job_status %}
Outcome of a recipe run: `succeeded` (ran to completion), `failed` (ran and failed), or `unknown`
(status missing at source: still running, or lost). `unknown` runs are counted, never treated as a success.
{% enddocs %}

{% docs tasks_used %}
Number of tasks the run consumed. **Tasks are the billing unit**, so this column drives usage-based revenue.
{% enddocs %}

{% docs loaded_at %}
When the row landed in the warehouse (not when the job ran). Incremental models filter on this,
so late-arriving rows are still picked up.
{% enddocs %}

{% docs fct_daily_workspace_usage %}
**Grain: one row per customer workspace per day with any activity.**

The default source for usage dashboards: about 43,000 rows instead of 150,000 jobs plus 78,000 events,
so dashboards are faster and cheaper. Internal workspaces are excluded.
Days with no activity for a workspace have no row; join to `dim_date` to show zero days.
{% enddocs %}
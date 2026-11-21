# Data dictionary

Generated from dbt metadata by `scripts/generate_data_dictionary.py`. Don't edit by hand:
change the descriptions in the model YAML files and re-run the script.

| Model | Materialization | Description |
| --- | --- | --- |
| [`fct_daily_workspace_usage`](#fct_daily_workspace_usage) | table | **Grain: one row per customer workspace per day with any activity.** The default source for usage dashboards: about 43,000 rows instead of 150,000 jobs plus 78,000 events, so dashboards are faster and cheaper. Internal workspaces are excluded. Days with no activity for a workspace have no row; join to `dim_date` to show zero days. |
| [`fct_recipe_jobs`](#fct_recipe_jobs) | incremental | Recipe runs. Grain: one row per recipe job run, about 150,000 rows. Includes internal workspaces, flagged with is_internal. Incremental (merge on job_id, filtered on loaded_at with a 3-day lookback). |
| [`dim_accounts`](#dim_accounts) | table | Customer accounts. Grain: one row per account, with its current plan. An account is churned when its latest plan period has ended. Plan history over time lives in the subscriptions_snapshot (SCD Type 2). |
| [`dim_date`](#dim_date) | table | Calendar dimension. Grain: one row per day, 2025-01-01 to 2026-12-31. Join facts to it to group by week, month or quarter, or to show days with no activity. |
| [`dim_recipes`](#dim_recipes) | table | Recipes. Grain: one row per recipe, with how many distinct connectors it uses. |
| [`dim_workspaces`](#dim_workspaces) | table | Workspaces. Grain: one row per workspace, with the account attributes analysts filter by most (segment, region, plan), so they don't need an extra join. |

## fct_daily_workspace_usage

**Grain: one row per customer workspace per day with any activity.** The default source for usage dashboards: about 43,000 rows instead of 150,000 jobs plus 78,000 events, so dashboards are faster and cheaper. Internal workspaces are excluded. Days with no activity for a workspace have no row; join to `dim_date` to show zero days.

Materialization: `table` · Owner: `analytics-engineering`

| Column | Description | Tests |
| --- | --- | --- |
| `workspace_day_id` | Primary key (workspace_id + activity_date). | not_null, unique |
| `workspace_id` | Workspace identifier, e.g. `W00017`. A workspace belongs to exactly one account and is where recipes run. | relationships |
| `account_id` | Customer account identifier, e.g. `A0042`. One account can own several workspaces. |  |
| `activity_date` | The day the activity happened. |  |
| `jobs_run` | All recipe runs that day, whatever their status. |  |
| `successful_jobs` | Runs that succeeded. |  |
| `failed_jobs` | Runs that failed. |  |
| `unknown_status_jobs` | Runs with no status at source. |  |
| `tasks_used` | Number of tasks the run consumed. **Tasks are the billing unit**, so this column drives usage-based revenue. |  |
| `active_recipes` | Distinct recipes that ran at least once that day. |  |
| `active_users` | Distinct users with at least one product event that day. |  |
| `ai_agent_actions` | Number of AI agent actions (event `ai_agent_action`). |  |
| `mcp_server_calls` | Number of MCP server calls (event `mcp_server_called`). |  |

## fct_recipe_jobs

Recipe runs. Grain: one row per recipe job run, about 150,000 rows. Includes internal workspaces, flagged with is_internal. Incremental (merge on job_id, filtered on loaded_at with a 3-day lookback).

Materialization: `incremental` · Owner: `analytics-engineering`

| Column | Description | Tests |
| --- | --- | --- |
| `job_id` | Recipe run identifier. Primary key. | not_null, unique |
| `recipe_id` | Recipe identifier, e.g. `R000123`. A recipe is an automated workflow that connects one or more apps. | relationships |
| `workspace_id` | Workspace identifier, e.g. `W00017`. A workspace belongs to exactly one account and is where recipes run. Recovered from the recipe when missing at source. | not_null, relationships |
| `account_id` | Customer account identifier, e.g. `A0042`. One account can own several workspaces. |  |
| `job_date` | Date the job started. | daily_volume_drop, relationships |
| `job_status` | Outcome of a recipe run: `succeeded` (ran to completion), `failed` (ran and failed), or `unknown` (status missing at source: still running, or lost). `unknown` runs are counted, never treated as a success. |  |
| `is_success` | `true` only when job_status is `succeeded`. Never null. |  |
| `is_workspace_backfilled` | `true` when workspace_id was missing at source and recovered from the recipe. |  |
| `is_internal` | `true` for workspaces used by our own employees (testing, demos). These are **excluded from every customer metric**. `fct_daily_workspace_usage` already filters them out; anything built on `fct_recipe_jobs` must filter `where not is_internal`. |  |
| `started_at` | When the run started. |  |
| `finished_at` | When the run finished. Null if still running or lost. |  |
| `duration_seconds` | Run time in seconds (finished_at minus started_at). |  |
| `tasks_used` | Number of tasks the run consumed. **Tasks are the billing unit**, so this column drives usage-based revenue. |  |
| `loaded_at` | When the row landed in the warehouse (not when the job ran). Incremental models filter on this, so late-arriving rows are still picked up. |  |

## dim_accounts

Customer accounts. Grain: one row per account, with its current plan. An account is churned when its latest plan period has ended. Plan history over time lives in the subscriptions_snapshot (SCD Type 2).

Materialization: `table` · Owner: `analytics-engineering` · Contract: **enforced**

| Column | Description | Tests |
| --- | --- | --- |
| `account_id` `varchar` | Customer account identifier, e.g. `A0042`. One account can own several workspaces. Primary key. | not_null, relationships, unique |
| `account_name` `varchar` | Customer's account name. |  |
| `segment` `varchar` | Customer size segment: SMB, Mid-Market or Enterprise. |  |
| `region` `varchar` | Customer's region: US, EU or APAC. |  |
| `created_date` `date` | Date the account was created. |  |
| `current_plan` `varchar` | Plan the account is on today. `Churned` when the latest plan period has ended. | accepted_values |
| `current_mrr` `int` | Monthly recurring revenue on the current plan. 0 when churned. | not_null |
| `is_churned` `boolean` | `true` when the account has no active plan. |  |
| `churned_date` `date` | Date the last plan period ended. Null for active accounts. |  |

## dim_date

Calendar dimension. Grain: one row per day, 2025-01-01 to 2026-12-31. Join facts to it to group by week, month or quarter, or to show days with no activity.

Materialization: `table`

| Column | Description | Tests |
| --- | --- | --- |
| `date_day` | The calendar date. Primary key. | not_null, unique |
| `year_number` | Calendar year, e.g. 2026. |  |
| `month_number` | Month of the year, 1 to 12. |  |
| `month_start` | First day of the month. Group by this for monthly reporting. |  |
| `week_start` | First day of the week (Monday). Group by this for weekly reporting. |  |
| `quarter_start` | First day of the calendar quarter. |  |
| `is_weekend` | `true` on Saturday and Sunday. |  |

## dim_recipes

Recipes. Grain: one row per recipe, with how many distinct connectors it uses.

Materialization: `table`

| Column | Description | Tests |
| --- | --- | --- |
| `recipe_id` | Recipe identifier, e.g. `R000123`. A recipe is an automated workflow that connects one or more apps. Primary key. | not_null, relationships, unique |
| `workspace_id` | Workspace identifier, e.g. `W00017`. A workspace belongs to exactly one account and is where recipes run. |  |
| `created_by_user_id` | User who built the recipe. |  |
| `trigger_type` | What starts the recipe: `scheduled`, `webhook`, `polling` or `api`. |  |
| `created_date` | Date the recipe was created. |  |
| `is_active` | `true` when the recipe is switched on and can run. |  |
| `connector_count` | Number of distinct connectors (apps) the recipe uses, after removing duplicates. 0 if none. | not_null |

## dim_workspaces

Workspaces. Grain: one row per workspace, with the account attributes analysts filter by most (segment, region, plan), so they don't need an extra join.

Materialization: `table`

| Column | Description | Tests |
| --- | --- | --- |
| `workspace_id` | Workspace identifier, e.g. `W00017`. A workspace belongs to exactly one account and is where recipes run. Primary key. | not_null, relationships, unique |
| `account_id` | Customer account identifier, e.g. `A0042`. One account can own several workspaces. | relationships |
| `environment` | `prod` or `test`: the customer's own label for the workspace. |  |
| `created_date` | Date the workspace was created. |  |
| `is_internal` | `true` for workspaces used by our own employees (testing, demos). These are **excluded from every customer metric**. `fct_daily_workspace_usage` already filters them out; anything built on `fct_recipe_jobs` must filter `where not is_internal`. |  |
| `segment` | Segment of the owning account. |  |
| `region` | Region of the owning account. |  |
| `current_plan` | Current plan of the owning account. |  |
| `is_account_churned` | `true` when the owning account has churned. |  |
# Description optimization

Use this procedure for trigger evaluation or description tuning. It requires an authenticated `claude` CLI; otherwise, offer a manual description review and state that trigger behavior was not measured.

## 1. Draft the trigger set

Create 20 realistic queries: 10 that should invoke the skill and 10 near-misses that should not. Save a JSON array:

```json
[
  {"query": "A concrete request that needs the skill", "should_trigger": true},
  {"query": "A related request that needs something else", "should_trigger": false}
]
```

Cover distinct trigger branches, implicit requests, competing skills, and varied phrasing. Include enough context to require the workflow; trivial one-step tasks may be handled directly even when the description matches. Negative queries should test boundaries, not unrelated subjects.

Proceed when every intended trigger branch and its closest exclusion have coverage.

## 2. Get user review

Read `assets/eval_review.html` from the skill-creator directory. Replace its eval-data, skill-name, and skill-description placeholders with the proposed set and current metadata. Write the rendered HTML to a temporary file and open it or provide its path.

Ask the user to review the queries and labels, then export the set. Locate their latest exported `eval_set.json` and save the approved copy in the workspace. If HTML review is unavailable, get approval in the conversation.

## 3. Run optimization

Choose an explicit model supported by the Claude CLI, matching the deployment being evaluated where possible. State any model mismatch that limits the comparison.

From the skill-creator directory, run in the background:

```bash
python -m scripts.run_loop \
  --eval-set <approved-trigger-set.json> \
  --skill-path <target-skill-path> \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

Tell the user this may take time. Check progress periodically and report iteration scores. The script separates training and held-out queries, repeats trigger checks, and selects `best_description` using held-out performance. Inspect its report and results before applying the selection.

## 4. Apply and report

Update the target skill's frontmatter with `best_description`. Show the before/after text and measured scores, including held-out performance. Preserve the approved trigger set and results in the workspace.

# Evaluation

Use this procedure for skill test runs, baseline comparisons, and human output review. Keep results in `<skill-name>-workspace/`, beside the target skill, outside its distributable directory. Create iteration and case directories as needed.

Read [Schemas](schemas.md) when writing evaluation or result JSON. Use `expectations` for assertions in `evals/evals.json`; case metadata uses `assertions`.

## 1. Prepare paired runs

Use this layout, including `run-1` so the aggregation script discovers the results:

```text
<skill-name>-workspace/
├── skill-snapshot/                 # existing skill before revision
└── iteration-1/
    └── eval-1-descriptive-case-name/
        ├── eval_metadata.json
        ├── with_skill/
        │   └── run-1/
        │       ├── eval_metadata.json
        │       ├── transcript.md
        │       └── outputs/
        └── without_skill/
            └── run-1/
                ├── eval_metadata.json
                ├── transcript.md
                └── outputs/
```

For each case, write metadata with its ID, descriptive name, full prompt, and an initially empty `assertions` list. Copy it into each run directory so the viewer can resolve the prompt.

Use `with_skill` for the current draft and `without_skill` for the baseline:

- **New skill:** baseline gets no skill.
- **Existing skill:** baseline gets the pre-edit snapshot. Record which version it represents; on later iterations, deliberately choose the original or previous revision.

Launch both configurations for every case in the same turn. Give each executor:

- The identical task prompt and input files, resolving relative inputs against the target skill directory.
- Its skill path, or an explicit instruction to run without a skill.
- Its run directory and the exact deliverables to save in `outputs/`.
- An instruction to save the execution transcript as `transcript.md` beside `outputs/`.

Keep executors isolated from one another's outputs. Use repeated runs when measuring variance; number them `run-1`, `run-2`, and so on.

**Without subagents:** execute the with-skill cases sequentially. Omit baselines and comparative benchmarks, disclose that the author also executed the tests, and use human review to assess quality.

## 2. Define assertions while runs execute

Draft objective checks of meaningful outcomes, using descriptive wording. Use executable checks where possible. Leave subjective quality to human review rather than forcing a numerical assertion.

Review existing assertions instead of replacing them automatically. Update both `evals/evals.json` (`expectations`) and every applicable metadata file (`assertions`). Explain to the user what these checks measure and what still needs their judgment.

This step is complete when each objective success criterion has a check and subjective criteria are identified for review.

## 3. Capture completion data

As each executor completes, save available token and duration data to its `timing.json`, beside `outputs/`. Capture notification-only metrics immediately; report unavailable metrics rather than inventing values. See [Schemas](schemas.md#timingjson) for the fields.

Proceed when every run has its deliverables and transcript, and available timing data is saved.

## 4. Grade and aggregate

Read [Grader](../agents/grader.md), then grade each run inline or with a grader agent. Supply assertions, transcript path, and output directory. Run programmatic checks for objectively testable assertions.

Save `grading.json` in each run directory. Its `expectations` entries require `text`, `passed`, and `evidence`; include the `summary` counts and pass rate for aggregation. Follow [Schemas](schemas.md#gradingjson).

For paired runs, aggregate from the skill-creator directory:

```bash
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
```

This writes `benchmark.json` and `benchmark.md`. Verify that all expected runs were included and the comparison is current skill minus baseline. When assembling benchmark JSON manually, follow [Schemas](schemas.md#benchmarkjson) and list `with_skill` before `without_skill`.

Read the “Analyzing Benchmark Results” section of [Analyzer](../agents/analyzer.md). Record non-discriminating assertions, inconsistent runs, and quality/time/token tradeoffs that the averages hide.

## 5. Present results for human review

Generate the supplied viewer before making another revision:

```bash
python <skill-creator-path>/eval-viewer/generate_review.py \
  <workspace>/iteration-N \
  --skill-name <name> \
  --benchmark <workspace>/iteration-N/benchmark.json
```

- On iteration 2+, add `--previous-workspace <workspace>/iteration-<N-1>`.
- Without a benchmark, omit `--benchmark`.
- Without a display or browser, add `--static <output-path>` and give the user the HTML file.
- For a live server, run it in the background and retain its PID for cleanup.

Tell the user that **Outputs** contains deliverables and feedback fields, and **Benchmark** contains the quantitative comparison when available. Ask them to review and return when finished.

If the viewer cannot run, present each prompt and output in the conversation, link generated files, and request feedback inline. Disclose the fallback.

## 6. Collect feedback

Read the iteration's `feedback.json` after the user finishes. For a static viewer, copy the downloaded file into the iteration directory. Feedback entries identify runs by `run_id` and contain a `feedback` string; an empty string means no requested change.

Stop any live viewer server after review. Return to the main skill's revision step with the user's feedback, grades, and analyst observations. Preserve prior iterations for comparison.

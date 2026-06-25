export const meta = {
  name: 'write-plan',
  description: 'Plan-authoring pipeline: scout repo into a context pack, author the plan directory from the approved spec, then run the review workflow for a structured verdict. Patching is left to the skill coordinator.',
  phases: [
    { title: 'Scout', detail: 'Explore spec + repo and write context-pack.md' },
    { title: 'Author', detail: 'Write the plan directory (overview, task files, status.json)' },
    { title: 'Review', detail: 'Run the review workflow and capture its verdict' },
  ],
};

// NOTE: Claude Code **Workflow-tool script** — run via the Workflow tool. The runtime wraps
// everything below `meta` in an async function, so top-level `await` and the final top-level
// `return` are INTENTIONAL. Do NOT wrap the body in a function or "fix" the return — that breaks
// the runtime. `node --check` reporting "Illegal return" is EXPECTED; validate by launching with
// the Workflow tool. Path args are provided by the trusted orchestrator (the invoking skill).
const specPath = args.specPath;
const planDir = args.planDir;
const repoRoot = args.repoRoot;
const reviewWorkflowPath = args.reviewWorkflowPath;
const reviewMode = args.mode || 'full';
const templatesPath = args.templatesPath; // writing-plans SKILL.md — holds the overview/task/status/context-pack templates
const decisionPackPath = args.decisionPackPath; // optional: decision pack OR phase handoff artifact (authoritative input, if present)
const constraints = args.constraints;           // optional: explicit human constraints, as text (authoritative input, if present)
const contextPackPath = `${planDir}/context-pack.md`;

// Optional authoritative inputs beyond the spec — mirror the writing-plans "Source of Truth"
// (decision pack / phase handoff; explicit human constraints). The manual fallback feeds these to
// the scout AND the author; the workflow must too, or the default (Workflow) path is weaker than the
// fallback and silently drops required constraints that decision-pack/handoff-driven sessions rely on.
const authInputLines = [];
if (decisionPackPath) {
  authInputLines.push(
    'Also read the decision pack / phase handoff at: ' + decisionPackPath + ' — it is an authoritative input alongside the spec; honor its decisions and any constraints it records.',
  );
}
if (constraints) {
  authInputLines.push(
    'Explicit human constraints (authoritative — must be reflected in your output):',
    constraints,
  );
}

  // Phase 1: Scout — one read-only subagent builds the context pack.
  phase('Scout');
  log(`Scouting spec ${specPath} against repo ${repoRoot}`);
  const SCOUT_SCHEMA = {
    type: 'object',
    additionalProperties: false,
    required: ['wrote', 'summary'],
    properties: {
      wrote: { type: 'boolean' },
      summary: { type: 'string' },
    },
  };
  const scoutResult = await agent(
    [
      'You are building a context pack for implementation planning.',
      'Do not write a plan. Do not modify repository code. Do not use chat history.',
      `Read the approved spec at: ${specPath}`,
      ...authInputLines,
      `Inspect the repository rooted at: ${repoRoot} — read-only for repository code (you may run git diff; do NOT commit or modify any repo source/config/test file).`,
      'Identify: relevant files and responsibilities, existing patterns, test commands, constraints, risks, and open questions.',
      `Writing the context pack is your REQUIRED output and is explicitly allowed (it is not "modifying the repo"). Write it to: ${contextPackPath}; follow the Context Pack template defined in the writing-plans skill at: ${templatesPath} (read it for the exact required shape — do not guess). The plan directory ${planDir} may not exist yet (a fresh plan target is normal) — creating it (e.g. mkdir -p) as part of writing the context pack is explicitly allowed and REQUIRED. A missing plan directory is NOT a failure: create it. You MUST create the context pack file before returning.`,
      'Return { wrote: true ONLY IF you actually created the context pack file at the path above; summary: one line }. Return wrote: false ONLY for a genuine write failure (e.g. permission denied) — NOT merely because the plan directory did not exist (you are required to create it).',
    ].join('\n'),
    { label: 'context-scout', phase: 'Scout', schema: SCOUT_SCHEMA },
  );

  // Gate: never author a plan from a missing context pack. If the scout did not actually write it
  // (skipped, failed, or self-reported wrote:false), stop BEFORE the Author phase.
  if (!scoutResult || scoutResult.wrote !== true) {
    const reason = scoutResult ? scoutResult.summary : 'scout subagent returned no result';
    log('write-plan: context pack not created by Scout — stopping before Author (' + reason + ')');
    return {
      planDir: planDir,
      review: {
        verdict: 'blocked',
        blocking: [{ severity: 'blocking', file: contextPackPath, problem: 'Context pack was not created by the Scout phase (' + reason + '). Plan was NOT authored — create the context pack / re-run before proceeding.' }],
        important: [],
        minor: [],
      },
    };
  }
  const scoutReceipt = scoutResult.summary;

  // Phase 2: Author — one subagent writes the full plan directory from sterile inputs.
  phase('Author');
  log(`Authoring plan directory at ${planDir}`);
  const authorResult = await agent(
    [
      'You are writing an implementation plan from saved artifacts.',
      'Do not use chat history. Do not implement code.',
      `You may read files and run git diff in ${repoRoot} to verify paths, symbols, and tests; do not commit or modify anything outside the plan directory.`,
      `Approved spec: ${specPath}`,
      `Context pack: ${contextPackPath}`,
      ...authInputLines,
      `Read the plan templates (overview/task/status) from the writing-plans skill at: ${templatesPath} and conform to them exactly — do not guess the structure.`,
      `Write the plan directory at: ${planDir}`,
      'Produce overview.md, task-NNN-<name>.md files, and status.json following those templates.',
      'Prefer TDD task order. Mark risk tier and review policy per task. Include concrete verification steps.',
      'If something is unknown, add an open question instead of guessing.',
      'Return { wrote: true ONLY IF you actually wrote the plan directory (overview.md + task files + status.json); summary: one line }. If you could not, return wrote: false with the reason.',
    ].join('\n'),
    { label: 'plan-author', phase: 'Author', schema: SCOUT_SCHEMA },
  );

  // Gate: never review a plan the Author did not actually write — otherwise Review could validate and
  // approve stale files already present in planDir from an earlier run.
  if (!authorResult || authorResult.wrote !== true) {
    const areason = authorResult ? authorResult.summary : 'author subagent returned no result';
    log('write-plan: plan not authored — stopping before Review (' + areason + ')');
    return {
      planDir: planDir,
      review: {
        verdict: 'blocked',
        blocking: [{ severity: 'blocking', file: planDir, problem: 'Plan directory was not authored by the Author phase (' + areason + '). Not reviewed — re-run before proceeding.' }],
        important: [],
        minor: [],
      },
    };
  }
  const authorReceipt = authorResult.summary;

  // Phase 3: Review — reuse the shipped review workflow (one level of nesting; allowed at top level).
  phase('Review');
  log(`Reviewing plan via ${reviewWorkflowPath}`);
  const review = await workflow(
    { scriptPath: reviewWorkflowPath },
    {
      planDir: planDir,
      specPath: specPath,
      contextPackPath: contextPackPath,
      repoRoot: repoRoot,
      mode: reviewMode,
    },
  );

  log(`Scout: ${scoutReceipt}`);
  log(`Author: ${authorReceipt}`);

  return { planDir: planDir, review: review };

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
const contextPackPath = `${planDir}/context-pack.md`;

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
      `Inspect the repository rooted at: ${repoRoot} — read-only for repository code (you may run git diff; do NOT commit or modify any repo source/config/test file).`,
      'Identify: relevant files and responsibilities, existing patterns, test commands, constraints, risks, and open questions.',
      `Writing the context pack is your REQUIRED output and is explicitly allowed (it is not "modifying the repo"). Write it to: ${contextPackPath}; follow the Context Pack template defined in the writing-plans skill at: ${templatesPath} (read it for the exact required shape — do not guess). You MUST create this file before returning.`,
      'Return { wrote: true ONLY IF you actually created the context pack file at the path above; summary: one line }. If you could not create it (e.g. directory missing, write denied), return wrote: false with the reason in summary.',
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
  const authorReceipt = await agent(
    [
      'You are writing an implementation plan from saved artifacts.',
      'Do not use chat history. Do not implement code.',
      `You may read files and run git diff in ${repoRoot} to verify paths, symbols, and tests; do not commit or modify anything outside the plan directory.`,
      `Approved spec: ${specPath}`,
      `Context pack: ${contextPackPath}`,
      `Read the plan templates (overview/task/status) from the writing-plans skill at: ${templatesPath} and conform to them exactly — do not guess the structure.`,
      `Write the plan directory at: ${planDir}`,
      'Produce overview.md, task-NNN-<name>.md files, and status.json following those templates.',
      'Prefer TDD task order. Mark risk tier and review policy per task. Include concrete verification steps.',
      'If something is unknown, add an open question instead of guessing.',
      'Return ONLY a short receipt: the plan directory path, the task files created, and a one-line summary.',
    ].join('\n'),
    { label: 'plan-author', phase: 'Author' },
  );

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

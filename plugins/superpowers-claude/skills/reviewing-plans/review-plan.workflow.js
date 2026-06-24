export const meta = {
  name: 'review-plan',
  description: 'Parameterized pre-execution plan review: fan-out reviewers over spec-coverage/correctness/snippet/risk/security, then adversarially verify each finding and emit a structured verdict.',
  phases: [
    { title: 'Review', detail: 'Parallel read-only reviewers produce findings across the selected dimensions for the given mode.' },
    { title: 'Verify', detail: 'One adversarial verifier per finding; REFUTED findings are dropped, then the verdict is computed.' }
  ]
};

// NOTE: Claude Code **Workflow-tool script** — run via the Workflow tool
// (Workflow({ scriptPath: ".../review-plan.workflow.js", args: {...} })). The runtime
// wraps everything below `meta` in an async function, so top-level `await` and the final
// top-level `return` are INTENTIONAL and required. Do NOT wrap the body in a function and
// do NOT "fix" the top-level return — that breaks the Workflow runtime (the file must begin
// with the literal `export const meta`, followed by a bare async body). `node --check` will
// report "Illegal return statement" — that is EXPECTED; validate by LAUNCHING the script
// with the Workflow tool, not with node. Path args are provided by the trusted orchestrator
// (the invoking skill), not external/untrusted input.

// ---- inputs (from global args) ----
const planDir = args.planDir;
const specPath = args.specPath;
const contextPackPath = args.contextPackPath;
const repoRoot = args.repoRoot;
const mode = args.mode || 'full';

// Reviewer set depends on mode. 'full' = all dimensions; reduced sets otherwise.
const REVIEWER_SETS = {
  light: ['spec-coverage', 'plan-correctness'],
  targeted: ['spec-coverage', 'plan-correctness', 'snippet'],
  full: ['spec-coverage', 'plan-correctness', 'snippet', 'risk', 'security']
};

const DIMENSIONS = {
  'spec-coverage': 'Map every spec requirement to at least one plan task and a verification step. Flag requirements with no task, behavior changes with no verification, and unrequested scope added without approval.',
  'plan-correctness': 'Check file paths, task order, dependencies, commands, and stale references. Flag files/symbols that are referenced but do not exist, files used before they are created, non-concrete or unrunnable commands, and task order that violates dependencies.',
  'snippet': 'Validate code snippets against the real repo: imports, symbol names, function signatures, and test references. Flag snippets that reference non-existent symbols or contradict the actual repository.',
  'risk': 'Check high-risk changes: migrations, data loss, concurrency, public API changes, rollback, and observability. Flag risky changes missing compatibility, rollback, or failure-mode handling.',
  'security': 'Check for security-relevant gaps: authn/authz, input validation, secrets handling, injection, and unsafe external calls introduced or left unaddressed by the plan.'
};

const FINDING_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['blocking', 'important', 'minor'] },
          file: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'string' }
        },
        required: ['severity', 'file', 'problem', 'evidence']
      }
    }
  },
  required: ['findings']
};

const VERIFY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['CONFIRMED', 'PLAUSIBLE', 'REFUTED'] },
    severity: { type: 'string', enum: ['blocking', 'important', 'minor'] },
    file: { type: 'string' },
    problem: { type: 'string' },
    evidence: { type: 'string' },
    reasoning: { type: 'string' }
  },
  required: ['verdict', 'severity', 'file', 'problem', 'evidence', 'reasoning']
};

function reviewerPrompt(dimension) {
  return [
    'You are reviewing an implementation plan, not implementing code.',
    'Do not modify files. Do not commit. Read-only.',
    'Do not use chat history.',
    '',
    'Repo context:',
    '- repo root: ' + repoRoot,
    'Inputs (read these real files):',
    '- approved spec: ' + specPath,
    '- context pack: ' + contextPackPath,
    '- plan directory: ' + planDir,
    'Review mode: ' + mode,
    '',
    'SCOPE — review ONLY the plan in the plan directory above (its overview.md and task files)',
    'against the approved spec. Do NOT open, review, or report on any OTHER plan or directory',
    '(e.g. other docs/plans/* or docs/superpowers/plans/* entries). Every finding MUST concern',
    'THIS plan or a repo file THIS plan references. Ignore unrelated plans entirely.',
    '',
    'Your dimension: ' + dimension,
    DIMENSIONS[dimension],
    '',
    'Read this plan, the spec, the context pack, and the repo files THIS plan references to validate claims.',
    'Return findings as an array. Each finding: severity (blocking|important|minor),',
    'file (the plan task file or repo file the problem is in), problem (one sentence),',
    'evidence (concrete file path + plan task reference or repo line that proves it).',
    'If you find no issues for this dimension, return an empty findings array.'
  ].join('\n');
}

function verifyPrompt(finding) {
  return [
    'You are an adversarial verifier. A plan reviewer reported the finding below.',
    'Your job is to try to REFUTE it by checking the real artifacts. Read-only.',
    'Do not use chat history.',
    '',
    'Repo context:',
    '- repo root: ' + repoRoot,
    'Inputs (read these real files):',
    '- approved spec: ' + specPath,
    '- context pack: ' + contextPackPath,
    '- plan directory: ' + planDir,
    '',
    'Reported finding:',
    '- severity: ' + finding.severity,
    '- file: ' + finding.file,
    '- problem: ' + finding.problem,
    '- evidence: ' + finding.evidence,
    '',
    'Verify against the real files. Return:',
    '- verdict CONFIRMED if the problem is real and the evidence holds,',
    '- PLAUSIBLE if it may be real but you cannot fully confirm,',
    '- REFUTED if the evidence is wrong or the problem does not exist.',
    'Echo back severity/file/problem/evidence and add your reasoning.'
  ].join('\n');
}

// Workflow body — runs at top level in the async context the Workflow runtime provides.
const dimensions = REVIEWER_SETS[mode] || REVIEWER_SETS.full;

  phase('Review');
  log('review-plan: mode=' + mode + ' dimensions=' + dimensions.join(','));

  const reviewResults = await parallel(
    dimensions.map((dimension) => () =>
      agent(reviewerPrompt(dimension), {
        schema: FINDING_SCHEMA,
        label: 'review:' + dimension,
        phase: 'Review',
        agentType: 'Explore'
      })
    )
  );

  // Fail-safe: if every reviewer subagent failed (no results at all), do NOT fall through
  // to an empty-findings "approved" — that would be a false clean. Return blocked.
  const okReviews = reviewResults.filter(Boolean);
  if (dimensions.length > 0 && okReviews.length === 0) {
    log('review-plan: all reviewers failed — returning blocked (review incomplete)');
    return {
      verdict: 'blocked',
      blocking: [{ severity: 'blocking', file: planDir, problem: 'Plan review did not complete: every reviewer subagent failed to return results. Re-run review before trusting any approval.' }],
      important: [],
      minor: []
    };
  }

  const findings = okReviews
    .flatMap((r) => (r && Array.isArray(r.findings) ? r.findings : []))
    .filter(Boolean);

  log('review-plan: ' + findings.length + ' raw finding(s) to verify');

  phase('Verify');

  // Fail-safe verify: keep each finding unless its verifier EXPLICITLY refutes it.
  // A null/errored verifier keeps the finding (marked UNVERIFIED) rather than silently dropping it.
  const verifyOutcomes = await parallel(
    findings.map((finding) => () =>
      agent(verifyPrompt(finding), {
        schema: VERIFY_SCHEMA,
        label: 'verify:' + finding.severity,
        phase: 'Verify',
        agentType: 'Explore'
      }).then((v) => ({ finding: finding, v: v }))
    )
  );

  const verified = verifyOutcomes
    .filter(Boolean)
    .filter((o) => !(o.v && o.v.verdict === 'REFUTED'))
    .map((o) => ({
      severity: (o.v && o.v.severity) || o.finding.severity,
      file: o.finding.file,
      problem: o.finding.problem,
      evidence: (o.v && o.v.evidence) || o.finding.evidence,
      verify: o.v ? o.v.verdict : 'UNVERIFIED'
    }));

  const blocking = verified.filter((v) => v.severity === 'blocking');
  const important = verified.filter((v) => v.severity === 'important');
  const minor = verified.filter((v) => v.severity === 'minor');

  let verdict;
  if (blocking.length > 0) {
    verdict = 'blocked';
  } else if (important.length > 0 || minor.length > 0) {
    verdict = 'issues-found';
  } else {
    verdict = 'approved';
  }

  log('review-plan: verdict=' + verdict + ' blocking=' + blocking.length + ' important=' + important.length + ' minor=' + minor.length);

  return { verdict, blocking, important, minor };

# Yielding work versus worker execution

AgentOS has two distinct kinds of parallelism. Keeping them separate avoids
turning every decomposition choice into persistent queue state.

## Yield inside a task

A worker may use its own subagents or tools while handling one task. That work
shares the task's scope, acceptance criteria, result contract, and final state.
AgentOS observes one worker invocation and evaluates one result.

Use this when the delegated work is temporary and does not need an independent
checkpoint, human gate, retry budget, or queue dependency.

## Workers across tasks

AgentOS queue parallelism runs independent tasks in separate worktrees when the
repository is eligible. Each task has its own worker, run artifacts, result,
state transition, and merge boundary. Queue state remains single-writer, and
merge conflicts are left for inspection rather than resolved automatically.

Use this when a unit of work must survive a session, block or unblock other
tasks, carry a distinct acceptance contract, or be independently recovered and
reviewed.

## Decision rule

| Need | Prefer |
|---|---|
| Temporary research or implementation assistance within one acceptance contract | Worker-managed subagents |
| Durable dependency, separate ownership, or independent verification | AgentOS task |
| Cross-worker scheduling or worktree isolation | AgentOS task |
| Fast local decomposition with one final result | Worker-managed subagents |

These mechanisms can be combined. AgentOS schedules durable tasks; each routed
worker may still yield parts of its task internally. AgentOS does not inspect or
standardize a worker's private subagent protocol.

See [parallel-queue.md](../parallel-queue.md) for merge and recovery details.

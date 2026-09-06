# Working on netwatch

Read the relevant named sections of [report.typ](report.typ) before changing architecture,
dependencies or product behavior. Use [README.md](README.md) for current commands and delivered
capabilities. If code and research disagree, identify the discrepancy and resolve it explicitly;
do not quietly change the foundation or describe a planned capability as implemented.

- **Reuse before building.** Follow “Architecture → Where to build the foundation”: retain the
  controlled Frigate application and its integrated internals. Adapt upstream code when needed;
  missing plug compatibility alone does not justify replacement. Replace a boundary only with
  evidence of a requirement, measured benefit or unsustainable maintenance cost.
- **Keep ownership singular.** Follow “Where to build the foundation” and “Operational contract”:
  one camera configuration, authentication system and restream owner. Extend the native application
  instead of adding a parallel registry/UI/export path. Keep new incident/policy logic in distinct
  modules within the foundation; alternatives in the research are not mandatory dependencies.
- **Respect the product contract.** Consult “Trace one stream”, “Operational contract” and “First
  complete capability to implement” for time, reconnect, evidence and verdict semantics. Keep local
  operation independent of cloud services and preserve the customer's NVR role. Do not silently
  expand into specialist or identity features; consult “Product boundary” and “Commercial thesis”.
- **Check the actual dependency.** Follow “Security is architecture” and “Open-source composition”:
  inspect pinned source and shipped binaries, preserve attribution, and distinguish code, model
  and dataset rights. A release tag or build success does not establish safe deployment.
- **Use the project toolchain.** Use uv for Python and pnpm for JavaScript; preserve lockfiles.
  Use Firefox for browser verification. Keep vendor edits reproducible in the tracked integration
  patches and locks, and check that they apply to the pinned source before delivery.
- **Verify behavior and state limits.** Follow “Validation plan → Required measures”: exercise the
  changed flow in the actual application, including relevant failure/restart cases. Distinguish
  simulated footage, real-camera results and research claims; report what ran and what remains
  unverified. Do not equate a live preview or model benchmark with incident reliability.
- **Edit the source of truth.** Correct existing code/research directly. Do not create audit or
  progress documents, a docs directory, or additional first-party Markdown beyond README.md and
  this file. Keep README operational and synchronized with code; keep rationale and evidence in
  report.typ. Preserve ignored research and runtime data, and never stage secrets or generated
  artifacts. Upstream source checkouts retain their own documentation and notices.
- **Respect the authorized Git scope.** Check branch and diff before changing remote state.
  Update an existing PR in place when requested; do not merge without explicit user authorization.
  Report the concrete changes, validation and remaining limitations in the PR and final response.

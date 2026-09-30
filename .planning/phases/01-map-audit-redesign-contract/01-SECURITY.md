---
phase: 1
slug: map-audit-redesign-contract
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-20
---

# Phase 1 — Security

> Docs-only CONT-01. Threat register authored in PLAN 01–03. ASVS L1: grep-depth verification of mitigations. No implementation files modified.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Working tree → git commit | Docs-only phase; sneaking `src/world/` layout into the same commit | Markdown vs GDScript |
| Audit/contract markdown → Phase 2 authors | Stale or invented counts become false composition authority | Live constants vs foundation 576/23/150 |
| Camera table → `tests/world_render_validation.*` | Implementing cameras now tampers with the current-map GPU gate | Specified IDs vs scene nodes |
| Audit recommendations → runtime art | A sentence that promotes forbidden wild frames bypasses the 1× veto | `runtime_promotion` string |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | `src/world/*.gd` layout | high | mitigate | Phase commits vs `388aeb0` touch docs + `.planning` only. `git diff --name-only 388aeb0..HEAD -- src/world/` empty. `LAYOUT_VERSION` still `2`. `WORLD_BUILD_SEED` still `0xB35E7E`. | closed |
| T-01-02 | Tampering | `tests/world_render_validation.*` cameras | high | mitigate | Fifteen `camera_id`s specified in contract/proof. Diff empty on `tests/world_render_validation.gd` and `.tscn`. | closed |
| T-01-03 | Elevation of privilege | wild/salvage atlas promotion | high | mitigate | Audit + contract restate `forbidden_pending_human_visual_veto`. Five `WILD_TREE_REGIONS` unchanged. No new Rect2 in `src/world/`. | closed |
| T-01-04 | Information disclosure | docs/ markdown secrets | low | mitigate | Three deliverable docs contain no `.env`, LAN keys, or Addons/ vault dumps. | closed |
| T-01-05 | Spoofing | LAN described as internet-ready | medium | mitigate | Deliverable docs do not mention UDP 8791 or internet-ready LAN. Peer-one unchanged. | closed |
| T-01-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs this phase. No `package.json` / `Cargo.toml` / `requirements.txt`. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (`high`) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01-SC | T-01-SC | No package ecosystem in this Godot project; Phase 1 added none | PLAN 01–03 threat model | 2026-09-20 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-20 | 6 | 6 | 0 | gsd-secure-phase (verify-work post) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-20

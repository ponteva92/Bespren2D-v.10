# Addons archive extraction audit gate

`Addons/` is an immutable source vault. The extraction gate materializes every
physical non-container file plus every supported archive member as review
evidence; it is not an importer, does not promote assets, and never writes a
byte under `Addons/` or `assets/`. Physical archive-wrapper files are SHA-256
verified but deliberately not duplicated: their contents are the staged
archive-member evidence.

Run a fresh, ledger-verified stage from the project root:

```powershell
python tools/asset_pipeline/extract_addons_audit_sources.py --run-id vault-current-YYYYMMDD
```

The production command requires both current deep-audit ledgers:

- `artifacts/asset_audit/addons_file_ledger.jsonl`
- `artifacts/asset_audit/archive_member_ledger.jsonl`

It first requires the live physical file set to exactly match the file ledger.
Every physical archive wrapper is SHA-256 checked against that ledger, and every
physical non-container file is streamed to staging and SHA-256 checked against
the same ledger. It then requires every materialized archive member's lineage,
depth, occurrence, byte count, CRC (where supplied), SHA-256, and container
format to match the archive-member ledger.

For the current vault, a complete all-physical run must account for 31,404
physical file-ledger records: 31,259 loose files / 2,175,603,380 bytes staged,
145 archive wrappers / 180,230,867 bytes hash-verified but not copied, and 4,684
archive-member payloads / 892,666,069 bytes staged across 159 recursive
containers. Thus the stage contains 35,943 payloads and 3,068,269,449 bytes.
Those values are evidence targets, not permission to promote any source to
runtime.

## Output contract

Each run is fresh and immutable at:

```text
artifacts/asset_audit/extraction_runs/<run-id>/
  .gdignore
  run_manifest.json
  extraction_ledger.jsonl
  stage/
    .gdignore
    payloads/
      loose/l-<file-ledger-sequence>-<file-sha-prefix>.bin
      c-<container-sha-prefix>-i-<ordinal-hash>/m-<ordinal>-<member-sha-prefix>.bin
```

Neither archive-controlled nor loose source names select an output path. The
stage uses short, flat, hash-and-ordinal names so it remains within Windows path
limits. Loose source bytes are materialized as evidence; archive wrapper bytes
are not, because their fully verified contents are already materialized as
members. `artifact_relative_path` in the extraction ledger is relative to its
run directory; `stage_relative_path` in the manifest is project-relative. The
entire extraction-runs tree is excluded in
`export_presets.cfg` and both the run and payload stage have `.gdignore` files.

Every successful `archive_member` ledger row carries the physical source,
container lineage/hash/instance, raw and canonical member name, occurrence and
ordinal, size/compression/CRC, payload SHA-256, staged path/hash/bytes, logical
Unity metadata safety result, and the matched deep-audit decision fields.
`physical_loose_file` rows carry the physical file-ledger path/sequence/bytes/
SHA-256 and staged evidence hash. `physical_container_verification` rows prove
each non-copied archive wrapper matched the live file ledger. A failure always
creates a `gate_rejection` row plus a `status: rejected` manifest;
already-written safe payloads are retained as non-promotable evidence.

## Security and integrity gates

The gate intentionally avoids `extract()` and `extractall()` and never reads a
normal archive member or loose source wholesale. It streams each admitted
payload through SHA-256 and CRC calculation into a temporary file, `fsync`s it,
then atomically renames it into the fixed stage path.

- ZIP and gzip-TAR signatures are discovered by bytes, including nested
  containers. Named archives with an unsupported signature are rejected.
- Archive paths are evidence only and are rejected on traversal, absolute/UNC
  or drive/device paths, NUL/control characters, ADS colons, invalid Windows
  characters, trailing dot/space, `CON`/`AUX`/`COM*`/`LPT*` names, excessive
  component/path lengths, case collisions, and NFC/NFD Unicode collisions.
- ZIP symlinks and encrypted entries, TAR symlinks/hardlinks/FIFO/device nodes,
  duplicate canonical paths, and output reparse-point traversal are rejected.
- Per-file/member, per-container, whole-run bytes/entry/container/depth budgets
  and compression-ratio limits are enforced before payload publication. The
  current defaults are 192 MiB per staged file, 2 GiB per archive container,
  4 GiB total materialization, and 50,000 total source/archive entries.
  Available disk must cover all audited loose + expanded-member bytes, the
  largest atomic temp file, and a 64 MiB ledger margin.
- ZIP CRCs, gzip/TAR streaming integrity, member SHA-256 values, and source
  container hashes are checked. After every loose payload and archive member is
  staged, the gate re-hashes all 31,404 physical vault files against the file
  ledger in one post-stage checkpoint to detect a concurrent mutation.
- Unity `pathname` values are bounded and safety-validated as metadata only;
  they never control a disk location. Unsafe values are retained in a ledger row
  as `rejected_metadata_not_used`.

Two existing Adobe Animate FLA containers have a stale central-directory byte
count that the deep audit already identifies. Only for a malformed ZIP container
at most 8 MiB, the gate applies the same central-directory normalization in
memory, scans its valid unindexed local record(s), and still streams the payload
to staging with CRC/hash verification. Larger malformed containers are rejected
rather than buffered.

## Read-only validation and regression tests

Validate an already complete run without extracting anything:

```powershell
python tools/asset_pipeline/extract_addons_audit_sources.py --validate-run artifacts/asset_audit/extraction_runs/<run-id>
```

The validator rejects a legacy archive-members-only run as incomplete coverage.
For an all-physical production run it verifies every staged file's containment,
every intermediate stage/payload component has no reparse/junction redirect,
size, SHA-256, manifest counters, extraction-ledger SHA-256, absence of
temporary files, current deep-ledger hashes, and exact expected keys for loose
files, archive wrappers, and archive members. It also re-hashes the current
physical vault against the file ledger, so a source mutation after staging makes
the run invalid. The fast adversarial fixture suite
covers safe loose/nested ZIP/TAR extraction, source immutability, deterministic
stage validation, traversal/ADS/device and reserved-name rejection, ZIP
symlink/encryption/duplicate/case/Unicode/budget rejection, TAR
symlink/hardlink/FIFO rejection, unsafe Unity logical metadata, a production
deep-ledger mismatch, and an intermediate-reparse validator rejection where the
host permits symlink creation:

```powershell
python tests/extract_addons_audit_sources_validation.py
python tests/deep_asset_audit_validation.py
```

This gate proves source integrity and review isolation. License compatibility,
art direction, atlas preparation, runtime import settings, 480x270 readability,
and device performance still require their own approval gates.

# web-core: one core image per Ubuntu version, features added by the consumer

## Goal
web-core publishes one nginx + PHP image per Ubuntu version. A consuming project adds imagick, redis, memcached, ssh2 or cron with one build step, and no pre-made variant image is needed.

## Given state (2026-11-10)
- Repo `smol-kitten/web-core`, main at 2100e58. Draft PR #56 (daily job cut to 15 images) is open and independent of this plan.
- `Dockerfile_prep_base` compiles PHP 8.4 and all four PECL extensions once per Ubuntu version.
- `Dockerfile_nginx` copies that PHP tree into every variant. A variant differs only in two points: which `20-<ext>.ini` and `.so` files it keeps, and which runtime packages it installs.
- `build.yml` builds 96 nginx variants (3 versions x 2^5 flags) on every push to main and every Sunday.
- `security-update.yml` builds the same 96 every day. Measured 2026-11-10: about 340 GiB of SSD writes per run on the CI hosts.
- Tags in use, first count (GitHub code search plus local clones): 12 tags, 5 flag combinations: plain, `imagick`, `cron`, `imagick-cron`, `redis-memcached-cron`. The local clones were partly stale. The inventory gate below gives the present list.
- Consumers: 17 repos. All but one use a `FROM` line in a Dockerfile. `server-manager` uses `image:` in compose.
- Size: local images of the same day show 296 MB (plain 25.10) and 332 MB (`25.10-imagick-cron`). The features are small. The cost of the variants is the number of builds, not the image size.
- The runtime image has no PHP headers. A new PECL extension must be compiled in `prep_base`.
- Static and Bun images are out of scope.
- Open tasks: t-38b918 (CI writes), t-1c3f8d (tags in use that no workflow builds).

## Requirements
- R1. One published core image per Ubuntu version: `nginx:<version>`. It is the present plain tag. The plain tag loads none of the four extensions today, and the core loads none. Present users of the plain tag see the same loaded modules and the same packages.
- R2. One command in the image enables features at build time: `webcore-enable <feature>...` or `webcore-enable --file <path>`.
- R3. The command fails the build on an unknown feature, a failed package install, or an extension that does not load afterwards. It never fails silently.
- R4. The command is idempotent.
- R5. The Ubuntu-version-specific package lookups live in the command, not in consumer Dockerfiles.
- R6. Every tag in use keeps working and keeps its security rebuilds until its consumers have moved.
- R7. A consumer can build an intermediate base image (`Dockerfile.base`) for faster app builds. This is optional per project.
- R8. Not allowed: a push to web-core main starts a 96-image build.
- R9. Not allowed: deleting published tags without the operator's OK.
- R10. Not allowed: package installs at container start.

## Options considered
1. Keep the variants and only cut the build lists (PR #56). Not chosen as the end state: every new combination needs a new pre-made image, and the build list must track the consumers.
2. One fat image with every library installed and extensions switched on by an environment variable at start. Not chosen: ImageMagick and three more libraries sit in every app image, and the operator asked for a core that is truly a core. It stays possible later, because the size difference is small.
3. Lean core plus `webcore-enable` at consumer build time (chosen).
4. Core plus `ONBUILD` triggers driven by a build argument. Not chosen: implicit, and it does nothing for a consumer that sets no argument.

## Chosen approach
The core image keeps all four compiled extension files but loads none. `webcore-enable` works in this order. It rejects unknown names. It skips features that are on. It finds the runtime packages with `apt-cache` patterns and installs them. It writes `conf.d/20-<ext>.ini`. It then reads `php -m` and stops on a missing module or a PHP startup warning. It records the feature in `/etc/webcore/enabled`. `Dockerfile_nginx` calls the same command for its `INSTALL_*` arguments, so the remaining variant tags and the consumer path run the same code. The variant list shrinks to the tags in use and ends when the consumers have moved.

## Steps
1. web-core PR A (this branch):
   1. Add `src/webcore-enable` (features: imagick, redis, memcached, ssh2, cron; `--file`, `--list`).
   2. Add `src/webcore-apt` (uniform `apt-get update`, install without recommends, clean) for the consumer's own packages.
   3. Change `Dockerfile_nginx`: keep all extension `.so` files, remove all four `20-*.ini` files, call `webcore-enable` for the `INSTALL_*` arguments.
   4. Add `tests/consumer-enable/` and a `test-webcore-enable` job in `pr-test.yml`.
   5. Change `build.yml`: the nginx matrix builds the core plus the four variant combinations in use, per version (15 images, was 96).
   6. Update `README.md`: core image, `webcore-enable`, the features file, the intermediate-image pattern.
2. Verify PR A (see Verification). Run the inventory gate: search the three fleet orgs and the local clones for `smol-kitten/nginx:` again and write the tag list into the PR. Add each tag in use that is missing from the matrix. Then merge. The push to main builds 15 nginx images plus builder, static and bun.
3. Pilot: `katzenbube.de` moves to `FROM nginx:26.04` plus `webcore-enable imagick cron`, with a `Dockerfile.base` and a workflow that builds the base image. The katzenbube session does the change. The orchestrator reviews it.
4. File a reusable workflow for the base-image build in fleet-actions (pawkit session). Inputs: Dockerfile path, image name, schedule. Use the pilot's workflow as the source.
5. Move the other consumers through their sessions, one PR per repo. Plain-tag users change the version only. Check the support state of 25.10 first and move 25.10 users to 26.04 if it is out of support.
6. When code search and the local clones show no variant tag: remove the variant combinations from `build.yml` and `security-update.yml`. Three nginx images remain (two without 25.10).
7. Ask the operator whether the old variant tags are deleted from the registry or left as they are.

## Verification
- V1. `shellcheck` and `hadolint` report no error on the new and changed files. `actionlint` reports no error on the workflows.
- V2. Local build of the core and of a consumer image that enables all five features. `php -m` lists imagick, redis, memcached and ssh2. `php -r 'new Imagick();'` exits 0. `command -v cron` exits 0.
- V3. The core image loads none of the four extensions, and `php -v` prints no startup warning.
- V4. `webcore-enable nosuch` exits non-zero and names the valid features. A second run of the same enable line changes nothing and exits 0.
- V5. A variant built through `INSTALL_IMAGICK=true` has the same loaded-module list and package list as the published `24.04-imagick`. The new core has the same two lists as the published `24.04`.
- V6. The existing smoke test and the consumer nginx layout test stay green.
- V7. After merge: the push run on main shows 15 nginx jobs, and `matrix-report` is green.
- V8. Write figures of the CI hosts from the guest-audit sampler, before and after.

## Risks
- A repo that the search did not find uses one of the 81 variant tags that are no longer rebuilt. The tag stays pullable but gets no updates. Mitigation: the inventory gate in step 2; a missing tag is one line in the matrix. Undo: revert PR A, and the next push builds all 96 again. No tag is deleted, so each old image stays pullable.
- A consumer build now needs the Ubuntu archive when it enables a feature with packages. Mitigation: the intermediate base image moves that step out of the app build.
- A consumer base image goes stale. Mitigation: the base workflow has a weekly schedule, and the reusable workflow makes the schedule the default.
- `Dockerfile_nginx` changes for all remaining variants in one step. Mitigation: V5 and V6 before merge; the old images stay in the registry by digest.
- The core image grows by the size of four `.so` files. Measured in V2 and written into the PR.

## Results (2026-11-10, local builds)
- V1: `shellcheck` clean on the three scripts. `hadolint` reports no error. `actionlint` reports only findings that main has too.
- V2, V3, V4: `tests/consumer-enable/check.sh` passes on 24.04, 25.10 and 26.04 (core checks, consumer image with five features, second run is a no-op).
- V5: module list and package list are identical for new variant and published `24.04-imagick`, and for new core and published `24.04`.
- Size: core 276 MB, the same as the published `24.04` at MB precision. The four `.so` files are 1.36 MB together.

## Inventory gate (2026-11-10 19:20Z)
Scan of the default branch of all 147 non-archived repos in the three fleet orgs (224 Dockerfiles and compose files read, no read failed). Live references:
- `24.04-cron`: server-manager
- `24.04-imagick`: minecraft-archive
- `25.10-cron`: web-fapi
- `25.10-imagick`: web-goes.moe
- `26.04`: web-cat-boy.dev, web-catboy.systems, web-meds.catboy.systems, workflow-manager
- `26.04-imagick`: catboy-auth, comfy-email, web-cc.goes.moe, web-id.catboy.farm, web-list.catboy.systems, web-mari.pet, web-odu.goes.moe
- `26.04-imagick-cron`: katzenbube.de
- `26.04-redis-memcached-cron`: darter, web-m-schneider.cc

All 8 tags are in the matrix of 15. Most consumers are on 26.04 already. Only web-fapi and web-goes.moe use 25.10. Not covered by the scan: branches other than the default branch.

## Review round 1 (planhook: critic disagrees, MAGI approves)
- R1 against the removal of the `.ini` files: adopted as a clarification and a check. The plain tag loads none of the four today. V5 now compares the core with the published plain tag. Result: identical.
- Matrix cut on an inventory that may be incomplete: adopted. Step 2 has an inventory gate before merge, and Risks states the undo.
- Mechanics of the command not specified: adopted (Chosen approach).
- Merge before the pilot proves R7: rebutted. The pilot needs the published core with the command. The cut to 15 images does not depend on the consumer path, because the variant tags use the same Dockerfile (V5, V6).

Further rounds stop here

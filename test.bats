#!/usr/bin/env bats

# Tests de l'add-on ddev-claude.
# Lancer (hors release) :   bats ./test.bats --filter-tags '!release'

load tests/test_helper/bats-support/load.bash
load tests/test_helper/bats-assert/load.bash

setup() {
  set -eu -o pipefail

  # À adapter au vrai dépôt :
  export GITHUB_REPO=your-org/ddev-claude

  TESTDIR=$(mktemp -d)
  export PROJNAME="test-claude"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  mkdir -p "${TESTDIR}/${PROJNAME}"
  cd "${TESTDIR}/${PROJNAME}"

  ddev config --project-name="${PROJNAME}" --project-type=php
  ddev start -y >/dev/null

  # Chemin du dépôt de l'add-on (répertoire courant des sources).
  export DIR
  DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  [ -n "${TESTDIR:-}" ] && rm -rf "${TESTDIR}"
}

health_checks() {
  # Le conteneur claude tourne.
  run docker ps --format '{{.Names}}'
  assert_output --partial "ddev-${PROJNAME}-claude"

  # Claude Code est installé.
  run docker exec "ddev-${PROJNAME}-claude" claude --version
  assert_success

  # RTK est le bon (Token Killer) : `rtk gain` existe, pas "command not found".
  run docker exec "ddev-${PROJNAME}-claude" rtk --version
  assert_success

  # npx est dispo pour GSD.
  run docker exec "ddev-${PROJNAME}-claude" npx --version
  assert_success

  # Le code projet est bien monté.
  run docker exec "ddev-${PROJNAME}-claude" test -d /var/www/html
  assert_success

  # Les commandes host sont enregistrées.
  run ddev claude --help
  assert_success
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
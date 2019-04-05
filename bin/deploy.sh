#!/usr/bin/env bash
#
#   :mod:`deploy.sh` -- Vault configuration script
#   ==============================================
#
#   .. module:: deploy.sh
#       :platform: Unix
#       :synopsis: Configure new ot update existing vault instance
#
#   .. envvar::
#       :var VAULT_ADDR:
#           URL to access vault API; default is ``http://127.0.0.1:8200``
#
#       :var VAULT_TOKEN:
#           Root token; can be used to reconfigure existing vault instance;
#           default is emply
#
#       :var VAULT_SECRET_KEYS:
#           Space separated list of master key shares; can be used to unseal
#           existing vault storage; default is emply
#
#       :var VAULT_SECRET_SHARES:
#           Number of master key shares to initialize Vault storage;
#           default is ``5``
#
#       :var VAULT_SECRET_THRESOLD:
#           Threshold number to initialize Vault storage;
#           default is ``3``
#
#   .. requirements::
#       * ``curl``
#       * ``jq``
#       * ``virtualenv``
#       * ``pip``
#


set -o errexit

VAULT_TOKEN=${VAULT_TOKEN:-}
VAULT_SECRET_KEYS=${VAULT_SECRET_KEYS:-}

VAULT_ADDR=${VAULT_ADDR:-'http://127.0.0.1:8200'}
VAULT_SECRET_SHARES=${VAULT_SECRET_SHARES:-5}
VAULT_SECRET_THRESOLD=${VAULT_SECRET_THRESOLD:-3}


_status() {
    curl --silent --location \
        "${VAULT_ADDR}/v1/sys/seal-status" \
        | jq ".$*"
}

_initialize() {
    local out data
    data='{"secret_shares":'${VAULT_SECRET_SHARES}',"secret_threshold":'${VAULT_SECRET_THRESOLD}'}'
    out=$(curl --silent --location --request PUT --data "${data}" \
        "${VAULT_ADDR}/v1/sys/init" 2>&1)
    VAULT_TOKEN=$(echo "${out}" \
        | jq '.root_token' \
        | sed 's|"||g')
    VAULT_SECRET_KEYS=$(echo "${out}" \
        | jq '.keys[]' \
        | sed 's|"||g' \
        | head -n "${VAULT_SECRET_THRESOLD}")
    echo '[INFO] Initialized'
    echo '[INFO] Secret keys:'
    for key in ${VAULT_SECRET_KEYS} ; do
        echo "[INFO]   ${key}"
    done
    echo '[INFO] Root token:'
    echo "[INFO]   export VAULT_TOKEN=${VAULT_TOKEN}"
}

_unseal() {
    local data result
    [ -z "$VAULT_SECRET_KEYS" ] && echo '[ERROR] No keys to unseal' && exit 1
    for key in ${VAULT_SECRET_KEYS} ; do
        data='{"key": "'${key}'"}'
        out=$(curl --silent --location --request PUT --data "${data}" \
            "${VAULT_ADDR}/v1/sys/unseal" 2>&1)
        result=$(echo "${out}" | jq '.sealed')
    done
    [ "${result}" == 'true' ] && echo '[ERROR] Unable to unseal' && exit 1
    echo '[INFO] Unsealed'
}

_deploy() {
    local name path data
    pushd "${WORKDIR}/data" &>/dev/null
    find "${1}" -name '*.yaml' | while read -r file; do
      name=${file%.yaml}
      name=${name##*/}
      path=${file%/*}
      path="${path#./}/${name}"
      data=$(yq . < "${file}")
      echo "[INFO] Process ${path}"
      # shellcheck disable=SC2086
      curl \
        --silent \
        --location \
        --request POST \
        --header 'X-Vault-Token: '${VAULT_TOKEN} \
        --data "${data}" \
        "${VAULT_ADDR}/v1/${path}" 2>&1 | jq
    done
    popd &>/dev/null
}

WORKDIR="$(dirname "$(readlink -e "$0")")/.."

[ -z "${VAULT_ADDR}" ] && echo '[ERROR] VAULT_ADDR is not set' && exit 1

[ "$(_status initialized)" == 'false' ] && _initialize
[ "$(_status sealed)" == 'true' ] && _unseal
[ -z "${VAULT_TOKEN}" ] && echo '[ERROR] VAULT_TOKEN is not set' && exit 1

######################
#
# Install yq
#
if [ ! -d "${WORKDIR}/.venv" ] ; then
    virtualenv "${WORKDIR}/.venv"
    # shellcheck source=/dev/null
    source "${WORKDIR}/.venv/bin/activate"
    pip install yq
fi
# shellcheck source=/dev/null
source "${WORKDIR}/.venv/bin/activate"

######################
#
# Configure instance
#

_deploy sys/auth
_deploy sys/mounts
_deploy sys/policy
_deploy auth
_deploy kv

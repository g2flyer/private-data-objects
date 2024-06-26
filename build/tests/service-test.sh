#!/bin/bash

# Copyright 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -----------------------------------------------------------------
# -----------------------------------------------------------------
source ${PDO_SOURCE_ROOT}/bin/lib/common.sh
check_pdo_runtime_env
check_python_version

# -----------------------------------------------------------------
# -----------------------------------------------------------------
if [ "${PDO_LEDGER_TYPE}" == "ccf" ]; then
    if [ ! -f "${PDO_LEDGER_KEY_ROOT}/networkcert.pem" ]; then
        die "CCF ledger keys are missing, please copy and try again"
    fi
fi

# -----------------------------------------------------------------
# Process command line arguments
# -----------------------------------------------------------------
F_SCRIPT=$(basename ${BASH_SOURCE[-1]} )
F_SERVICE_HOST=${PDO_HOSTNAME}
F_LEDGER_URL=${PDO_LEDGER_URL}
F_LOGLEVEL=${PDO_LOG_LEVEL:-info}

F_USAGE='--host service-host | --ledger url | --loglevel [debug|info|warn]'
SHORT_OPTS='h:l:'
LONG_OPTS='host:,ledger:,loglevel:'

TEMP=$(getopt -o ${SHORT_OPTS} --long ${LONG_OPTS} -n "${F_SCRIPT}" -- "$@")
if [ $? != 0 ] ; then echo "Usage: ${F_SCRIPT} ${F_USAGE}" >&2 ; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -h|--host) F_SERVICE_HOST="$2" ; shift 2 ;;
        -1|--ledger) F_LEDGER_URL="$2" ; shift 2 ;;
        --loglevel) F_LOGLEVEL="$2" ; shift 2 ;;
        --help) echo "Usage: ${SCRIPT_NAME} ${F_USAGE}"; exit 0 ;;
    	--) shift ; break ;;
    	*) echo "Internal error!" ; exit 1 ;;
    esac
done

# -----------------------------------------------------------------
# -----------------------------------------------------------------
SAVE_FILE=$(mktemp /tmp/pdo-test.XXXXXXXXX)
ESDB_FILE=$(mktemp /tmp/pdo-test.XXXXXXXXX)
GROUPS_FILE=$(mktemp /tmp/pdo-test.XXXXXXXXX)

function cleanup {
    rm -f ${SAVE_FILE} ${ESDB_FILE} ${GROUPS_FILE}
}

trap cleanup EXIT

_COMMON_=("--logfile __screen__" "--loglevel ${F_LOGLEVEL}")
LOCAL_OPTS=${_COMMON_[@]}

_COMMON_+=("--ledger ${F_LEDGER_URL}")
NETWORK_OPTS=${_COMMON_[@]}

_COMMON_+=("--bind service_host ${F_SERVICE_HOST}")
PSHELL_OPTS=${_COMMON_[@]}

# -----------------------------------------------------------------
say verify that services are running
# -----------------------------------------------------------------
CURL_CMD='curl --ipv4 --retry 10 --connect-timeout 5 --max-time 10  -sL -w %{http_code} -o /dev/null'

function check_service() {
    url="http://${F_SERVICE_HOST}:$1/info"
    resp=$(${CURL_CMD} ${url})
    if [ $? != 0 ] || [ $resp != "200" ]; then
    	die "unable to contact service at $url"
    fi
}

declare -i port_count=5
declare -i pservice_base_port=7001
declare -i sservice_base_port=7101
declare -i eservice_base_port=7201
declare -i p s e v

for v in $(seq 0 $((${port_count} - 1))) ; do
    check_service $((pservice_base_port + v))
    check_service $((sservice_base_port + v))
    check_service $((eservice_base_port + v))
done

# -----------------------------------------------------------------
# these functions attemp to create a reproducible environment for
# each of the tests
# -----------------------------------------------------------------
function begin_test {
    yell $@
    try ${PDO_SOURCE_ROOT}/build/tests/site-configuration.psh ${PSHELL_OPTS}
}

function end_test {
    yell end test

    try pdo-service-db clear ${PSHELL_OPTS}
    try pdo-service-groups clear ${PSHELL_OPTS}
}

# -----------------------------------------------------------------
# -----------------------------------------------------------------
begin_test run unit tests for eservice database

try ${PDO_SOURCE_ROOT}/build/tests/service-storage-test.psh \
    ${PSHELL_OPTS} \
    --bind tmpfile ${ESDB_FILE}

say create the eservice database using database CLI
try pdo-service-db clear ${PSHELL_OPTS}
try pdo-service-groups clear

try pdo-service-db add --url http://${F_SERVICE_HOST}:7101 --name es7101 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7102 --name es7102 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7103 --name es7103 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7104 --name es7104 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7105 --name es7105 --type eservice ${PSHELL_OPTS}

end_test

# -----------------------------------------------------------------
# ----------------------------------------------------------------
begin_test start storage service test

try pdo-test-storage ${LOCAL_OPTS} --url http://${F_SERVICE_HOST}:7201

end_test

# -----------------------------------------------------------------
# -----------------------------------------------------------------
begin_test run unit tests for service groups database

try ${PDO_SOURCE_ROOT}/build/tests/service-groups-test.psh \
    ${PSHELL_OPTS} \
    --bind tmpfile ${GROUPS_FILE}

say create the service and groups database using the groups CLI
try pdo-service-db clear ${PSHELL_OPTS}
try pdo-service-groups clear

try pdo-service-db add --url http://${F_SERVICE_HOST}:7101 --name es7101 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7102 --name es7102 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7103 --name es7103 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7104 --name es7104 --type eservice ${PSHELL_OPTS}
try pdo-service-db add --url http://${F_SERVICE_HOST}:7105 --name es7105 --type eservice ${PSHELL_OPTS}

try pdo-eservice create --group test1
try pdo-eservice add --group test1 --url http://${F_SERVICE_HOST}:7101 http://${F_SERVICE_HOST}:7102
try pdo-eservice add --group test1 --name es7103 es7104

end_test

# -----------------------------------------------------------------
# -----------------------------------------------------------------
begin_test start request test

try pdo-test-request \
    ${NETWORK_OPTS} \
    --config pcontract.toml \
    --pservice http://${F_SERVICE_HOST}:7001/ http://${F_SERVICE_HOST}:7002 http://${F_SERVICE_HOST}:7003 \
    --eservice-url http://${F_SERVICE_HOST}:7101/ \
    --ledger ${F_LEDGER_URL} \
    --logfile __screen__ --loglevel ${F_LOGLEVEL}

# execute the common tests
for test_file in ${PDO_SOURCE_ROOT}/build/tests/common/*.json ; do
    test_contract=$(basename ${test_file} .json)
    say start test ${test_contract} with services
    try pdo-test-contract \
        ${NETWORK_OPTS} \
        --config pcontract.toml \
        --contract ${test_contract} --expressions ${test_file} \
        --pservice http://${F_SERVICE_HOST}:7001/ http://${F_SERVICE_HOST}:7002 http://${F_SERVICE_HOST}:7003 \
        --eservice-url http://${F_SERVICE_HOST}:7101/ \
        --logfile __screen__ --loglevel ${F_LOGLEVEL}
done

# execute interpreter specific tests
INTERPRETER_NAME=${PDO_INTERPRETER}
if [[ "$PDO_INTERPRETER" =~ ^"wawaka-" ]]; then
    INTERPRETER_NAME="wawaka"
fi

for test_file in ${PDO_SOURCE_ROOT}/build/tests/${INTERPRETER_NAME}/*.json ; do
    test_contract=$(basename ${test_file} .json)
    say start interpreter-specific test ${test_contract} with services
    try pdo-test-contract \
        ${NETWORK_OPTS} \
        --config pcontract.toml \
        --contract ${test_contract} --expressions ${test_file} \
        --pservice http://${F_SERVICE_HOST}:7001/ http://${F_SERVICE_HOST}:7002 http://${F_SERVICE_HOST}:7003 \
        --eservice-url http://${F_SERVICE_HOST}:7101/ \
        --logfile __screen__ --loglevel ${F_LOGLEVEL}
done

end_test

## -----------------------------------------------------------------
## -----------------------------------------------------------------
if [[ "$PDO_INTERPRETER" =~ ^"wawaka" ]]; then
    begin_test start the multi-user test
    try ${PDO_SOURCE_ROOT}/build/tests/multi-user.sh -h ${F_SERVICE_HOST} -l ${F_LEDGER_URL} --loglevel ${F_LOGLEVEL}
    end_test
else
    yell no multi-user test for ${PDO_INTERPRETER}
fi

## -----------------------------------------------------------------
## -----------------------------------------------------------------
begin_test test failure conditions to ensure they are caught

say create the contract
declare CONTRACT_FILE=${PDO_HOME}/contracts/_mock-contract.b64
if [ ! -f ${CONTRACT_FILE} ]; then
    die missing contract source file, ${CONTRACT_FILE}
fi
try ${PDO_HOME}/bin/pdo-create.psh \
    ${PSHELL_OPTS} \
    --client-identity user1 --psgroup all --esgroup all --ssgroup all \
    --pdo_file ${SAVE_FILE} --source ${CONTRACT_FILE} --class mock-contract

say invalid method, this should fail
${PDO_HOME}/bin/pdo-invoke.psh \
    ${PSHELL_OPTS} \
    --client-identity user1 --pdo_file ${SAVE_FILE} --method no-such-method
if [ $? == 0 ]; then
    die mock contract test succeeded though it should have failed
fi

say policy violation with identity, this should fail
${PDO_HOME}/bin/pdo-invoke.psh \
    ${PSHELL_OPTS} \
    --client-identity user2 --pdo_file ${SAVE_FILE} --method get_value
if [ $? == 0 ]; then
    die mock contract test succeeded though it should have failed
fi

end_test

# -----------------------------------------------------------------
# -----------------------------------------------------------------
begin_test test pdo-shell

try ${PDO_SOURCE_ROOT}/build/tests/shell-test.psh \
    ${PSHELL_OPTS}

end_test

# -----------------------------------------------------------------
# -----------------------------------------------------------------
if [[ "$PDO_INTERPRETER" =~ ^"wawaka" ]]; then
    begin_test run system tests for contracts

    cd ${PDO_SOURCE_ROOT}/contracts/wawaka
    try make system-test \
        TEST_LOG_LEVEL=${F_LOGLEVEL} \
        TEST_SERVICE_HOST=${F_SERVICE_HOST} \
        TEST_LEDGER=${F_LEDGER_URL}
    end_test
else
    yell no system tests for "${PDO_INTERPRETER}"
fi

# -----------------------------------------------------------------
# -----------------------------------------------------------------
begin_test run tests for state replication

cd ${PDO_SOURCE_ROOT}/build
say start mock-contract test with replication 3 eservices 2 replicas needed before txn.

try pdo-test-request \
    ${NETWORK_OPTS} \
    --config pcontract.toml \
    --pservice http://${F_SERVICE_HOST}:7001/ http://${F_SERVICE_HOST}:7002 http://${F_SERVICE_HOST}:7003 \
    --eservice-url http://${F_SERVICE_HOST}:7101/ http://${F_SERVICE_HOST}:7102/ http://${F_SERVICE_HOST}:7103/ \
    --ledger ${F_LEDGER_URL} \
    --logfile __screen__ --loglevel ${F_LOGLEVEL} --iterations 100 \
    --num-provable-replicas 2 --availability-duration 100 --randomize-eservice

end_test

# -----------------------------------------------------------------
# -----------------------------------------------------------------
yell completed all service tests
exit 0

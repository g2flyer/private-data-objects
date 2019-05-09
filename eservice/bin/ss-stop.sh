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

F_SERVICEHOME="$( cd -P "$( dirname ${BASH_SOURCE[0]} )/.." && pwd )"
source ${F_SERVICEHOME}/bin/common.sh

F_USAGE='-c|--count services -b|--base name'
F_COUNT=1
F_BASENAME='sservice'

# -----------------------------------------------------------------
# Process command line arguments
# -----------------------------------------------------------------
TEMP=`getopt -o b:c:h --long base:,count:,help \
     -n 'ss-stop.sh' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
    case "$1" in
        -b|--base) F_BASENAME="$2" ; shift 2 ;;
        -c|--count) F_COUNT="$2" ; shift 2 ;;
        --help) echo $F_USAGE ; exit 1 ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
    esac
done

rc=0
for index in `seq 1 $F_COUNT` ; do
    IDENTITY="${F_BASENAME}$index"
    echo stopping storage service $IDENTITY

    url="$(get_url_base $IDENTITY)/shutdown" || { echo "no url found for storage service"; exit 1; }
    resp=$(curl -sL -w "%{http_code}\\n" ${url} -o /dev/null)
    if [ $? != 0 ]; then # shutdown results in 500 error, so do not test also || [ $resp != "200" ]
	echo "storage service $IDENTITY not running or not properly shut down"
	rc=1
    fi
done
exit $rc
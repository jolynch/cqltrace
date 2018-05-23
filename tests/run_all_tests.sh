#!/bin/bash
set -uo pipefail

echo "Current directory"
echo ${PWD}
echo "Files in this directory"
find . -type f

TESTS=$(find . -name *.in)

for filename in $TESTS
do
    TEST="${filename%.*}"
    # Fun bash one liner ... this is probably super inefficient on large files,
    # so ... I wouldn't use this for anything other than testing
    echo "Checking ${TEST}.in against ${TEST}.out"
    diff <(./${TEST}.sh ${TEST}.in) <(cat "./${TEST}.out")
    if [[ $? -ne 0 ]]; then
        echo " ...FAILED"
        echo "Verification of test data failed"
        exit 1
    fi

    echo " ...PASSED"
done

echo "Solution seems to work"

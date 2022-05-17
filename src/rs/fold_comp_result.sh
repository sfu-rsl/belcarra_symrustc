#!/bin/bash

# SPDX-License-Identifier
# Copyright (C) 2021-2022 Simon Fraser University (www.sfu.ca)

set -euxo pipefail

SYMRUSTC_TARGET_NAME=belcarra/source

function belcarra_exec () {
    declare -i code_expected="$1"; shift
    local target="$1"; shift
    local input="$@"

    local output_dir=$SYMRUSTC_EXAMPLE0/$target/$SYMRUSTC_TARGET_NAME
    export SYMCC_OUTPUT_DIR=$output_dir/output

    mkdir -p $SYMCC_OUTPUT_DIR

    declare -i code_actual=0
    echo $input | $target/debug/belcarra || code_actual=$?
    echo $input | $SYMRUSTC_HOME_RS/hexdump.sh /dev/stdin

    ls $output_dir/output | wc -l
    cat $output_dir/hexdump_stdout
    cat $output_dir/hexdump_stderr

    if (( $code_expected != $code_actual )); then
        echo "$target: Unexpected exit code: $code_actual" >&2
        if [[ ! -v SYMRUSTC_SKIP_FAIL ]] ; then
            exit 1
        fi
    fi
}

for dir in "source_0_original_1a_rs 0 true 17 test" \
           "source_0_original_1b_rs 0 true 40 test" \
           "source_2_base_1a_rs 1 true 0" \
           "source_4_symcc_1_rs 0 false 3 -ne \x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03" \
           "source_4_symcc_2_rs 0 false 9 test"
do
    dir=( $dir )

    targets=( target_cargo )
    if eval ${dir[2]}; then
        targets+=( target_rustc_none target_rustc_file target_rustc_stdin )
    fi
    
    for target0 in ${targets[@]}
    do
        belcarra_exec ${dir[1]} ${dir[0]}/${target0}_on "${dir[@]:4}"
        if [ $(ls $SYMCC_OUTPUT_DIR | wc -l) -ne ${dir[3]} ] ; then
            echo "$target: check expected to succeed" >&2
            if [[ ! -v SYMRUSTC_SKIP_FAIL ]] ; then
                exit 1
            fi
        fi
        
        target=${dir[0]}/${target0}_off
        belcarra_exec ${dir[1]} $target "${dir[@]:4}"
        
        declare -i count=$(ls $SYMCC_OUTPUT_DIR | wc -l)
        if (( $count != 0 )); then
            if (( $count >= ${dir[3]} )); then
                echo "$target: check not expected to succeed" >&2
                exit 1
            else
                echo "warning: $SYMRUSTC_EXAMPLE0/$target not empty" >&2
            fi
        fi
    done
done

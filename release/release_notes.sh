#!/usr/bin/env bash
# Copyright (C) 2018 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

SCRIPT_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))

. ${SCRIPT_DIR}/../globals.sh
. ${SCRIPT_DIR}/../common.sh

. ./config/config.sh

var_load DS_DOWN_VERSION
var_load DS_FORMAT
var_load DS_LATEST
var_load DS_UP_VERSION
var_load MIX_VERSION
var_load MIX_UP_VERSION
var_load MIX_DOWN_VERSION

calculate_diffs() {
    # Collecting package data for old version
    local packages_path=${STAGING_DIR}/update/${DS_LATEST}/custom-pkg-list
    assert_file ${packages_path}

    old_package_list=$(sed -r 's/(.*)-(.*)-/\1\t\2\t/' ${packages_path})

    # Collecting package data for new version
    packages_path=${BUILD_DIR}/update/www/${MIX_VERSION}/custom-pkg-list
    assert_file ${packages_path}

    new_package_list=$(sed -r 's/(.*)-(.*)-/\1\t\2\t/' ${packages_path})

    # calculate added & changed packages
    while read NN VN RN ; do
        found=false
        while read NO VO RO ; do
            if [[ "${NN}" == "${NO}" ]] ; then
                if [[ "${RN}" != "${RO}" ]] || [[ "${VN}" != "${VO}" ]]  ; then
                    pkgs_changed+=$(printf "\n    %s    %s-%s -> %s-%s" ${NN} ${VO} ${RO} ${VN} ${RN})
                fi
                found=true
                break
            fi
        done <<< $old_package_list
        if ! ${found} ; then
            pkgs_added+=$(printf "\n    %s    %s-%s" ${NN} ${VN} ${RN})
        fi
    done <<< $new_package_list

    # calculate removed packages
    while read NO VO RO ; do
        found=false
        while read NN VN RN ; do
            if [[ "${NO}" == "${NN}" ]] ; then
                found=true
                break
            fi
        done <<< $new_package_list
        if ! ${found} ; then
            pkgs_removed+=$(printf "\n    %s    %s-%s" ${NO} ${VO} ${RO})
        fi
    done <<< $old_package_list
}

generate_release_notes() {
    calculate_diffs

    local downstream_format=$(< ${BUILD_DIR}/update/www/${MIX_VERSION}/format)

    cat > ${RELEASE_NOTES} << EOL
Release Notes for ${MIX_VERSION}

DOWNSTREAM VERSION:
    ${MIX_UP_VERSION} ${MIX_DOWN_VERSION} (${downstream_format})

PREVIOUS VERSION:
    ${DS_UP_VERSION} ${DS_DOWN_VERSION} (${DS_FORMAT})

ADDED PACKAGES:
${pkgs_added:-"    None"}

REMOVED PACKAGES:
${pkgs_removed:-"    None"}

UPDATED PACKAGES:
${pkgs_changed:-"    None"}
EOL
}

echo "Generating Release Notes"
generate_release_notes
echo "    Done!"

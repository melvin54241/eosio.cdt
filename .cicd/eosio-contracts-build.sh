#!/usr/bin/env bash
set -eo pipefail
. ./.cicd/helpers/general.sh
CDT_DIR_HOST=$(pwd)


[[ ! -z "$CONTRACTS_VERSION" ]] || export CONTRACTS_VERSION="$(cat "$PIPELINE_CONFIG" | jq -r '.dependencies["eosio.contracts"]')"
git clone -b "$CONTRACTS_VERSION" https://github.com/EOSIO/eosio.contracts.git 

for i in `seq 1 3`; do
rm -rf build_eosio_contracts
mkdir -p build_eosio_contracts

if [[ $(uname) == 'Darwin' ]]; then
    export PATH=$CDT_DIR_HOST/build/bin:$PATH
    cd build_eosio_contracts
    CMAKE="cmake ../eosio.contracts"
    echo "$ $CMAKE"
    eval $CMAKE
    MAKE="make -j $JOBS"
    echo "$ $MAKE"
    eval $MAKE
    cd ..
else #Linux
    ARGS=${ARGS:-"--rm --init -v $(pwd):$MOUNTED_DIR"}
    . $HELPERS_DIR/docker-hash.sh

    PRE_CONTRACTS_COMMAND="export PATH=$MOUNTED_DIR/build/bin:$PATH && cd $MOUNTED_DIR/build_eosio_contracts"
    BUILD_CONTRACTS_COMMAND="CMAKE='cmake ../eosio.contracts' && echo \\\"$ \\\$CMAKE\\\" \
    && eval \\\$CMAKE && MAKE='make -j $JOBS' && echo \\\"$ \\\$MAKE\\\" && eval \\\$MAKE"

    # Docker Commands
    # Generate Base Images
    $CICD_DIR/generate-base-images.sh
    if [[ "$IMAGE_TAG" == 'ubuntu-18.04' ]]; then
        FULL_TAG='eosio/ci-contracts-builder:base-ubuntu-18.04-develop'
        export CMAKE_FRAMEWORK_PATH="$MOUNTED_DIR/build:${CMAKE_FRAMEWORK_PATH}"
        BUILD_CONTRACTS_COMMAND="CMAKE='cmake -DBUILD_TESTS=true $MOUNTED_DIR/eosio.contracts' \
        && echo \\\"$ \\\$CMAKE\\\" && eval \\\$CMAKE && MAKE='make -j $JOBS' && echo \\\"$ \\\$MAKE\\\" && eval \\\$MAKE"
    fi

    COMMANDS_EOSIO_CONTRACTS="$PRE_CONTRACTS_COMMAND && $BUILD_CONTRACTS_COMMAND"

    # Load BUILDKITE Environment Variables for use in docker run
    if [[ -f $BUILDKITE_ENV_FILE ]]; then
        evars=""
        while read -r var; do
            evars="$evars --env ${var%%=*}"
        done < "$BUILDKITE_ENV_FILE"
    fi

    DOCKER_RUN="docker run $ARGS $evars $FULL_TAG bash -c \"$COMMANDS_EOSIO_CONTRACTS\""
    echo "$ $DOCKER_RUN"
    eval $DOCKER_RUN

fi

touch wasm-hash.$((i)).json

pushd build_eosio_contracts/contracts
for dir in */; do
    cd $dir
    for FILENAME in *.{wasm}; do
        if [[ -f $FILENAME ]]; then
            FILEHASH=$(sha256sum $FILENAME | awk '{print $1;}')
            export value=$FILEHASH
            export key="$FILENAME"
            JSON="$(echo "$JSON" | jq -c '.[env.key] += (env.value)')"
        fi
    done
    cd ..
done

echo '--- :arrow_up: Uploading wasm-hash.json'
popd
echo "$JSON" | jq '.' >> wasm-hash.$((i)).json
if [[ $BUILDKITE == true ]]; then

    buildkite-agent artifact upload wasm-hash.$((i)).json
    echo 'Done uploading wasm-hash.json'
    echo '--- :arrow_up: Uploading eosio.contract build'
    echo 'Compressing eosio.contract build directory.'
    tar -pczf 'build_eosio_contracts.$((i)).tar.gz' build_eosio_contracts
    echo 'Uploading eosio.contract build directory.'
    buildkite-agent artifact upload 'build_eosio_contracts.$((i)).tar.gz'
    echo 'Done uploading artifacts.'
fi

done
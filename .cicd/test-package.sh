#!/bin/bash
set -eu

echo '--- :docker: Selecting Container'

#DOCKER_REPO="blockone-b1fs-b1x-docker-dev-local.jfrog.io"
DOCKER_REPO="blockone-dockerhub.jfrog.io"
DOCKER_LOGIN_REPO="https://${DOCKER_REPO}"

echo "login to artifactory"
echo $ARTIFACTORY_PASSWORD | docker login $DOCKER_LOGIN_REPO -u $ARTIFACTORY_USERNAME --password-stdin

DOCKER_PULL="docker pull $DOCKER_REPO/$IMAGE"
echo "$ $DOCKER_PULL"
eval $DOCKER_PULL
echo "Done with pull"
echo "eval docker run $ARGS $evars $DOCKER_REPO/$FULL_TAG bash -c \"$COMMANDS\" "
eval docker run $ARGS $evars $DOCKER_REPO/$FULL_TAG bash -c \"$COMMANDS\"
echo "done with eval docker run..."
echo "docker run --rm -v "$(pwd):/eos" -w '/eos' -it $DOCKER_REPO/$IMAGE ./.cicd/test-package.run.sh"
docker run --rm -v "$(pwd):/eos" -w '/eos' -it $DOCKER_REPO/$IMAGE ./.cicd/test-package.run.sh
echo "done with docker run..."

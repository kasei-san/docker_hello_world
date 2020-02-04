#!/bin/sh

curl https://0ym4rbvub6.execute-api.us-east-1.amazonaws.com/production/create?branch_name=${BRANCH_NAME}&commit_hash=${CODEBUILD_RESOLVED_SOURCE_VERSION} &
pid=($!)
wait ${pid}

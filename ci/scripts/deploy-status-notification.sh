#!/bin/bash

set -e
set -x

url=$(cat metadata/atc-external-url)
team=$(cat metadata/build-team-name)
pipeline=$(cat metadata/build-pipeline-name)
job=$(cat metadata/build-job-name)
build=$(cat metadata/build-name)

notification=output/deploy_status_notification
pushd config
last_commit_summary=$(git show --summary)
popd

echo `
*${PRODUCT_NAME} deployment finish $BUILD_STATUS*
Triggered by:

\`\`\`
${last_commit_summary}
\`\`\`

<${url}/teams/${team}/pipelines/${pipeline} |Go to pipeline>
` >> $notification

exit 0

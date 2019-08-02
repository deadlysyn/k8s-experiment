#!/bin/bash -e
if [ ! $# -eq 1 ]; then
  echo "Must supply environment as arg"
  exit 1
fi

environment_name=$1
echo "Validating configuration for opsman"

touch ${environment_name}/config/vars/opsman.yml
touch ${environment_name}/config/secrets/opsman.yml

bosh int --var-errs --var-errs-unused ${environment_name}/config/templates/opsman.yml \
  --vars-file common/opsman.yml \
  --vars-file ${environment_name}/config/vars/opsman.yml \
  --vars-file ${environment_name}/config/secrets/opsman.yml > /dev/null

echo "Validating configuration for director"

touch ${environment_name}/config/vars/director.yml
touch ${environment_name}/config/secrets/director.yml

bosh int --var-errs --var-errs-unused ${environment_name}/config/templates/director.yml \
    --vars-file common/director.yml \
    --vars-file ${environment_name}/config/vars/director.yml \
    --vars-file ${environment_name}/config/secrets/director.yml > /dev/null

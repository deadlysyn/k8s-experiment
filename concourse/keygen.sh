#!/usr/bin/env bash

set -ex

mkdir -p keys/web keys/worker

openssl genrsa -out ./keys/web/keypair.pem 4096
openssl rsa -in ./keys/web/keypair.pem -pubout -out ./keys/web/web.crt
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in ./keys/web/keypair.pem -out ./keys/web/web.key

ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''
ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''
cp ./keys/worker/worker_key.pub ./keys/web/authorized_worker_keys
cp ./keys/web/tsa_host_key.pub ./keys/worker
touch keys/concourse_keys

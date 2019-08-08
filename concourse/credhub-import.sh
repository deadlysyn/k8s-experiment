#!/usr/bin/env bash

set -e

credhub login -s https://localhost:9000 -u credhub -p password --skip-tls-validation
credhub import -f config/credhub-export.yml

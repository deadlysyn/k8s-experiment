#!/usr/bin/env bash

ENV="$1"

: "${ENV:?Provide environment name as argument}"

fly -t pks sp \
	-p pks-automation \
	-c ${ENV}/pipeline.yml \
	-l ${ENV}/pipeline-params.yml

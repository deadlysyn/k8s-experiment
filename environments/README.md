# Overview

Generate tile configuration for a given product by first placing a version file for that product in `${environment}/config/versions/${product}.yml` where `${product}` must match the tile product not the pivnet slug (cf vs elastic-runtime).

`./generate-config.sh ${product} # ran from environments directory`

You should also generate `${product}-stemcell.yml`, using existing files as reference. Consult Pivnet to determine compatible product and stemcell versions.  The versions files serve as your deployment manifest, allowing you to have fine-grained control over what's deployed in each environment.

This will generate an empty `${product}-operations` file in this directory. Update that file with the operations files you need and re-run `./generate-config.sh`. The generate script also makes a temporary `tile-configs` directory at runtime. This should not be committed to git (it's in `.gitignore`), but can be used as reference for a list of available operations files (`tree tile-config/${product}-config`).

## Validate

Configuration is validated for completeness by using the following files

  - `${environment}/templates/${product}.yml`
  - `${environment}/defaults/${product}.yml`
  - `common/${product}.yml`
  - `${environment}/vars/${product}.yml`
  - `${environment}/secrets/${product}.yml` (interpolated from credhub at runtime)

Validation checks to see if values used in the template are properly contained in one of the vars files, and that all vars specified in files are actually used.

### Vars
These are often strewn around git and terraform, with a goal of migrating product specific vars migrating to `${environment}/config/vars/${product}.yml` for env-specific settings and global values in `common/${product}.yml`.

### Secrets
The `secrets` directories do not contain actual secrets as-is in git. These are templates used by `credhub-interpolate`, which only exposes the required secrets inside the ephemeral concourse containers.

### Pipeline Params
Parameter file to deploy pipeline `pipeline-params.yml` - put common, non-sensitive, per-environment things here for easy reference.

```
foundation: sandbox
...
```

## Deploy Pipeline
From the `environments` directory:

`fly -t ${environment} sp -p ${pipeline_name} -c ${environment}/pipeline.yml -l ${environment}/pipeline-params.yml`

![starter pks pipeline](https://raw.githubusercontent.com/deadlysyn/k8s-experiment/master/assets/pipeline.png)

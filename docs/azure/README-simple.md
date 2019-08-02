# PKS on azure faster

run the version of https://github.com/pivotal-cf/terraforming-azure that ships with your PAS/OM version from Pivnet (e.g. 2.6 ships with 0.40.0). have a DNS subdomain handy to delegate to Azure (makes access easier). go over the repo readme and run with `ops_manager_image_uri = ""` (pave iaas but don't create opsman VM).

forget "supported path" and get concourse ASAP so we can focus on PKS...

```
# create
wget https://concourse-ci.org/docker-compose.yml
docker pull postgres
docker pull concourse/concourse
docker-compose up -d

# connect
fly -t pks login -c http://localhost:8080 -u test -p test
fly -t pks sync

# destroy
docker-compose down
```



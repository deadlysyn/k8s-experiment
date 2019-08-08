# concourse in a box

WARNING: THIS IS WIP!

```
# create
wget https://raw.githubusercontent.com/deadlysyn/k8s-experiment/concourse/master/docker-compose.yml
docker-compose up -d

# connect
fly -t pks login -c http://localhost:8081 -u test -p test
fly -t pks sync

# credhub
credhub-cli login -s https://localhost:9000 -u credhub -p password --skip-tls-validation
credhub set -n /foo/bar -t value -v baz

# destroy
docker-compose down
```


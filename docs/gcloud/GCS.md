# Using GCS for Concourse storage

To create a private bucket with versioning enabled, execute the following:

```
gsutil mb -c regional -l us-central1 gs://${GCSbucket}
gsutil versioning set on gs://${GCSBucket}
```

Zero state file:

```
echo "---" > ~/state.yml
gsutil cp ~/state.yml gs://${GCSbucket}
```



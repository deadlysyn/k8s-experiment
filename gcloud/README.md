# Pre-reqs

You have a Google Cloud Platform account and access to https://console.cloud.google.com.

TODO: Link to docs on setting that up.

# Install gcloud SDK:

Lets you work with GCP from your local machine...

- https://cloud.google.com/sdk/install
  - https://cloud.google.com/sdk/docs/quickstart-macos
  - also: `brew cask install google-cloud-sdk`
- configure: `gcloud init` (answer questions)
- verify:
  - `cat ~/.config/gcloud/configurations/config_default`
  - `gcloud auth login`
- experiment:
  - go to console > compute engine and create a vm instance
  - from your machine: `gcloud compute instances list`
  - `gcloud compute ssh $instanceName` _**_
  - `gcloud compute instances delete $instanceName --zone=$zoneName`

_**_ For `gcloud compute ssh` to work, you need to create instances on the default
VPC (which allows SSH by default), or add a firewall rule to your VPC allowing
the traffic. One way to do this without a blanket allow is via console >
VPC Network > $yourVPC > Firewall rules > Add firewall rule. Allow TCP/22, and
specify a target tag of "ssh-in" (or something you will remember). Then you can
simply apply this tag to compute instances to allow SSH access as needed
(`gcloud compute instances add-tags $instancename --tags ssh-in`).


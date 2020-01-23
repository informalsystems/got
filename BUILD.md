# Game of Tendermint

## How to package a Nightking AMI image
- [Prerequisites](#prerequisites)
- [Folder structure](#folder-structure)
- [The build process](#the-build-process)

### Prerequisites
- [Amazon AWS account and API keys](https://aws.amazon.com/premiumsupport/knowledge-center/create-access-key/)
- [Packer](https://packer.io)
- [Ansible](https://ansible.com)
- [Source code](https://github.com/interchainio/got)

Installing and configureing the prerequisites is outside of the scope of this documentation.

### Folder structure
The `experiments` folder contains the list of experiments by name (one folder - one experiment).

- Read the [How to create new experiments](XP.md) guide to learn more about creating experiments.

The `extras` folder contains scripts and examples for easier maintenance.

- `aws-manager` contains Interchain internal scripts to clean up old, unused Nightking AMIs and snapshots.
Do NOT run these scripts. You can use them as examples for your own purposes.

- `launcher` contains a Terraform script with wrappers for easier Nightking deployment. This is described in more details
in the [How to run packaged experiments](RUN.md) document under the `Running the experiments using Terraform` section.

The `roles` folder contains Ansible roles that are executed in the `setup.yml` play during the build on the server.

- OS configuration roles
  - debug: changes core dump settings for system services. It is only run if the `DEBUG=1` environment variable is set
  during the execution of the build.
  - journald: configures journald to not drop any messages when there's a message flood
  - openfiles: raises the limit on the number of open files on the OS
  - yum: Install basic applications and security upgrades for the OS
- Infrastructure services roles
  - monitoring: Installs services to monitor and graph experiments
  - terraform: Installs Terraform
  - terraform-templates: Copies over Terraform configuration templates for experiment infrastructures
- Core application and configuration roles
  - tendermint: Installs Tendermint application
  - tm-load-test: Installs the TM-Load-Test application
  - scripts: Copies over experiment configurations and experiment orchestration scripts

### The build process
You can build a new Nightking image with the following command:
```shell script
packer build packer.json
```

Alternatively, if you don't want to run experiments automatically (for example this will be a developer's AMI), you can
set NOAUTORUN=1 in the environment before you start building:
```shell script
NOAUTORUN=1 packer build packer.json
```

- Packer spawns an EC2 instance in AWS based on Amazon Linux, in the us-east-1 region.
- Packer uses Ansible to apply the defined roles on the running server.
- Packer shuts down the server and copies the image over to the below regions:
  - us-east-1
  - us-east-2
  - us-west-1
  - us-west-2
  - ca-central-1
  - sa-east-1
  - eu-west-1
  - eu-west-2
  - eu-west-3
  - eu-north-1
  - eu-central-1
  - ap-south-1
  - ap-northeast-1
  - ap-northeast-2
  - ap-southeast-1
  - ap-southeast-2
- You can use any of these regions to spawn a new Nightking server.
- The AMI description will say "Interchain Nightking image {{ timestamp }}" where the timestamp is a UTC-based timestamp
since system epoch.
- Use the AMI owner and description to identify copied images in different regions.

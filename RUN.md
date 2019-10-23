# Game of Tendermint

## How to run packaged experiments
- [Prerequisites](#prerequisites)
  - [Amazon AWS account](#1-amazon-aws-account)
  - [Amazon AWS AMI image](#2-amazon-aws-ami-image)
    - [How to obtain an image ID](#how-to-obtain-an-image-id)
- [AWS Web UI or Terraform](#aws-web-ui-or-terraform)
- [Running the experiments using Amazon AWS Web UI](#running-the-experiments-using-amazon-aws-web-ui)
  - [Set up the configuration](#1-set-up-the-configuration)
  - [Create an EC2 instance](#2-create-an-ec2-instance)
- [Running the experiments using Terraform](#running-the-experiments-using-terraform)
- [Configuring an instance using tags](#configuring-an-instance-using-tags)
  - [EXPERIMENTS](#experiments)
  - [PASSWORD](#password)
  - [DEBUG](#debug)
  
### Prerequisites
#### 1. Amazon AWS account
The Amazon account used has to have access to EC2 (create/delete instances, key-pairs and
security groups) and IAM (create/delete instance profiles, policies and roles) on all AWS regions used in experiments.

Note: At the time of writing, only 16 AWS regions are used in experiments. Check out the "Build process" section of the
[How to package a Nightking AMI image](BUILD.md) guide to see the list of regions involved.

Note: Some AWS regions are not enabled by default on fresh AWS accounts. If you receive e-mails with the subject
"Your Request For Accessing AWS Resources Has Been Validated", it is a good indication that an experiment tried to use
a region that was previously not enabled.

You can either use the [AWS web UI](#aws-web-ui-or-terraform) or the [Terraform scripts](running-the-experiments-using-terraform)
and command-line described below to start running the experiments.

#### 2. Amazon AWS AMI image
Experiments and the necessary tools are packaged into an Amazon AWS AMI image.
These images are stored and shared on AWS.

You can refer to an image using its AMI ID otherwise called an image ID.

##### How to obtain an image ID
Research papers using the Game of Tendermint framework can host their pre-built image ID on AWS.
If that is the case, the image ID should be mentioned in the research paper,
together with the AWS region where that image is hosted.

See [an example](THESIS.md) for more details.

Research papers might describe their experiments in other format, for example sharing the experiment files only. In that
case, read the [How to package a Nightking AMI image](BUILD.md) documentation.
 
If only the Tendermint version and configuration is shared, you might need to build the experiments yourself, together with
the AMI image. The [How to create new experiments](XP.md) guide can help with that.

### AWS Web UI or Terraform
First, you need to decide if you are going to manage the Nightking node through the Amazon AWS Web UI or from Terraform.
Setting up Terraform is not part of this documentation. If you are familiar with it, feel free to use it. Otherwise,
stick to Amazon's Web UI.

### Running the experiments using Amazon AWS Web UI
Although, the actual execution of the experiments only entails creating an EC2 instance from the AWS AMI, it is
important to prepare a few things before the actual EC2 server creation.

Please note: The Amazon AWS Web UI receives constant improvements from the developers at Amazon. The exact look might
differ from the one that was in use at the time of writing. Because of this, no images are attached to this document.
We will try to describe the necessary options generally, so a generic understanding of Amazon EC2 instances should
be applied.

#### 1. Set up the configuration
You need to decide on three configuration items for your Nightking EC2 instance. Most of these can be decided during
the EC2 instance creation, but they are described here separately for more details.

##### IAM role
The Nightking server will need access to the Amazon AWS account to be able to create and manage additional EC2 instances
for the Tendermint network nodes (Starks) and the load-test nodes (Whitewalkers).

IAM -> Roles -> Create role -> AWS Service, EC2 access -> AdministratorAccess [-> give it a name].

Optionally, you can do this during EC2 instance creation. There is a "Create new IAM role" link where you have to add
the IAM role you want to use for the instance.

##### Security group
The Nightking server has to have a security group that describes what ports are accessible from what IP addresses.
The minimum required setup is to have the below TCP ports open to the world (`0.0.0.0/0`):
- TCP port 8086 (InfluxDB TLS port for the data backend)
- TCP port 26656 (Tendermint P2P port for the seed node)
- TCP port 26670 (Load-Test Master port)

The below port has to be enabled to be accessed from your IP address (it is not necessary to enable it for the whole world):
- TCP port 443

The below ports are only necessary for troubleshooting and development (it's enough to enable them for your IP):
- TCP port 80 (Server summary and server certificate download link)
- TCP port 22 (SSH port for console connection to the server - requires SSH key setup described below)

EC2 -> (Network & Security) Security groups -> Create Security Group [-> Add the inbound rules and give it a name].

Optionally, you can do this during the EC2 instance creation. There is a "Configure Security Group" page where you get
to create a new one, if necessary and add all the rules on one page.

##### [optional] SSH key
If you want to troubleshoot the server, you will need an SSH public key added during the creation of the instance.
The key will be set for the `ec2-user` on the server.

EC2 -> (Network & Security) Key Pairs -> Import Key Pair [-> Browse, upload, name it and Import the key].

OR alternatively you can create a new key-pair on the website:

EC2 -> (Network & Security) Key Pairs [-> name it and download the private key].

Optionally, you can create a new key-pair during the EC2 instance creation. You cannot import a key-pair during the
EC2 instance creation at the time of writinh. It is considered more secure to create your key-pair on your machine and
import the public key to AWS.

#### 2. Create an EC2 instance
After going through the configuration setup, you should be able to easily create a new Nightking EC2 isntance.

EC2 -> (Images) AMI -> [Make sure the filter says "Public Images"] -> Search for the AMI ID you received previously -> 
Launch -> Choose an Instance Type (e.g.: `t2.micro`) -> in the details, set the IAM role you created previously ->
in Storage add some more storage so you have enough for the received data -> in Tags, add any optional tags (see below)
-> set the Security Group created before -> Launch your instance.

After a few minutes the instance launched and you should be able to log in to the Grafana dashboards on the
https://<public-DNS-name> address. The default Grafana username and password is `admin/admin`, unless you changed them
using the tags.

### Running the experiments using Terraform
You can find the Terraform script in `extras/launcher/terraform.tf`. It goes through the configuration setup and
launches a Nightking instance. Open it up and check the first few lines for the available variables.

You can also use the Shell scripts in the same folder as examples on how to create or destroy a Nightking server.

### Configuring an instance using tags
During instance creation, EC2 Instace Tags can be used to configure some of the behaviour of the Nightking server.

#### EXPERIMENTS
Definition: a comma-separated list of experiment names to execute.

By default, the Nightking server will run all experiments built into it. If a comma-separated list of experiment names
are provided, only those experiments will be executed.

Note: The list of experiments can be found in the `experiments` folder in the source code.

Note: You can change this tag in AWS and reboot the server. The new values will be used.

#### PASSWORD
Definition: Grafana `admin` user password. Defaults to `admin` if unset.

#### DEBUG
Definition: Debug flag. Unset by default. If set, the additionally created EC2 nodes will not be destroyed by the
Nightking server at the end of the experiments.

Note: You need to set an SSH key (described above) to be able to log on to the Nightking server or the additional
servers when you are troubleshooting something. This flag has not much use without logging in to the servers.

Note: The Terraform code for a specific experiment is stored under the `/root/terraform-<experiment_name>` folder.
You can use that folder and terraform to automatically destroy the extra nodes (and additional infrastructure) after
you are done troubleshooting. Or you can use the AWS Web UI to do manual cleanup.

Note: You can change this tag in AWS and reboot the server. The new values will be used.

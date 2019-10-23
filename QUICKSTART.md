# Game of Tendermint

## Quickstart guide
Reminders for the time when you already know what you're doing.

- [Quick start a Nightking instance](#quick-start-a-Nightking-instance)
- [Quick start a Nightking AMI build](#quick-start-a-nightking-ami-build)

### Quick start a Nightking instance
- Have an AWS account with EC2 Full access and IAM role creation access
- Create an IAM role that allows Nightking servers to create more EC2 instances (EC2 Full Admin)
- Create a security group for Nightking
  - Port 443 for your IP
  - Port 8086, 26656, 26670 to the world
  - [optional] Port 22,80 for your IP for troubleshooting
- [optional] Create an SSH key pair or import one
- Create the EC2 instance from AMI ID.
- [optional] Connect to http://<public-DNS-name>, download and install the server certificate
- Connect to https://<public-DNS-name> (if you didn't install the server certificate, accept the warning)
- Default user is `admin`, default password is `admin` or if you used Terraform, `notverysecurepassword`.

### Quick start a Nightking AMI build
- Double-check the `experiments` folder to see if everything is there.
- Run `packer build packer.json` with AWS access.
- Check the description of the AMI at the end to get the timestamp.

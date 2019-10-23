#!/bin/bash

# Removes unused IAM instance profiles, roles and policies.

# Note: if you use aws-vault or any other tool with GetSessionToken for access, you will need to have MFA enabled for IAM access.
# See also: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_request.html
#           "Cannot call IAM API operations unless MFA information is included with the request."

set -euo pipefail

echo "Usage: $0"
echo -ne "jq needs to be present. "
which jq

# To be able to remove instance profiles... //Todo: Low priority cleanup: keep the roles too so it doesn't need to be queried again below.
instance_profiles=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[] | select(.InstanceProfileName | (startswith("stark") or startswith("whitewalker")) and endswith("-self-read-role")) | .InstanceProfileName')
if [ -n "${instance_profiles}" ]; then
  echo -e "Found instance profile(s):\n${instance_profiles}\nRemoving..."
  for i in ${instance_profiles//\\n/ }
  do

    #...we need to detach any roles attached to them first...
    roles_attached=$(aws iam get-instance-profile --instance-profile-name "${i}" | jq -r '.InstanceProfile.Roles[] | .RoleName')
    for r in ${roles_attached//\\n/ }
    do
      aws iam remove-role-from-instance-profile --instance-profile-name "${i}" --role-name "${r}"
    done

    #...then we can remove the instance profile.
    aws iam delete-instance-profile --instance-profile-name "${i}"
  done
else
  echo "Did not find any instance profiles. Moving on."
fi

# To be able to remove roles...
role_names=$(aws iam list-roles | jq -r '.Roles[] | select(.RoleName | (startswith("whitewalker") or startswith("stark")) and endswith("-self-read-role")) | .RoleName')
if [ -n "${role_names}" ]; then
  echo -e "Found role name(s):\n${role_names}\nRemoving..."
  for i in ${role_names//\\n/ }
  do

    #...we need to detach any role policies first...
    attached_policies=$(aws iam list-attached-role-policies --role-name "${i}" | jq -r '.AttachedPolicies[] | .PolicyArn')
    for p in ${attached_policies//\\n/ }
    do
      aws iam detach-role-policy --role-name "${i}" --policy-arn "${p}"
    done

    #...then we can delete the role.
    aws iam delete-role --role-name "${i}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
  done
else
  echo "Did not find any roles. Moving on."
fi

# Remove policies
policy_arns=$(aws iam list-policies | jq -r '.Policies[] | select(.PolicyName | (startswith("whitewalker") or startswith("stark")) and endswith("-self-read-policy")) | .Arn')
if [ -n "${policy_arns}" ]; then
  echo -e "Found policy ARN(s):\n${policy_arns}\nRemoving..."
  for i in ${policy_arns//\\n/ }
  do
    aws iam delete-policy --policy-arn "${i}" 2> /dev/null || echo "Did not remove ${i}. Moving on."
  done
else
  echo "Did not find any policies. Moving on."
fi


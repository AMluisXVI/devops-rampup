#!/usr/bin/env bash
# Copies playbooks + app code to the bastion and runs Ansible THERE (requirement).
# The SSH agent is forwarded (-A) so the private key never leaves your machine.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV=${1:?usage: ansible/run.sh qa|prod}
[ "$(terraform -chdir=terraform workspace show)" = "$ENV" ] || { echo "select workspace $ENV first"; exit 1; }
ssh-add -l >/dev/null || { echo "load your key into ssh-agent first (ssh-add)"; exit 1; }

BASTION=$(terraform -chdir=terraform output -raw bastion_public_ip)
SSH="ssh -o StrictHostKeyChecking=accept-new"
# Every deploy creates a new bastion that may reuse an old public IP: drop the stale key, trust the new one.
ssh-keygen -R "$BASTION" >/dev/null 2>&1 || true

$SSH ec2-user@"$BASTION" 'cloud-init status --wait >/dev/null'  # Ansible is installed by user_data
rsync -az --delete -e "$SSH" --exclude node_modules --exclude test-results.xml \
  ansible movie-analyst-api movie-analyst-ui ec2-user@"$BASTION":deploy/
$SSH -A ec2-user@"$BASTION" "cd deploy/ansible && ansible-playbook -i inventory/$ENV.ini site.yml"

#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
terraform plan -detailed-exitcode -no-color -input=false > /tmp/drift-plan.txt 2>&1
case $? in
  0) echo "$(date -Is) sem drift" ;;
  2) echo "$(date -Is) DRIFT detetado, vê /tmp/drift-plan.txt" ;;
  *) echo "$(date -Is) erro no plan, vê /tmp/drift-plan.txt" ;;
esac

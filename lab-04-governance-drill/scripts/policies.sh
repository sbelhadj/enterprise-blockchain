#!/usr/bin/env bash
#
# Listing L4.1: Part A. Every policy in the channel configuration that decides a
# governance question, decoded from the configuration block, and the chaincode's
# own endorsement policy from its committed definition.
set -euo pipefail
source "$(dirname "$0")/env.sh"
fetch_config "$W/config.json"
jq -r '
  def rule: if .type == 3 then "\(.value.rule) \(.value.sub_policy)"
    else "\(.value.rule.n_out_of.n) of " +
      ([.value.identities[] | "\(.principal.msp_identifier).\(.principal.role
        | ascii_downcase)"] | join(", ")) end;
  def show(p): .policies | to_entries[] | select(.key | IN("Admins",
    "LifecycleEndorsement", "Endorsement", "BlockValidation"))
    | "\(p)/\(.key) | \(.value.policy | rule)";
  .channel_group
  | show("Channel"),
    (.groups.Application | show("Application")),
    (.groups.Orderer | show("Orderer")),
    (.groups.Application.groups.ExportBankMSP | show("ExportBankMSP")),
    "Raft consenters | \(.groups.Orderer.values.ConsensusType.value.metadata
      .consenters | length)",
    "Application orgs | \(.groups.Application.groups | keys | map(sub("MSP$"; ""))
      | join(" "))",
    "Orderer orgs | \(.groups.Orderer.groups | keys | map(sub("MSP$"; ""))
      | join(" "))"
' "$W/config.json" | awk -F' [|] ' '{printf "%-33s %s\n", $1, $2}'
use exportbank
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n "$CC" -O json |
  jq -r '"lc \(.version), sequence \(.sequence) | " +
    (.validation_parameter | @base64d | gsub("[^A-Za-z/]"; ""))' |
  awk -F' [|] ' '{printf "%-33s %s\n", $1, $2}'

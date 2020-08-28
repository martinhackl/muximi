#!/bin/bash

set -u
set -e

VERSION=0.1.0

#== FUNCTION  ==================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
usage() {
  cat<<- EOT
Start a Tmux session preconfigured with a JSON file.

usage : $0 [config file] [comma separated commands]

  Possible commands are:
    - create ... Create new session.
    - attach ... Attach to session.
    - remove ... Remove session.
    - run    ... Only when used with 'create': Run configured commands.
EOT
}

# ------------------------------------------------------------------------------
# Parameters
# ------------------------------------------------------------------------------
[ $# -ne 2 ] && { usage; exit 1; }

json_file=$1
in_cmds=$2 
IFS=',' read -r -a cmds <<< "$in_cmds"

# ------------------------------------------------------------------------------
# Global variables
# ------------------------------------------------------------------------------
session_name=$(jq -r ".session.name" "$json_file")
root_path=$(jq -r ".session.root" "$json_file")

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
if [[ " ${cmds[@]} " =~ " remove " ]]; then
  echo "Remove session..."
  tmux kill-session -t "$session_name"
fi

if [[ " ${cmds[@]} " =~ " create " ]] && ! tmux ls | grep "$session_name"; then
  echo "Create session..."
  tmux -2 new-session -d -s "$session_name"

  base_index=$(tmux show-options -gv base-index)

  idx="$base_index"
  IFS=$'\n'

  for window in $(jq -cr ".windows[]" "$json_file"); do
    name=$(echo "$window" | jq -r ".name")
    rel_path=$(echo "$window" | jq -r ".path")
    path="${root_path:-/}/${rel_path}"
    cmd=$(echo "$window" | jq -r ".cmd")

    if [ "$idx" -eq "$base_index" ]; then
      # tmux creates one window by default
      tmux rename-window -t "$idx" "$name"
    else
      tmux new-window -t "$session_name:$idx" -n "$name" -c "$path"
    fi

    tmux send-keys -t "$idx" "cd $path" C-m C-l

    if [ -n "$cmd" ] && [[ " ${cmds[@]} " =~ " run " ]]; then
      tmux send-keys -t "$idx" "$cmd" C-m
    fi

    ((idx++))
  done

  unset IFS
fi

if [[ " ${cmds[@]} " =~ " attach " ]]; then
  echo "Attach to session..."
  tmux attach -t "$session_name"
fi

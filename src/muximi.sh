#!/usr/bin/env bash
#===============================================================================
#
#         NAME: muximi.sh
#
#        USAGE: muximi.sh [config file] [create,attach,remove]
#
#  DESCRIPTION: Creates and congfigures a tmux session based on a JSON config
#               file.
#
# REQUIREMENTS: jq, tmux
#      VERSION: 0.2.0
#
#===============================================================================

set -o errexit
set -o pipefail
set -o nounset

readonly ARGS=("$@")
# readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# readonly FILE="${DIR}/$(basename "${BASH_SOURCE[0]}")"

usage() {
  echo "Start a Tmux session preconfigured with a JSON file."
  echo ""
  echo "  usage : $0 [config file] [comma separated commands]"
  echo ""
  echo "    Possible commands are:"
  echo "      - create ... Create new session."
  echo "      - attach ... Attach to session."
  echo "      - remove ... Remove session."
}

session_exists() {
  tmux ls 2>/dev/null | grep -q "$1"
}

command_exists() {
  local rest="${@:2}"

  printf "%s\n" "${rest[@]}" | grep -q "$1"
}

create_session() {
  tmux -2 new-session -d -s "$1"
}

attach_session() {
  tmux attach -t "$1"
}

remove_session() {
  tmux kill-session -t "$1" 2>/dev/null
}

create_windows() {
  local windows
  local base_index
  local idx

  windows="$1"
  base_index=$(tmux show-options -gv base-index)
  idx="$base_index"

  IFS=$'\n'

  for window in ${windows}
  do
      local name
      local rel_path
      local path
      local cmd

      name=$(echo "$window" | jq -r ".name")
      rel_path=$(echo "$window" | jq -r ".path")
      path="${root_path:-/}/${rel_path}"
      cmd=$(echo "$window" | jq -r ".cmd")


      if [ "$idx" -eq "$base_index" ]
      then
        # tmux creates one window by default
        tmux rename-window -t "$idx" "$name"
      else
        tmux new-window -t "$session_name:$idx" -n "$name" -c "$path"
      fi

      tmux send-keys -t "$idx" "cd $path" C-m C-l

      if [ -n "$cmd" ]
      then
        tmux send-keys -t "$idx" "$cmd" C-m
      fi

      ((idx++))
    done

    unset IFS
}

main() {
  local json_file
  local cmds
  local session_name
  local root_path

  json_file="$1"
  cmds=($(echo "$2" | tr "," "\n"))
  session_name=$(jq -r ".session.name" "$json_file")
  root_path=$(jq -r ".session.root" "$json_file")

  if command_exists "remove" "${cmds[@]}" && session_exists "$session_name"
  then
    echo "Remove session '${session_name}'..."
    remove_session "${session_name}"
  fi

  if command_exists "create" "${cmds[@]}" && ! session_exists "$session_name"
  then
    echo "Create session '${session_name}'..."

    create_session "${session_name}"

    windows=$(jq -cr ".windows[]" "$json_file")
    create_windows "${windows}"
  fi

  if command_exists "attach" "${cmds[@]}" && session_exists "$session_name"
  then
    echo "Attach to session '${session_name}'..."
    attach_session "$session_name"
  fi
}

[ $# -ne 2 ] && {
  usage
  exit 1
}

main "${ARGS[@]}"

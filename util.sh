#!/bin/bash

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR -C"
k8s::scp()
{
  local host="$1"
  local src=($2)
  local dst="$3"
  scp -r ${SSH_OPTS} ${src[*]} "${host}:${dst}"
}
k8s::ssh()
{
  local host="$1"
  local cmd="$2"
  shift
  ssh ${SSH_OPTS} -t "${host}" "${cmd}" >/dev/null 2>&1
}
k8s:ssh_nowait()
{
  local host="$1"
  shift
  ssh ${SSH_OPTS} -t "${host}" "nohup $@" >/dev/null 2>&1 &
}

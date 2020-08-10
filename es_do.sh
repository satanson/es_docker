#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

source ${basedir}/functions.sh
source ${basedir}/es_ops.sh

cluster_op(){
  yellow_print "cmd: "
  cmd=$(selectOption "start" "restart" "stop" "bootstrap" "destroy")
  green_print "exec: ${cmd}_${service}"
  confirm
  ${cmd}_${service}
}

service_op(){
  yellow_print "cmd: "
  cmd=$(selectOption "restart" "restart_all" "stop" "stop_all" "start" "start_all" "bootstrap" "bootstrap_all" "destroy" "destroy_all")
  if isIn ${cmd} "restart_all|stop_all|start_all|bootstrap_all|destroy_all";then
    green_print "exec: ${cmd}_${service}"
    confirm
    ${cmd}_${service}
  elif isIn ${cmd} "restart|stop|start|bootstrap|destroy";then
    yellow_print "node: "
    if isIn ${service} "es_master";then
      node=$(selectOption ${es_master_list})
    elif isIn ${service} "es_data";then
      node=$(selectOption ${es_data_list})
    elif isIn ${service} "es_coord";then
      node=$(selectOption ${es_coord_list})
    fi
    green_print "exec: ${cmd}_${service} ${node}"
    confirm
    ${cmd}_${service} ${node}
  fi
}

op(){
  yellow_print "service: "
  service=$(selectOption "es_cluster" "es_master" "es_data" "es_coord")
  if isIn ${service} "es_cluster";then
    cluster_op
  else
    service_op
  fi
}

op

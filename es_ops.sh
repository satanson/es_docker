#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
test  ${basedir} == ${PWD}
esLocalRoot=$(cd ${basedir}/../es_all/elasticsearch;pwd)
esDockerRoot=/home/hdfs/es

es_master_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(es_master\d+)\s*$/' ${PWD}/hosts )
es_data_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(es_data\d+)\s*$/' ${PWD}/hosts )
es_coord_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(es_coord\d+)\s*$/' ${PWD}/hosts )

master_csv=$(perl -e "print join qq/,/,qw/${es_master_list}/")
zenPingUnicastHosts="-Ediscovery.zen.ping.unicast.hosts=${master_csv}"
initialMasterNodes="-Ecluster.initial_master_nodes=${master_csv}"

es_master_args="
  -Enode.master=true
  -Enode.voting_only=false
  -Enode.data=false
  -Enode.ingest=false
  -Enode.ml=false
  -Expack.ml.enabled=true
  -Enode.transform=false
  -Enode.remote_cluster_client=false
  ${zenPingUnicastHosts}
  "

es_data_args="
  -Enode.master=false
  -Enode.voting_only=false
  -Enode.data=true
  -Enode.ingest=false
  -Enode.ml=false
  -Enode.transform=false
  -Enode.remote_cluster_client=false
  ${zenPingUnicastHosts}
  "

es_coord_args="
  -Enode.master=false 
  -Enode.voting_only=false 
  -Enode.data=false 
  -Enode.ingest=true
  -Enode.ml=false
  -Enode.transform=false
  -Enode.remote_cluster_client=false
  ${zenPingUnicastHosts}
  "

dockerFlags="-tid --rm -u hdfs -w ${esDockerRoot} --privileged --net static_net0 -v ${PWD}/hosts:/etc/hosts -v ${esLocalRoot}:${esDockerRoot}"

stop_node(){
  local name=$1;shift
  set +e +o pipefail
  docker kill ${name}
  docker rm ${name}
  set -e -o pipefail
}

## es-fe

stop_es_node_args(){
  local node=${1:?"undefined 'es_master'"};shift
  local finalize=${1:-"false"}
  stop_node ${node}
  if [ "x${finalize}x" != 'xfalsex' ];then
    datadir=${node}_data
    logdir=${node}_logs
    for dir in $(eval "echo ${node}_{data,logs}");do
      [ -d "${dir}" ] && rm -fr ${dir:?"undefined"}
    done
  fi
}

start_es_node_args(){
  local node=${1:?"undefined 'node'"};shift
  local bootstrap=${1:-"false"};shift;
  local ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)

  local nodeType=$(perl -e "print \$1 if qq/${node}/=~/^([^\d]+)\d+$/")
  local nodeConfigDir=""
  for configDir in $(eval "echo {${node}_config,${nodeType}_config,config}");do
    if [ -d "${configDir}" ];then
      nodeConfigDir=${configDir}
    fi
  done
  if [ -z "${nodeConfigDir}" ]; then
    red_print "Node config directory not exists" >&2
    exit 1
  fi

  local flags="
  -v ${PWD}/${node}_data:${esDockerRoot}/data
  -v ${PWD}/${node}_logs:${esDockerRoot}/logs
  -v ${PWD}/${nodeConfigDir}:${esDockerRoot}/config
  --name $node
  --hostname $node
  -e JAVA_HOME=${esDockerRoot}/jdk
  -e PATH=${esDockerRoot}/jdk/bin:/usr/local/bin/:/usr/bin/:/bin:/usr/sbin:/sbin
  --ip $ip
  "

  local args=$(eval "echo \${${nodeType}_args:?"undefined"}")
  echo "nodeType=${nodeType}"
  echo "master_args=${master_args}"
  echo "data_args=${data_args}"
  echo "coord_args=${coord_args}"
  [ -d "${node}_logs" ] && rm -fr ${node:?"undefined"}_logs
  if [ "x${bootstrap}x" != "xfalsex" ];then
    [ -d "${PWD}/${node}_data" ] &&  rm -fr ${PWD}/${node}_data/*
    args="${args} ${initialMasterNodes}"
  fi
  mkdir -p ${PWD}/${node}_logs
  mkdir -p ${PWD}/${node}_data

  # run docker
  green_print docker run ${dockerFlags} ${flags} hadoop_debian:8.8 ${esDockerRoot}/bin/elasticsearch ${args}
  docker run ${dockerFlags} ${flags} hadoop_debian:8.8 ${esDockerRoot}/bin/elasticsearch ${args}
}

stop_es_master(){
  stop_es_node_args ${1:?"missing 'node'"} "false"
}

destroy_es_master(){
  stop_es_node_args ${1:?"missing 'node'"} "true"
}

do_all(){
  local func=${1:?"missing 'func'"}
  set -- $(perl -e "print qq/\$1 \$2/ if qq/${func}/ =~ /^(\\w+)_all_(\\w+)\$/")
  local cmd=${1:?"missing 'cmd'"};shift
  local nodeType=${1:?"missing 'nodeType'"};shift
  green_print "BEGIN: ${func}"
  for node in $(eval "echo \${${nodeType}_list}"); do
    green_print "run: ${cmd}_${nodeType} ${node}"
    ${cmd}_${nodeType} ${node}
  done
  green_print "END: ${func}"
}

stop_all_es_master(){ do_all ${FUNCNAME};}
destroy_all_es_master(){ do_all ${FUNCNAME};}


bootstrap_es_master(){
  start_es_node_args ${1:?"undefined 'node'"} "true"
}

bootstrap_all_es_master(){ do_all ${FUNCNAME};}

start_es_master(){
  start_es_node_args ${1:?"undefined 'node'"} "false"
}

start_all_es_master(){ do_all ${FUNCNAME};}

restart_es_master(){
  local node=${1:?"undefined 'es_master'"};shift
  stop_es_master ${node}
  start_es_master ${node}
}

restart_all_es_master(){ do_all ${FUNCNAME};}

stop_es_data(){
  stop_es_node_args ${1:?"missing 'node'"} "false"
}

destroy_es_data(){
  stop_es_node_args ${1:?"missing 'node'"} "true"
}

bootstrap_es_data(){
  start_es_node_args ${1:?"missing 'node'"} "true"
}


start_es_data(){
  start_es_node_args ${1:?"missing 'node'"} "false"
}

restart_es_data(){
  local node=$1;shift
  stop_node ${node}
  start_es_data ${node}
}

stop_all_es_data(){ do_all ${FUNCNAME};}
destroy_all_es_data(){ do_all ${FUNCNAME};}
bootstrap_all_es_data(){ do_all ${FUNCNAME};}
start_all_es_data(){ do_all ${FUNCNAME};}
restart_all_es_data(){ do_all ${FUNCNAME};}

#############################################################################
## es coordinator

stop_es_coord(){
  stop_es_node_args ${1:?"missing 'node'"} "false"
}

destroy_es_coord(){
  stop_es_node_args ${1:?"missing 'node'"} "true"
}

bootstrap_es_coord(){
  start_es_node_args ${1:?"missing 'node'"} "true"
}

start_es_coord(){
  start_es_node_args ${1:?"missing 'node'"} "false"
}

restart_es_coord(){
  stop_es_coord ${1:?"mssing 'node'"}
  start_es_coord $1
}

stop_all_es_coord(){ do_all ${FUNCNAME};}
destroy_all_es_coord(){ do_all ${FUNCNAME};}
bootstrap_all_es_coord(){ do_all ${FUNCNAME};}
start_all_es_coord(){ do_all ${FUNCNAME};}
restart_all_es_coord(){ do_all ${FUNCNAME};}

## cluster
start_es_cluster(){
  start_all_es_master
  start_all_es_data
  start_all_es_coord
}

stop_es_cluster(){
  stop_all_es_coord
  stop_all_es_data
  stop_all_es_master
}

restart_es_cluster(){
  restart_all_es_coord
  restart_all_es_data
  restart_all_es_master
}

bootstrap_es_cluster(){
  stop_es_cluster
  for fe in ${es_master_follower_list};do
    bootstrap_es_master ${fe}
    sleep 20
  done

  for fe in ${es_master_observer_list};do
    bootstrap_es_master ${fe}
  done

  sleep 5

  bootstrap_all_es_data
  bootstrap_all_es_coord
}

destroy_es_cluster(){
  destroy_all_es_coord
  destroy_all_es_data
  destroy_all_es_master
}

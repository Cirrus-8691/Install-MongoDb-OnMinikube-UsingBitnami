#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)
underline=$(tput smul)
red=$(tput setaf 1)
white=$(tput setaf 7)

if ! [ $# -eq 1 ]; then
  echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "┃${white} 🔥FATAL ERROR: No arguments supplied for ${bold}${underline}PROJECT_NAME${normal}"
  echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
  exit 1
fi

PROJECT_NAME=$1
PACKAGE_NAME="mongodb"
NAMESPACE="$PROJECT_NAME-$PACKAGE_NAME"

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "┃ 🔵  Restaure MongoDb"
echo "┃────────────────────────────────────────────"
echo "┃ 🔷  Parameters"
echo "┃────────────────────────────────────────────"
echo "┃ 🔹  Package  = "$PACKAGE_NAME
echo "┃ 🔹  Namespace= "$FIND_NAMESPACE
NAMESPACE_FOUND=$(microk8s kubectl get namespace | grep $FIND_NAMESPACE)
if [[ "$NAMESPACE_FOUND" == *"$FIND_NAMESPACE"* ]]; then

    POD_NAME=$(microk8s kubectl -n $FIND_NAMESPACE get pod -o jsonpath={.items..metadata.name})
    MONGODB_USER=$(microk8s kubectl -n $FIND_NAMESPACE get pod -o jsonpath={.items..spec.containers..env[1]..value})
    MONGODB_DATABASE=$(microk8s kubectl -n $FIND_NAMESPACE get pod -o jsonpath={.items..spec.containers..env[2]..value})
    MONGODB_PASSWORD=$(microk8s kubectl -n $FIND_NAMESPACE get secret mongodb -o jsonpath="{.data.mongodb-passwords}" | base64 -d | awk -F',' '{print $1}')

    MASTER_PVC=$(microk8s kubectl -n $FIND_NAMESPACE get pod $POD_NAME -o jsonpath={.spec.volumes..persistentVolumeClaim.claimName})
    # ex: MASTER_PVC=redis-data-mongodb-master-0
    MASTER_PV=$(microk8s kubectl -n $FIND_NAMESPACE get pvc $MASTER_PVC -o jsonpath={.spec.volumeName})
    # ex : MASTER_PV=mongodb-pv-2
    MASTER_PV_HOSTPATH=$(microk8s kubectl -n $FIND_NAMESPACE get pv $MASTER_PV -o jsonpath={.spec.hostPath.path})
    # ex: MASTER_PV_HOSTPATH=/storage/data-mongodb-pv-2
    echo "┃────────────────────────────────────────────"
    echo "┃ 🔹 Pod name = "$POD_NAME
    echo "┃ 🔹 DATABASE = "$MONGODB_DATABASE
    echo "┃ 🔹 USER     = "$MONGODB_USER
    echo "┃ 🔹 PASSWORD = "$MONGODB_PASSWORD
    echo "┃────────────────────────────────────────────"
    echo "┃ 🟠 Copy dump to Pod Persistant Volume "
    echo "┃────────────────────────────────────────────"
    echo "┃ 🔹 PersistantVolumeClaim = "$MASTER_PVC
    echo "┃ 🔹 PersistantVolume      = "$MASTER_PV
    echo "┃ 🔹 HostPath              = "$MASTER_PV_HOSTPATH
    echo "┃────────────────────────────────────────────"
    ARCH_FROM_TO=/var/archives/$FIND_NAMESPACE
    echo "┃ 🔹 Dump cp from = "$ARCH_FROM_TO
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    mkdir $MASTER_PV_HOSTPATH/dump
    cp -r $ARCH_FROM_TO $MASTER_PV_HOSTPATH/dump
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Cannot cp to  ${bold}${underline}$MASTER_PV_HOSTPATH/dump${normal}"
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "┃ 🟠 Import dump"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # https://www.mongodb.com/docs/database-tools/mongorestore/
    microk8s kubectl -n $FIND_NAMESPACE exec $POD_NAME -- mongorestore -d $MONGODB_DATABASE --username=$MONGODB_USER --password=$MONGODB_PASSWORD /bitnami/mongodb/dump/$FIND_NAMESPACE/$MONGODB_DATABASE
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Cannot restore ${bold}${underline}/bitnami/mongodb/dump/$MONGODB_DATABASE${normal}"
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi

else
    echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "┃${white} 🔥FATAL ERROR: Cannot find namespace ${bold}${underline}$FIND_NAMESPACE${normal}"
    echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
    exit 1
fi

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "┃ 🟢 MongoDb 😀 ready"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
echo "┃ 🔵  Backup MongoDb"
echo "┃────────────────────────────────────────────"
echo "┃ 🔷  Parameters"
echo "┃────────────────────────────────────────────"
echo "┃ 🔹  Package  = "$PACKAGE_NAME
echo "┃ 🔹  Namespace= "$NAMESPACE

NAMESPACE_FOUND=$(kubectl get namespace | grep $NAMESPACE)
if [[ "$NAMESPACE_FOUND" == *"$NAMESPACE"* ]]; then

    POD_NAME=$(kubectl -n $NAMESPACE get pod -o jsonpath={.items..metadata.name})
    MONGODB_USER=$(kubectl -n $NAMESPACE get pod -o jsonpath={.items..spec.containers..env[1]..value})
    MONGODB_DATABASE=$(kubectl -n $NAMESPACE get pod -o jsonpath={.items..spec.containers..env[2]..value})
    MONGODB_PASSWORD=$(kubectl -n $NAMESPACE get secret mongodb -o jsonpath="{.data.mongodb-passwords}" | base64 -d | awk -F',' '{print $1}')

    MASTER_PVC=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath={.spec.volumes..persistentVolumeClaim.claimName})
    # ex: MASTER_PVC=redis-data-mongodb-master-0
    MASTER_PV=$(kubectl -n $NAMESPACE get pvc $MASTER_PVC -o jsonpath={.spec.volumeName})
    # ex : MASTER_PV=mongodb-pv-2
    MASTER_PV_HOSTPATH=$(kubectl -n $NAMESPACE get pv $MASTER_PV -o jsonpath={.spec.hostPath.path})
    # ex: MASTER_PV_HOSTPATH=/storage/data-mongodb-pv-2
    echo "┃────────────────────────────────────────────"
    echo "┃ 🔹 Pod name = "$POD_NAME
    echo "┃ 🔹 DATABASE = "$MONGODB_DATABASE
    echo "┃ 🔹 USER     = "$MONGODB_USER
    echo "┃────────────────────────────────────────────"
    echo "┃ 🔹 PersistantVolumeClaim = "$MASTER_PVC
    echo "┃ 🔹 PersistantVolume      = "$MASTER_PV
    echo "┃ 🔹 HostPath              = "$MASTER_PV_HOSTPATH
    echo "┃────────────────────────────────────────────"
    echo "┃ 🟠 Dumping all collections "
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ##################################################################################################
    # ATTENTION: ne pas effacer le répertoire: /tmp/hostpath-provisioner/$NAMESPACE/
    # ATTENTION: ne pas effacer le répertoire: /tmp/hostpath-provisioner/$NAMESPACE/mongodb
    # Remove OLNY previous DUMP
    rm -r $MASTER_PV_HOSTPATH/dump
    ##################################################################################################
    ##
    ## https://www.mongodb.com/docs/database-tools/mongodump/
    ##
    kubectl -n $NAMESPACE exec $POD_NAME -- mongodump -d $MONGODB_DATABASE --username=$MONGODB_USER --password=$MONGODB_PASSWORD -o /bitnami/mongodb/dump
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Cannot save ${bold}${underline}$POD_NAME${normal}"
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi
    ARCH_MV_TO=/var/archives/$NAMESPACE
    if ! [ -d $ARCH_MV_TO ]; then
        mkdir /var/archives/
        mkdir $ARCH_MV_TO
    else
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃ 🟠 Archive previous dump "
        echo "┃────────────────────────────────────────────"
        # export TODAY=$NAMESPACE$(date '+%Y-%m-%d_%H-%M-%S')
        # export PREVARCH_MV_TO=/var/archives/$TODAY
        PREVARCH_MV_TO1=/var/archives/$NAMESPACE-Previous
        PREVARCH_MV_TO2=/var/archives/$NAMESPACE-ToDelete
        if [ -d $PREVARCH_MV_TO1 ]; then
            echo "┃ ✳️  Move $PREVARCH_MV_TO1 to $PREVARCH_MV_TO2"
            rm -r $PREVARCH_MV_TO2
            mv $PREVARCH_MV_TO1 $PREVARCH_MV_TO2
        fi
        echo "┃ ✳️  Move $ARCH_MV_TO to $PREVARCH_MV_TO1"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        mv $ARCH_MV_TO $PREVARCH_MV_TO1
        mkdir $ARCH_MV_TO
    fi
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "┃ 🟢 Archive moved to "
    echo "┃────────────────────────────────────────────"
    DUMP_FROM=$MASTER_PV_HOSTPATH/dump/*
    echo "┃ ✳️  Move $DUMP_FROM to $ARCH_MV_TO"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    mv $DUMP_FROM $ARCH_MV_TO
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Cannot save ${bold}${underline}$MASTER_PV_HOSTPATH/dump${normal}"
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi
else
    echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "┃${white} 🔥FATAL ERROR: Cannot find namespace ${bold}${underline}$NAMESPACE${normal}"
    echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
    exit 1
fi

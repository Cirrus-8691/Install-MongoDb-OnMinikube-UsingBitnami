#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)
underline=$(tput smul)
red=$(tput setaf 1)
white=$(tput setaf 7)

if ! [ $# -eq 2 ]; then
  echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "┃${white} 🔥FATAL ERROR: No arguments supplied for ${bold}${underline}PROJECT_NAME, EXTERNAL_IP${normal}"
  echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
  exit 1
fi

PROJECT_NAME=$1
EXTERNAL_IP=$2

APP_INSTALLED="MongoDb"
PACKAGE_NAME="mongodb"
NAMESPACE="$PROJECT_NAME-$PACKAGE_NAME"

STORAGE_FOLDER="/storage"
PV_NAME=$PACKAGE_NAME"-pv-0"
PV_PATH=$STORAGE_FOLDER"/data-"$PV_NAME

echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "┃ 🔵  Install $APP_INSTALLED for project $PROJECT_NAME"
echo "┃────────────────────────────────────────────"
echo "┃ 🔷  Parameters"
echo "┃────────────────────────────────────────────"
echo "┃ 🔹 package    = "$PACKAGE_NAME
echo "┃ 🔹 namespace  = "$NAMESPACE
echo "┃ 🔹 externalIp = "$EXTERNAL_IP
echo "┃────────────────────────────────────────────"
echo "┃ 🔹 PersistentVolume name = "$PV_NAME
echo "┃ 🔹 PersistentVolume path = "$PV_PATH

NAMESPACE_FOUND=$(kubectl get namespace | grep $NAMESPACE)
if [[ "$NAMESPACE_FOUND" == *"$NAMESPACE"* ]]; then

    echo "┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "┃ 🟢  $APP_INSTALLED already installed for project $PROJECT_NAME"
    echo "┃────────────────────────────────────────────"
    echo "┃ 🟢 You do not have to restore data"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

else
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "🛂  Check PersistentVolume $PV_NAME"
    kubectl get pv $PV_NAME
    if ! [ $? -eq 0 ]; then

        echo "✨  Install StorageClass"
        kubectl apply -f ../storageclass.yaml
        if ! [ $? -eq 0 ]; then
            echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "┃${white} 🔥FATAL ERROR: Installing $APP_INSTALLED ${bold}${underline}StorageClass${normal}"
            echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
            exit 1
        fi

        echo "✨  Install PersistentVolume"
        kubectl apply -f ../values/$EXTERNAL_IP/pv-$PACKAGE_NAME.yaml
        if ! [ $? -eq 0 ]; then
            echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "┃${white} 🔥FATAL ERROR: Installing $APP_INSTALLED ${bold}${underline}PersistentVolume${normal} "
            echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
            exit 1
        fi

        echo "✨  Creating "$STORAGE_FOLDER
        mkdir $STORAGE_FOLDER
        echo "✨  Creating "$PV_PATH
        mkdir $PV_PATH
        chown -R 1001:1001 $PV_PATH
        chmod -R a+rwx $PV_PATH
    else
        echo "♻️  Recycle existing PersistentVolume"
        kubectl patch pv $PV_NAME -p '{"spec":{"claimRef": null}}'
        if ! [ $? -eq 0 ]; then
            echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "┃${white} 🔥FATAL ERROR: Recycling $APP_INSTALLED ${bold}${underline}PersistentVolume${normal} "
            echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
            exit 1
        fi
    fi

    echo "✨  Create Namespace "$NAMESPACE
    kubectl create ns $NAMESPACE
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Installing $APP_INSTALLED ${bold}${underline}Namespace${normal} "
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi

    echo "✨  Install $APP_INSTALLED"
    helm -n $NAMESPACE install $PACKAGE_NAME bitnami/$PACKAGE_NAME -f ../values/$EXTERNAL_IP/$PACKAGE_NAME.yaml
    if ! [ $? -eq 0 ]; then
        echo "${red}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃${white} 🔥FATAL ERROR: Installing $APP_INSTALLED ${bold}${underline}$PACKAGE_NAME${normal} "
        echo "${red}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${white}"
        exit 1
    fi
fi

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "┃ 🟢 $APP_INSTALLED ready 😀 "
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

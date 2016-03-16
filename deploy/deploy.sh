#!/bin/bash

# Stache Deployment Script
# Originally based on KUDU Deployment Script v0.1.11
# Ultimately, we removed some conditions that would never be true for us.

# Catches errors
exitWithMessageOnError () {
  if [ ! $? -eq 0 ]; then
    echo "An error has occurred during web site deployment."
    echo $1
    notifySlack "Stache build error: $1"
    exit 1
  fi
}

# If specified, notifies the Slack API
notifySlack() {
  echo $1
  if [[ -n $SLACK_WEBHOOK ]]; then
    curl -X POST --data-urlencode 'payload={"text":"['"$WEBSITE_SITE_NAME"'] '"$1"'"}' $SLACK_WEBHOOK
  fi
}

# Necessary in the Azure Environment
setup () {
  SCRIPT_DIR="${BASH_SOURCE[0]%\\*}"
  SCRIPT_DIR="${SCRIPT_DIR%/*}"
  ARTIFACTS=$SCRIPT_DIR/../artifacts
  KUDU_SYNC_CMD=${KUDU_SYNC_CMD//\"}

  if [[ ! -n "$DEPLOYMENT_SOURCE" ]]; then
    DEPLOYMENT_SOURCE=$SCRIPT_DIR
  fi

  if [[ ! -n "$NEXT_MANIFEST_PATH" ]]; then
    NEXT_MANIFEST_PATH=$ARTIFACTS/manifest

    if [[ ! -n "$PREVIOUS_MANIFEST_PATH" ]]; then
      PREVIOUS_MANIFEST_PATH=$NEXT_MANIFEST_PATH
    fi
  fi

  if [[ ! -n "$DEPLOYMENT_TARGET" ]]; then
    DEPLOYMENT_TARGET=$ARTIFACTS/wwwroot
  else
    KUDU_SERVICE=true
  fi

  if [[ ! -n "$KUDU_SYNC_CMD" ]]; then
    # Install kudu sync
    echo Installing Kudu Sync
    npm install kudusync -g --silent
    exitWithMessageOnError "npm failed"

    if [[ ! -n "$KUDU_SERVICE" ]]; then
      # In case we are running locally this is the correct location of kuduSync
      KUDU_SYNC_CMD=kuduSync
    else
      # In case we are running on kudu service this is the correct location of kuduSync
      KUDU_SYNC_CMD=$APPDATA/npm/node_modules/kuduSync/bin/kuduSync
    fi
  fi
}

# Necessary in the Azure Environment
selectNodeVersion () {
  if [[ -n "$KUDU_SELECT_NODE_VERSION_CMD" ]]; then
    SELECT_NODE_VERSION="$KUDU_SELECT_NODE_VERSION_CMD \"$DEPLOYMENT_SOURCE\" \"$DEPLOYMENT_TARGET\" \"$DEPLOYMENT_TEMP\""
    eval $SELECT_NODE_VERSION
    exitWithMessageOnError "select node version failed"

    if [[ -e "$DEPLOYMENT_TEMP/__nodeVersion.tmp" ]]; then
      NODE_EXE=`cat "$DEPLOYMENT_TEMP/__nodeVersion.tmp"`
      exitWithMessageOnError "getting node version failed"
    fi

    if [[ -e "$DEPLOYMENT_TEMP/.tmp" ]]; then
      NPM_JS_PATH=`cat "$DEPLOYMENT_TEMP/__npmVersion.tmp"`
      exitWithMessageOnError "getting npm version failed"
    fi

    if [[ ! -n "$NODE_EXE" ]]; then
      NODE_EXE=node
    fi

    NPM_CMD="\"$NODE_EXE\" \"$NPM_JS_PATH\""
  else
    NPM_CMD=npm
    NODE_EXE=node
  fi
}

# Runs the specified install command if the specified config exists.
install() {
  if [ -e "$DEPLOYMENT_SOURCE/package.json" ]; then
    eval $NPM_CMD install grunt-cli
    eval $NPM_CMD install
    exitWithMessageOnError "npm install failed"
  fi
}

# Runs the stache build command
# Supports deployment modes
build() {
  if [ -e "$DEPLOYMENT_SOURCE/Gruntfile.js" ]; then

    DEPLOY_MODE_UCASE="$(echo $DEPLOY_MODE | tr '[:lower:]' '[:upper:]')"
    case $DEPLOY_MODE_UCASE in
        "PROD") DEPLOY_FLAGS="--config=stache.yml,stache.prod.yml";;
        *) DEPLOY_FLAGS="";;
    esac

    grunt build $DEPLOY_FLAGS
    exitWithMessageOnError "stache build failed"
  fi
}

# Syncs the stache build output to the deployment target
sync() {
  "$KUDU_SYNC_CMD" -v 500 -f "$DEPLOYMENT_SOURCE/build" -t "$DEPLOYMENT_TARGET" -n "$NEXT_MANIFEST_PATH" -p "$PREVIOUS_MANIFEST_PATH" -i ".git;.hg;.deployment;deploy.sh"
  exitWithMessageOnError "Kudu Sync to Target failed"
}

# MAIN ENTRY POINT
notifySlack "Stache build started."
setup
selectNodeVersion
install
build
sync
notifySlack "Stache build successfully completed."
# MAIN ENTRY POINT

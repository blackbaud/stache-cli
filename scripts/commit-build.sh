#!/bin/bash

# ======================================================
# Fail the build if this step encounters an error
# ======================================================
set -e

# ======================================================
# Abort commit if building a pull request
# ======================================================
if [[ "$TRAVIS_EVENT_TYPE" == "pull_request" ]]; then
  exit 0
fi

# ======================================================
# Defaults for environment variables
# ======================================================
if [[ ! -n "$STACHE_DEPLOY_TEST_BRANCH" ]]; then
  STACHE_DEPLOY_TEST_BRANCH="deploy"
fi
if [[ ! -n "$STACHE_DEPLOY_PROD_BRANCH" ]]; then
  STACHE_DEPLOY_PROD_BRANCH="deploy"
fi
if [[ ! -n "$STACHE_MASTER_BRANCH" ]]; then
  STACHE_MASTER_BRANCH="master"
fi
if [[ ! -n "$STACHE_DEVELOP_BRANCH" ]]; then
  STACHE_DEVELOP_BRANCH="master"
fi

# ======================================================
# Configure GitHub user
# ======================================================
git config --global user.email "stache-build-user@blackbaud.com"
git config --global user.name "Blackbaud Stache Build User"

# ======================================================
# Commits the build results to a given branch
# ======================================================
commit_build() {
  echo "Committing build results to ${1}..."
  git status --short
  git add --all
  if ! git diff-index --quiet HEAD --; then
    git stash save
    git checkout $1 --quiet || git checkout -b $1
    git stash pop
    git add --all
    git commit -am "Built via Travis Build #${TRAVIS_BUILD_NUMBER}"
    git push -fq origin $1
  else
    echo "No changes detected. Aborting commit."
  fi
  git status --short
  echo "Done."
}

# ======================================================
# Is the build asking to be committed to test?
# ======================================================
if [[ "$TRAVIS_BRANCH" == "$STACHE_DEVELOP_BRANCH" ]]; then
  echo "Commit build results to ${STACHE_DEPLOY_TEST_BRANCH} branch."
  commit_build $STACHE_DEPLOY_TEST_BRANCH

# ======================================================
# Is the build asking to be committed to prod?
# ======================================================
elif [[ "$TRAVIS_BRANCH" == "$STACHE_MASTER_BRANCH" ]]; then
  echo "Commit build results to ${STACHE_DEPLOY_PROD_BRANCH} branch."
  commit_build $STACHE_DEPLOY_PROD_BRANCH
fi

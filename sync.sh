#!/bin/bash

# bootstrapping: if keytab is lost, upload to
# https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/credentials/store/system/domain/_/
# then set Use secret text above and set Bindings > Variable (path to the file) as ''' + CRW_KEYTAB + '''
chmod 700 ''' + CRW_KEYTAB + ''' && chown ''' + USER + ''' ''' + CRW_KEYTAB + '''
# create .k5login file
echo "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" > ~/.k5login
chmod 644 ~/.k5login && chown ''' + USER + ''' ~/.k5login
echo "pkgs.devel.redhat.com,10.19.208.80 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAplqWKs26qsoaTxvWn3DFcdbiBxqRLhFngGiMYhbudnAj4li9/VwAJqLm1M6YfjOoJrj9dlmuXhNzkSzvyoQODaRgsjCG5FaRjuN8CSM/y+glgCYsWX1HFZSnAasLDuW0ifNLPR2RBkmWx61QKq+TxFDjASBbBywtupJcCsA5ktkjLILS+1eWndPJeSUJiOtzhoN8KIigkYveHSetnxauxv1abqwQTk5PmxRgRt20kZEFSRqZOJUlcl85sZYzNC/G7mneptJtHlcNrPgImuOdus5CW+7W49Z/1xqqWI/iRjwipgEMGusPMlSzdxDX4JzIx6R53pDpAwSAQVGDz4F9eQ==
" >> ~/.ssh/known_hosts

ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

# see https://mojo.redhat.com/docs/DOC-1071739
if [[ -f ~/.ssh/config ]]; then mv -f ~/.ssh/config{,.BAK}; fi
echo "
GSSAPIAuthentication yes
GSSAPIDelegateCredentials yes

Host pkgs.devel.redhat.com
User crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM
" > ~/.ssh/config
chmod 600 ~/.ssh/config

# initialize kerberos
export KRB5CCNAME=/var/tmp/crw-build_ccache
kinit "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" -kt ''' + CRW_KEYTAB + '''
klist # verify working

#########################################################################
#
#                     Check out sources
#
#########################################################################
cd ${WORKSPACE}/sources
  git checkout --track origin/''' + SOURCE_BRANCH + ''' || true
  export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
  git config user.email "jpinkney+web-terminal-release@gmail.com"
  git config user.name "Red Hat Web Terminal Release Bot"
  git config --global push.default matching
  SOURCE_SHA=$(git rev-parse HEAD)
cd ..

# fetch sources to be updated
DWNSTM_REPO="''' + DWNSTM_REPO + '''"
if [[ ! -d ${WORKSPACE}/targetdwn ]]; then git clone ssh://crw-build@pkgs.devel.redhat.com/${DWNSTM_REPO} targetdwn; fi
cd ${WORKSPACE}/targetdwn
  git checkout --track origin/''' + DWNSTM_BRANCH + ''' || true
  git config user.email jpinkney@REDHAT.COM
  git config user.name "Web-Terminal Build"
  git config --global push.default matching
  DWNSTM_SHA=$(git rev-parse HEAD)
cd ..

#########################################################################
#
#             Copy sources from upstream branch to dist-git
#
#########################################################################

# copy over the files
cp -r sources/* targetdwn/

cd targetdwn
if [[ \$(git diff --name-only) ]]; then # file changed
  git add .
  git commit -s -m "[sync] Updated from ''' + SOURCE_REPO + ''' @ ${SOURCE_SHA:0:8} " || true
  git push origin ''' + DWNSTM_BRANCH + ''' || true
  echo "[sync] Updated from ''' + SOURCE_REPO + ''' @ ${SOURCE_SHA:0:8} "
else
  echo "Source and downstream contents are the same. No need to sync"
fi
#!/usr/bin/env bash

# Originally from cpaas build render_templates file

export VERSION=0.13.0
export SUPPORTED_OCP_VERSIONS="v4.12-v4.20"

# Related images - will need to be kept updated with latest via component nudges
# See https://konflux.pages.redhat.com/docs/users/building/component-nudges.html
export VOLSYNC_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/volsync-tenant/volsync-0-13:32dd3dfbb582f00c2f6d83dff18d8b4304f9d5b2"

export OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC="registry.redhat.io/openshift4/ose-kube-rbac-proxy-rhel9:v4.17"

# ACM 2.14 doclink
export ACM_DOCLINK = "https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/business_continuity/business-cont-overview#volsync"

export MANIFESTS_DIR=/manifests
export METADATA_DIR=/metadata
export CSV_NAME="volsync.clusterserviceversion.yaml"
export CSV_FILE="${MANIFESTS_DIR}/${CSV_NAME}"

set -x
env

# Check the version we're trying to build matches volsync
vs_version=$(cat /tmp/version.mk | grep "^VERSION :=")
vs_version="${vs_version##* }"

echo "VolSync vs_version: ${vs_version}, VERSION: ${VERSION}"
if [[ "${vs_version}" != "${VERSION}" ]]; then
  echo "ERROR: version of volsync ${vs_version} does not match expected version: ${VERSION}"
  exit 2
fi

#env | grep _BUILD_INFO_JSON > BUILD_INFO_ENV

#if [[ -z "$CPAAS_PRODUCT_VERSION" ]]; then
#   echo "ERROR: Environment variable CPAAS_PRODUCT_VERSION not defined."
#   exit 2
#fi

## get the required environment variables that are set when merging change sets
# FIXME: may need to set some vars that were in render_vars (like SUPPORTED_OCP_VERSIONS)
#source render_vars

## Check for environment variables pertaining to images
#if [[ -z "$VOLSYNC_UPSTREAM_TAG" ]] ||
#   [[ -z "$VOLSYNC_VERSION_SANITIZED" ]] ||
#   [[ -z "$VOLSYNC_VERSION_UNSANITIZED" ]] ||
#   [[ -z "$SCRIPT_CLONE_URL" ]] ||
#   [[ -z "$SCRIPT_CLONE_SHA" ]]; then
#  echo "ERROR: All required environment variables not loaded"
#  echo "    VOLSYNC_UPSTREAM_TAG"
#  echo "    VOLSYNC_VERSION_SANITIZED"
#  echo "    VOLSYNC_VERSION_UNSANITIZED"
#  echo "    SCRIPT_CLONE_URL"
#  echo "    SCRIPT_CLONE_SHA"
#  exit 3
#fi

#??? check for "candidate" in version?
#export VERSION=${VERSION:-${CPAAS_PRODUCT_VERSION}}

## Check for environment variables pertaining to the bundle
#if [[ -z "$MANIFESTS_DIR" ]] ||
#   [[ -z "$METADATA_DIR" ]] ||
#   [[ -z "$TESTS_DIR" ]] ||
#   [[ -z "$SUPPORTED_OCP_VERSIONS" ]]; then
#  echo "ERROR: All required environment variables not loaded"
#  echo "    MANIFESTS_DIR"
#  echo "    METADATA_DIR"
#  echo "    TESTS_DIR"
#  echo "    SUPPORTED_OCP_VERSIONS"
#  exit 3
#fi

#script_target_dir="scripts"

#set -x

# Get our tools and unbound manifests from upstream.

#git config --global core.sshCommand 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
#git clone $SCRIPT_CLONE_URL $script_target_dir
#if [[ $? -ne 0 ]]; then
#   echo "ERROR: Could not clone upstream release repo."
#   exit 2
#fi

#cd $script_target_dir
#git checkout $SCRIPT_CLONE_SHA
#cd ..

## Ensure the e2e custom scorecard tests config.yaml is correct
#diffscorecardconfig=$(diff --ignore-space-change $script_target_dir/custom-scorecard-tests/config-downstream.yaml tests/scorecard/config.yaml)
#if [ -n "$diffscorecardconfig" ]; then
#  echo "$diffscorecardconfig"
#  echo "ERROR: tests/scorecard/config.yaml is out-of-date. Make sure the upstream custom-scorecard-tests/config-downstream.yaml matches."
#  exit 2
#fi

# Grab the directories from the script dir so that they can be copied into the final image
#rm -rf ./${MANIFESTS_DIR} ./${METADATA_DIR} ./${TESTS_DIR}
#mkdir -p ./${MANIFESTS_DIR} ./${METADATA_DIR} ./${TESTS_DIR} # Ensure that directories exist in case they are nested
#mv $script_target_dir/bundle/manifests/* ./${MANIFESTS_DIR}
#mv $script_target_dir/bundle/metadata/* ./${METADATA_DIR}
# mv $script_target_dir/bundle/tests ./${TESTS_DIR}

# Convert image references from quay.io (i.e. upstream) to downstream
# VOLSYNC_IMAGE_PULLSPEC : quay.io/backube/volsync:latest

#export VOLSYNC_IMAGE_PULLSPEC=$(echo ${VOLSYNC_VOLSYNC_BUILD_INFO_JSON} | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj["extra"]["image"]["index"]["pull"][1])')

if [ ! -f "${CSV_FILE}" ]; then
   echo "CSV file not found, the version or name might have changed on us!"
   exit 5
fi

# For backwards compatibility ... just in case, separately rip out docker.io
# as this is no longer used as of version 0.2.0.
sed -i \
	-e "s|quay.io/backube/volsync:latest|${VOLSYNC_IMAGE_PULLSPEC}|g" \
	-e 's|gcr.io/kubebuilder/kube-rbac-proxy:.*$|${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC}|g' \
	-e 's|quay.io/brancz/kube-rbac-proxy:.*$|${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC}|g' \
	"${CSV_FILE}"

# Convert volsync name to volsync-product in files
sed -i -e "s|volsync\\.v|volsync-product\\.v|g" "${CSV_FILE}"
sed -i -e "s|volsync|volsync-product|g" "${METADATA_DIR}/annotations.yaml"

# Add -product to the CSV name
export TARGET_CSV_FILE="${MANIFESTS_DIR}/${CSV_NAME%%.*}-product.${VERSION}.${CSV_NAME#*.}"

# Rename CSV file with version
mv "${CSV_FILE}" "${TARGET_CSV_FILE}"

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
#pip3 install --upgrade pip && pip3 install -r requirements.txt
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return

timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
volsync_csv = load_manifest(os.getenv('TARGET_CSV_FILE'))
volsync_csv['spec']['maintainers'] = [{'email': 'acm-contact@redhat.com', 'name': 'Red Hat ACM Team'}]
volsync_csv['spec']['provider']['name'] = 'Red Hat'
# Remove spec.relatedImages section as it is not needed in midstream build
del volsync_csv['spec']['relatedImages']
# Add arch support labels
volsync_csv['metadata']['labels'] = volsync_csv['metadata'].get('labels', {})
volsync_csv['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
volsync_csv['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
volsync_csv['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
volsync_csv['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
volsync_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
volsync_csv['metadata']['annotations']['support'] = 'Red Hat'
volsync_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
volsync_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'true'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
volsync_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
volsync_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '["OpenShift Platform Plus", "Red Hat Advanced Cluster Management for Kubernetes"]'
volsync_csv['metadata']['annotations']['repository'] = 'https://github.com/backube/volsync'
volsync_csv['metadata']['annotations']['containerImage'] = os.getenv('VOLSYNC_IMAGE_PULLSPEC', '')

# Update to use the ACM doclink 
acmdoclink = os.getenv('ACM_DOCLINK')

for doclink in volsync_csv['spec']['links']:
  if doclink['name'] == 'Documentation':
    doclink['url'] = acmdoclink

# Update description with ACM specific info
desc_extension = """

### Documentation

For documentation about installing and using the VolSync Operator with Red Hat Advanced Cluster Management for
Kubernetes, see [VolSync persistent volume replication service](%s) in the Red Hat Advanced Cluster Management
documentation.

For additional information about the VolSync project, including features that might not be supported by Red Hat, see
the [VolSync community](https://volsync.readthedocs.ioe/) documentation.

### Support & Troubleshooting

Product support, which includes Support Cases, Product Pages, and Knowledgebase articles, is available when you have
a [Red Hat Advanced Cluster Management](https://www.redhat.com/en/technologies/management/advanced-cluster-management)
subscription.
"""

desc_extension = desc_extension % (acmdoclink) # Replace acm doclink in string

volsync_csv['spec']['description'] = volsync_csv['spec']['description'] + desc_extension

upstream_version_sanitized = os.getenv('VERSION')
volsync_csv['metadata']['name'] = volsync_csv['metadata']['name'] = f"volsync-product.v{upstream_version_sanitized}"
volsync_csv['spec']['version'] = volsync_csv['spec']['version'] = upstream_version_sanitized
dump_manifest(os.getenv('TARGET_CSV_FILE'), volsync_csv)
CSV_UPDATE

# Add OCP annotations
python3 - << END
import os, yaml
with open(os.getenv('METADATA_DIR') + "/annotations.yaml", 'r') as f:
    y=yaml.safe_load(f) or {}
    y['annotations']['com.redhat.delivery.operator.bundle'] = True
    y['annotations']['com.redhat.openshift.versions'] = os.getenv('SUPPORTED_OCP_VERSIONS')
    y['annotations']['com.redhat.delivery.backport'] = False
with open(os.getenv('METADATA_DIR') + "/annotations.yaml", 'w') as f:
    yaml.dump(y, f)
END

cat ${TARGET_CSV_FILE}

## Fetch additional Labels
#label_lines="./tmp.label-lines"
## Bundle-image format requires some image labels which mirror those we've already
## generated (upstream) as metadata/annotations.yaml, including stuff that relates
## to publication channels. To avoid manual maintenance of stuff downstream, convert
## metadata/annotations.yaml into LABELS. So we:
##
## - Filter out the "annotations:" line
## - Convert all others to LABEL statement
#tail -n +2 "${METADATA_DIR}/annotations.yaml" | \
#  sed "s/: */=/" | sed "s/^ */LABEL /" >> "$label_lines"
#
## Write labels to Dockerfile
## But first, stash off the base Dockerfile so that we have a clean one to ammend
#df="./Dockerfile"
#df_stash="./Dockerfile.stashed"
#if [[ ! -f $df_stash ]]; then
#  cp $df $df_stash
#fi
#cp $df_stash $df
#
#cat "$df" |\
#  sed "/com.redhat.delivery.operator.bundle=true/r $label_lines" |
#  sed "0,/com.redhat.delivery.operator.bundle=true/{//d;}" > "./df.upd.tmp"
#mv -f "./df.upd.tmp" "$df"
#rm -f "$label_lines"
#
## Done with the script repo, remove so it doesn't get committed into dist-git.
#rm -rf $script_target_dir

#!/usr/bin/env bash

# Copyright 2019 The Knative Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

source $(dirname $0)/../vendor/knative.dev/hack/codegen-library.sh

# If we run with -mod=vendor here, then generate-groups.sh looks for vendor files in the wrong place.
export GOFLAGS=-mod=
# hack's codegen shell library overrides GOBIN
# we need it on the path so run_go_tool works
export PATH="${PATH}:${GOBIN}"


echo "=== Update Codegen for $MODULE_NAME"

group "Knative Codegen"

# Knative Injection (for istio)
${KNATIVE_CODEGEN_PKG}/hack/generate-knative.sh "injection" \
  knative.dev/net-istio/pkg/client/istio istio.io/client-go/pkg/apis \
  "networking:v1alpha3" \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate/boilerplate.go.txt

group "Kubernetes Codegen"

# Generate our own client for istio (otherwise injection won't work)
${CODEGEN_PKG}/generate-groups.sh "client,informer,lister" \
  knative.dev/net-istio/pkg/client/istio istio.io/client-go/pkg/apis \
  "networking:v1alpha3" \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate/boilerplate.go.txt

group "Deepcopy Gen"

# Depends on generate-groups.sh to install bin/deepcopy-gen
${GOPATH}/bin/deepcopy-gen \
  -O zz_generated.deepcopy \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate/boilerplate.go.txt \
  -i knative.dev/net-istio/pkg/reconciler/ingress/config \
  -i knative.dev/net-istio/pkg/defaults

group "Update deps post-codegen"

# Make sure our dependencies are up-to-date
${REPO_ROOT_DIR}/hack/update-deps.sh

group "Update istio generated manifests"

# We don't update HEAD since it changes regularly and we don't
# want our presubmit checks to fail because a diff occurred
# ${REPO_ROOT_DIR}/third_party/istio-head/generate_manifests.sh


# Update stable and latest cause the istioctl version seems to generate
# reproducible yaml. So let's check for unexpected diffs
${REPO_ROOT_DIR}/third_party/istio-stable/generate-manifests.sh
${REPO_ROOT_DIR}/third_party/istio-latest/generate-manifests.sh

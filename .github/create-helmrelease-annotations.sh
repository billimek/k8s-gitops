#!/usr/bin/env bash

# Wire up the env and cli validations
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
# source "${__dir}/environment.sh"

export CLUSTER_ROOT=$(git rev-parse --show-toplevel)

export helm_repositories="${CLUSTER_ROOT}/flux-system-extra/helm-chart-repositories"

for helm_release in $(find ${CLUSTER_ROOT} -name "*.yaml"); do
    # ignore flux-system namespace
    # ignore wrong apiVersion
    # ignore non HelmReleases
    if [[ "${helm_release}" =~ "flux-system"
        || $(yq r "${helm_release}" apiVersion) != "helm.toolkit.fluxcd.io/v2beta1"
        || $(yq r "${helm_release}" kind) != "HelmRelease" ]]; then
        continue
    fi

    for helm_repository in "${helm_repositories}"/*.yaml; do
        chart_name=$(yq r "${helm_repository}" metadata.name)
        chart_url=$(yq r "${helm_repository}" spec.url)

        # only helmreleases where helm_release is related to chart_url
        if [[ $(yq r "${helm_release}" spec.chart.spec.sourceRef.name) == "${chart_name}" ]]; then
            # delete "renovate: registryUrl=" line
            sed -i "/renovate: registryUrl=/d" "${helm_release}"
            # insert "renovate: registryUrl=" line
            sed -i "/.*chart: .*/i \ \ \ \ \ \ # renovate: registryUrl=${chart_url}" "${helm_release}"
            echo "Annotated $(basename "${helm_release%.*}") with ${chart_name} for renovatebot..."
            break
        fi
    done
done

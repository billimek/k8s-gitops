#!/usr/bin/env zx
$.verbose = false

/**
 * * helmReleaseDiff.mjs
 * * Runs `helm template` with your Helm values and then runs a diff tool across Flux HelmRelease manifests
 * @param --current-release   The source Flux HelmRelease to compare against the target
 * @param --incoming-release  The target Flux HelmRelease to compare against the source
 * @param --kubernetes-dir    The directory containing your Flux manifests including the HelmRepository manifests
 * @param --diff-tool         The tool to use for diffing (`diff` or `dyff`)
 * * Limitations:
 * * Does not work with multiple HelmRelease maninfests in the same YAML document
 */
const CurrentRelease  = argv['current-release']
const IncomingRelease = argv['incoming-release']
const KubernetesDir   = argv['kubernetes-dir']
const diffTool        = argv['diff-tool']

const helm      = await which('helm')
// const kustomize = await which('kustomize')

async function helmRelease(releaseFile) {
  const helmRelease = await fs.readFile(releaseFile, 'utf8')
  const doc = YAML.parseAllDocuments(helmRelease).map((item) => item.toJS())
  const release = doc.filter((item) =>
    item.apiVersion === 'helm.toolkit.fluxcd.io/v2beta1'
      && item.kind === 'HelmRelease'
  )
  return release[0]
}

async function helmRepositoryUrl(kubernetesDir, releaseName) {
  const files = await globby([`${kubernetesDir}/**/*.yaml`])
  for await (const file of files) {
    const contents = await fs.readFile(file, 'utf8')
    const doc = YAML.parseAllDocuments(contents).map((item) => item.toJS())
    if (doc.length > 0 && 'apiVersion' in doc[0] && doc[0].apiVersion === 'source.toolkit.fluxcd.io/v1beta2'
        && 'kind' in doc[0] && doc[0].kind === 'HelmRepository'
        && 'metadata' in doc[0] && 'name' in doc[0].metadata && doc[0].metadata.name === releaseName)
    {
      return doc[0].spec.url
    }
  }
}

async function helmBuild(releaseFile, releaseName) {
  const helmRelease = await fs.readFile(releaseFile, 'utf8')
  const doc = YAML.parseAllDocuments(helmRelease).map((item) => item.toJS())
  const release = doc.filter((item) =>
    item.apiVersion === 'helm.toolkit.fluxcd.io/v2beta1'
      && item.kind === 'HelmRelease'
        && item.metadata.name === releaseName
  )
  return release[0]
}

async function helmRepoAdd (registryName, registryUrl) {
  await $`${helm} repo add ${registryName} ${registryUrl}`
}

async function helmTemplate (releaseName, registryName, chartName, chartVersion, chartValues) {
  const values = new YAML.Document()
  values.contents = chartValues
  const valuesFile = await $`mktemp`
  await fs.writeFile(valuesFile.stdout.trim(), values.toString())

  const manifestsFile = await $`mktemp`
  const manifests = await $`${helm} template --kube-version 1.24.8 --release-name ${releaseName} --include-crds=false ${registryName}/${chartName} --version ${chartVersion} --values ${valuesFile.stdout.trim()}`

  // Remove docs that are CustomResourceDefinition and keys which contain generated fields
  let documents = YAML.parseAllDocuments(manifests.stdout.trim())
  documents = documents.filter(doc => doc.get('kind') !== 'CustomResourceDefinition')
  documents.forEach(doc => {
    const del = (path) => doc.hasIn(path) ? doc.deleteIn(path) : false
    del(['metadata', 'labels'])
    del(['spec', 'template', 'metadata', 'annotations'])
    del(['spec', 'template', 'metadata', 'labels'])
  })

  await fs.writeFile(manifestsFile.stdout.trim(), documents.map(doc => doc.toString({directives: true})).join('\n'))
  return manifestsFile.stdout.trim()
}

// Generate current template from Helm values
const currentRelease = await helmRelease(CurrentRelease)
if(currentRelease)
{
  const currentBuild = await helmBuild(CurrentRelease, currentRelease.metadata.name)
  const currentRepositoryUrl = await helmRepositoryUrl(KubernetesDir, currentBuild.spec.chart.spec.sourceRef.name)
  await helmRepoAdd(currentBuild.spec.chart.spec.sourceRef.name, currentRepositoryUrl)
  const currentManifests = await helmTemplate(
    currentBuild.metadata.name,
    currentBuild.spec.chart.spec.sourceRef.name,
    currentBuild.spec.chart.spec.chart,
    currentBuild.spec.chart.spec.version,
    currentBuild.spec.values
  )

  // Generate incoming template from Helm values
  const incomingRelease = await helmRelease(IncomingRelease)
  const incomingBuild = await helmBuild(IncomingRelease, incomingRelease.metadata.name)
  const incomingRepositoryUrl = await helmRepositoryUrl(KubernetesDir, incomingBuild.spec.chart.spec.sourceRef.name)
  await helmRepoAdd(incomingBuild.spec.chart.spec.sourceRef.name, incomingRepositoryUrl)
  const incomingManifests = await helmTemplate(
    incomingBuild.metadata.name,
    incomingBuild.spec.chart.spec.sourceRef.name,
    incomingBuild.spec.chart.spec.chart,
    incomingBuild.spec.chart.spec.version,
    incomingBuild.spec.values
  )

  if (diffTool === 'diff')
  {
    const diff_tool = await which('diff')
    const diff_out = await $`${diff_tool} -u ${currentManifests} ${incomingManifests} || :`
    echo(diff_out.stdout.trim())
  }
  else if (diffTool === 'dyff')
  {
    const dyff_tool = await which('dyff')
    const diff_out = await $`${dyff_tool} --color=off --truecolor=off between --omit-header --ignore-order-changes --detect-kubernetes=true --output=human ${currentManifests} ${incomingManifests}`
    echo(diff_out.stdout.trim())
  }
}

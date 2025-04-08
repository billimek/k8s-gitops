# grafana

![](https://i.imgur.com/hzBFkEE.png)

[Grafana](https://github.com/grafana/grafana) is a metrics and logging dashboard

* [grafana/grafana.yaml](grafana/grafana.yaml)
* [grafana/dashboards/](grafana/dashboards/)

# influxdb

[influxdb](https://github.com/influxdata/influxdb) is a metrics collection database

* [influxdb/influxdb.yaml](influxdb/influxdb.yaml)

# prometheus-rules

Various custom PrometheusRule definitions for this cluster

* [prometheus-rules/](prometheus-rules/)

# speedtest-exporter

![](https://i.imgur.com/avohPk6.png)

ISP speed test results collector

* [speedtest-exporter/speedtest-exporter.yaml](speedtest-exporter/speedtest-exporter.yaml)

# trivy

![](https://i.imgur.com/yvZ86z0.png)

Be depressed about how many vulnerabilities you have in your images

* [trivy/trivy.yaml](trivy/trivy.yaml)

# victoria metrics

![](https://i.imgur.com/ab4qB97.png)

VictoriaMetrics [k8s stack helm chart](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack) to take the place of kube-prometheus-stack helm chart & thanos for the same features/functionality but more stable and less resource intensive.

* [victoria-metrics/victoria-metrics.yaml](victoria-metrics/victoria-metrics.yaml)

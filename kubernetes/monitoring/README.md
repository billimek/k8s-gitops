# fluent-bit

[fluent-bit](https://fluentbit.io) is an agent which ships the contents of local logs to a victoria-logs instance

* [fluent-bit/fluent-bit.yaml](fluent-bit/fluent-bit.yaml)

# grafana

![](https://i.imgur.com/hzBFkEE.png)

[Grafana](https://github.com/grafana/grafana) is a metrics and logging dashboard

* [grafana/grafana.yaml](grafana/grafana.yaml)
* [grafana/dashboards/](grafana/dashboards/)

# prometheus-rules

Various custom PrometheusRule definitions for this cluster

* [prometheus-rules/](prometheus-rules/)

# speedtest-exporter

![](https://i.imgur.com/avohPk6.png)

ISP speed test results collector

* [speedtest-exporter/speedtest-exporter.yaml](speedtest-exporter/speedtest-exporter.yaml)

# victoria-logs

[victoria-logs](https://docs.victoriametrics.com/victorialogs/) is a logging system

* [victoria-logs/victoria-logs.yaml](victoria-logs/victoria-logs.yaml)

# victoria metrics

![](https://i.imgur.com/ab4qB97.png)

VictoriaMetrics [k8s stack helm chart](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack) to take the place of kube-prometheus-stack helm chart & thanos for the same features/functionality but more stable and less resource intensive.

* [victoria-metrics/victoria-metrics.yaml](victoria-metrics/victoria-metrics.yaml)

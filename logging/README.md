# loki

![](https://i.imgur.com/bdN7Grj.png)

https://github.com/grafana/loki

* [loki.yaml](loki.yaml)

# EFK stack

![](https://i.imgur.com/9u80N7l.png)

* [elasticsearch.yaml](elasticsearch.yaml) - elasticsearch - uses a TON of memory
* [fluentd.yaml](fluentd.yaml) - fluentd for collecting all container logs from the kubernetes cluster
* [kibana.yaml](kibana.yaml) - kibana log viewer UI
* [elasticsearch-curator.yaml](elasticsearch-curator.yaml) - removes any logs older than 30 days - if you don't explicitly prune logs, elasticsearch will run out of space and go into a read-only mode and it's non-trivial to recover from

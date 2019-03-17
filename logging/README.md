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

# remote syslog logging

![](https://i.imgur.com/SpDKmQg.png)

* [fluentd.yaml](fluentd.yaml) - fluentd (deployed as fluentd-syslog) for listening as a syslog server on UDP/5140 for collecting all syslog messages from all hosts external from the cluster
  * Configure the remote rsyslog daemon with something like, 
  
  ``` shell
  echo "*.* @10.2.0.104:5140" > /etc/rsyslog.d/10-fluentd.conf && service rsyslog restart
  ```

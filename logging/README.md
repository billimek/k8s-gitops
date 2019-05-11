# loki

![](https://i.imgur.com/bdN7Grj.png)

https://github.com/grafana/loki

* [loki.yaml](loki.yaml)

# EFK stack

![](https://i.imgur.com/9u80N7l.png)

* [elasticsearch.yaml](elasticsearch.yaml) - elasticsearch - uses a TON of memory
* [fluentd.yaml](fluentd.yaml) - fluentd for collecting all container logs from the kubernetes cluster
* [kibana.yaml](kibana.yaml) - kibana log viewer UI

## Elasticsearch index templates

See [index templates](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-templates.html) for details.  It appears that it is necessary to manually create index templatess for elasticsearch in order to apply [deletion policies](https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started-index-lifecycle-management.html).

This is what I have configured:

for `logstash-*`:

```json
PUT _template/logstash
{
  "index_patterns": ["logstash-*"],
}
```

for `fluentd-syslog-*`:

```json
PUT _template/fluentd-syslog
{
  "index_patterns": ["fluentd-syslog-*"],
}
```

# remote syslog logging

![](https://i.imgur.com/SpDKmQg.png)

* [fluentd.yaml](fluentd.yaml) - fluentd (deployed as fluentd-syslog) for listening as a syslog server on UDP/5140 for collecting all syslog messages from all hosts external from the cluster
  * Configure the remote rsyslog daemon with something like, 
  
  ``` shell
  echo "*.* @10.2.0.104:5140" > /etc/rsyslog.d/10-fluentd.conf && service rsyslog restart
  ```

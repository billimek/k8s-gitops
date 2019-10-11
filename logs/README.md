# loki

![](https://i.imgur.com/bdN7Grj.png)

https://github.com/grafana/loki

* [loki/loki.yaml](loki/loki.yaml)

# EFK stack (CURRENTLY DISABLED)

![](https://i.imgur.com/9u80N7l.png)

* [elasticsearch.yaml](elasticsearch/elasticsearch.yaml) - elasticsearch - uses a TON of memory
* [fluentd.yaml](fluentd/fluentd.yaml) - fluentd for collecting all container logs from the kubernetes cluster
* [kibana.yaml](kibana/kibana.yaml) - kibana log viewer UI

## Elasticsearch index templates

See [index templates](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-templates.html) for details.  It appears that it is necessary to manually create index templatess for elasticsearch in order to apply [deletion policies](https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started-index-lifecycle-management.html).

This is what I have configured for elasticsearch:

### New `delete-after-30-days` ILM policy

```json
PUT _ilm/policy/delete-after-30d
{
  "delete-after-30d" : {
    "policy" : {
      "phases" : {
        "hot" : {
          "min_age" : "0ms",
          "actions" : {
            "set_priority" : {
              "priority" : 100
            }
          }
        },
        "delete" : {
          "min_age" : "30d",
          "actions" : {
            "delete" : { }
          }
        }
      }
    }
  }
}
```

### Index patterns

for `logstash-*`:

```json
PUT _template/logstash
{
  "index_patterns": ["logstash-*"]
}
```

for `fluentd-syslog-*`:

```json
PUT _template/fluentd-syslog
{
  "index_patterns": ["fluentd-syslog-*"]
}
```

... After creating the index patterns, it is necessary to 'apply' the index patterns to the newly-created ILM deletion policy so that all _new_ indexes created (with the above patterns) will have the policy automatically associated.

### Kibana saved search patterns

Import [saved_searches.ndjson](saved_searches.ndjson) to Kibana

# remote syslog logging (CURRENTLY DISABLED)

![](https://i.imgur.com/SpDKmQg.png)

* [fluentd.yaml](fluentd/fluentd-syslog.yaml) - fluentd (deployed as fluentd-syslog) for listening as a syslog server on UDP/5140 for collecting all syslog messages from all hosts external from the cluster
  * Configure the remote rsyslog daemon with something like, 
  
  ``` shell
  echo "*.* @10.2.0.104:5140" > /etc/rsyslog.d/10-fluentd.conf && service rsyslog restart
  ```

s/__PILLAR__DNS__SERVER__/<%= kubernetes_dns_ip %>/g
s/__PILLAR__DNS__REPLICAS__/1/g
s/__PILLAR__DNS__DOMAIN__/<%= domain %>/g
/__PILLAR__FEDERATIONS__DOMAIN__MAP__/d
s/__MACHINE_GENERATED_WARNING__/Warning: This is a file generated from the base underscore template file: __SOURCE_FILENAME__/g
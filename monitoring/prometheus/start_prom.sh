# Launch a docker container for Prometheus monitoring
# Attach it to the besrenet network so that it can communicate with other containers in the same network
docker run -d --name prometheus --network besrenet -p 9090:9090 -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
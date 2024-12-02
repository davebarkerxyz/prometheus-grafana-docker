# Setting up Grafana and Prometheus

## Prerequisites

You'll need `htpasswd` from Apache (install with `apt install apache2-utils`) and [cfssl](https://github.com/cloudflare/cfssl/) (install Go then download and compile with `go install github.com/cloudflare/cfssl/cmd/...@latest`) to follow along.

## Clone the basic container structure

`git clone https://github.com/davebarkerxyz/prometheus-grafana-docker.git`

## Generate passwords and set in config files

Run the `make-password.sh` script to generate random passwords that you'll then add to your config files:

- `./make-password.sh prometheus`
- `./make-password.sh node-exporter`

**Hold on to the output from these scripts - you'll need it for the following steps.**

Edit the *prometheus.yaml* file and replace *PROMETHEUS_PASSWORD* with the password for the *prometheus* user generated above. Replace *NODE_EXPORTER_PASSWORD* with the password for the *node-exporter* user generated above.

Edit *prometheus.web.yaml* and replace *HASHED_PASSWORD* with the hashed password for the *prometheus* user generated above.

Edit *node-exporter.web.yaml* and replace *HASHED_PASSWORD* with the hashed password for the *node-exporter* user generated above.

## Generate certificates

We'll need two certificates to get started: 

- A certificate for the Prometheus server (used for accessing the Prometheus web interface, and for Prometheus to scrape it's own metrics).
- A certificate for node_exporter (used to secure metrics API that Prometheus uses to scrape node metrics).

Technically, we don't need to turn on TLS for node_exporter as all communication occurs within the Docker custom network, but we do it in this case for consistency as we'll enable TLS for all of our other (off-network) node_exporter instances.

If you'd like to configure the certificate parameters (country, state, organisation, OU), edit *gen-cert.sh* (but this shouldn't be necessary as these certificates are all largely internal only).

*cd* into the *pki* folder and run `gen-cert.sh` as follows, substituting *YOUR-SERVER-HOSTNAME* for the hostname you'll use to access the Prometheus web UI in your browser:

- `./gen-cert.sh prometheus YOUR-SERVER-HOSTNAME`
- `./gen-cert.sh monitoring-node-exporter monitoring-node-exporter`

Each cert is valid for the hostname supplied, *localhost* and *127.0.0.1*.

Each certificate is generated with its own Certificate Authority (CA). We do this so that we can configure Prometheus and Grafana to essentially trust a single certificate CA for each host we're monitoring. By doing this, we can easily distrust a certificate (CA) if it's compromised by replacing the certificate in our Prometheus config, without having to set up and expose a traditional revocation system (like OCSP).

### Copy the certificates to the correct folders

Copy the certificates to your container as follows:

```
cp certs/prometheus/prometheus-ca.pem ../monitoring/certs/
cp certs/prometheus/prometheus.pem ../monitoring/certs/
cp certs/prometheus/prometheus-key.pem ../monitoring/certs/
cp certs/monitoring-node-exporter/monitoring-node-exporter-ca.pem ../monitoring/certs/
cp certs/monitoring-node-exporter/monitoring-node-exporter.pem ../monitoring/certs/
cp certs/monitoring-node-exporter/monitoring-node-exporter-key.pem ../monitoring/certs/
chmod 644 ../monitoring/certs/*
```

*Note: We change the permissions on the certs to 644 (world-readable). This is to allow the *nobody* user (which is used by the Prometheus and node_exporter containers) to read their private key from the bind mount. You may want to consider running the container as a separate user and chowning the private key to that user, rather than making it world readable.*

## Start the containers

You can now start the by *cd*ing into *monitoring* and running `docker compose up -d`.

You can access the Grafana web UI at your-server-hostname:9000 and the Prometheus web UI at your-server-hostname:9090.

The default Grafana username is *admin* and the password is *admin* - you'll be prompted to change this on first login.

## Configure Grafana

Open Grafana in your browser (your-server-hostname:9000) and go to *Connections*, *Data Sources*. Add a new Prometheus data source. Configure it as follows:

- Prometheus server URL: https://prometheus:9090
- Authentication type: Basic authentication
- Username: prometheus
- Password: *Password you generated earlier for the Prometheus user*
- Add self-signed certificate: Checked
- CA Certificate: *Paste from monitoring/certs/prometheus-ca.pem*

Click *Save & Test*.

## Check Prometheus targets

You can check your Prometheus targets (node_exports, and Prometheus' own service metrics) by visiting https://your-server-hostname:9000/targets. You'll receive a browser TLS security warning because your browser doesn't trust the Prometheus CA, and it's possible you're not accessing the server as *prometheus:9000*, *localhost:9000* or *127.0.0.1:9000*. This isn't a big issue, but in the long term you may went to look at the *gen-cert.sh* script and regenerate the certificate to include your server's hostname as a subject alternative name, or (more sensibly) put Prometheus and Grafana behind a Caddy reverse proxy with automatic Let's Encrypt TLS.

## Add the Node Exporter Full dashboard to Grafana

In Grafana, choose *Dashboards*, *New*, *Import* and import the Node Exporter Full dashboard from https://grafana.com/grafana/dashboards/1860-node-exporter-full/. Choose your default Prometheus service as the data source.

## 🎉 Congratulations

You've setup Grafana, Prometheus and node_exporter, all running in Docker and secured by per-service TLS certificates (without the overhead of running a traditional CA).

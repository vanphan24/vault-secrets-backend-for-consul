export VAULT_TOKEN=root

vault kv put secret/consul/gossip key='35FAhIVytwznTTk1bGuLs0nTpxQHUiGnWmxJ7ggcUKk='

vault policy write gossip-policy - <<EOF
path "secret/data/consul/gossip" {
  capabilities = ["read"]
}
EOF


vault auth enable kubernetes

vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault secrets enable -path=consul kv-v2

vault secrets enable pki

vault write auth/kubernetes/role/consul-server \
    bound_service_account_names=consul-consul-server \
    bound_service_account_namespaces=default \
    policies=gossip-policy \
    ttl=1h

vault write auth/kubernetes/role/consul-client \
    bound_service_account_names=consul-consul-client \
    bound_service_account_namespaces=default \
    policies=gossip-policy \
    ttl=1h


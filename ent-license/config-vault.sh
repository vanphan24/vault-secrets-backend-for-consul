export VAULT_TOKEN=root

### Set Encryption key and create policyin Vault ###
vault kv put secret/consul/gossip key='35FAhIVytwznTTk1bGuLs0nTpxQHUiGnWmxJ7ggcUKk='

vault policy write gossip-policy - <<EOF
path "secret/data/consul/gossip" {
  capabilities = ["read"]
}
EOF

### Set Ent License key and create policy in Vault. Make sure license is valid.
### Or request new one from https://www.hashicorp.com/products/###consul/trial

vault kv put secret/consul/enterpriselicense key='02MV4UU43BK5HGYYTOJZWFQMTMNNEWU33JJVWUS6SPIRATKTKXKV2E2V2WNBGWSMBTJ5CE42CMKRITIWSXJV2E2VCFO5NG2RTKJ5KFCMC2KRIXOSLJO5UVSM2WPJSEOOLULJMEUZTBK5IWST3JJJVVU3KGNVMVIQJVLFUTA6SOK5KTATCUJZVVSMSJORNGU2DJJVBTA52OIRAXOWTNLF4U4V22NVHUITLJJRBUU4DCNZHDAWKXPBZVSWCSOBRDENLGMFLVC2KPNFEXCSLJO5UWCWCOPJSFOVTGMRDWY5C2KNETMSLKJF3U22SJORGUITLUJVCE4VKNIRATMTKEKE3E26SFOVHFIVJSJ5KECMCNPJGXSV3JJFZUS3SOGBMVQSRQLAZVE4DCK5KWST3JJF4U2RCJPFGFIQL2JRKEC6SWIRAXOT3KIEYE62SNPBLWSSLTJFWVMNDDI5WHSWKYKJYGEMRVMZSEO3DULJJUSNSJNJEXOTLKJF2E2RCRORGUISSVJVCECNSNIRITMTL2IZQUS2LXNFSEOVTZMJLWY5KZLBJHAYRSGVTGIR3MORNFGSJWJFVES52NNJEXITKEKF2E2RCOKVGUIQJWJVCFCNSNPJDGCSLJO5UWGSCKOZNEQVTKMRBUSNSJNVHHMYTOJYYWEQ2JONEW2WTTLFLWI6SJNJYDOSLNGF3FUSCWONNFQTLJJ5WHG2K2GJ4HMWLNIZZUYWC2OBRTE3DJMFLXQ4DEJBVXIY3NHEYWIR3MOVNHSML2LEZEM422KNEXGSLNMR3GI3KWPFRG2RTVLEZFK5DDI44XGYKXJY2US3BRHFTFCPJ5FZTTQRZXNI4GC5KBOMXXGTDFOB4U6TTJJN4FUNCHNZBFCWKIHFJHQLZYJRYUIZLSJVFVSS3LKRBHE42MIJAXK3LQOE2TGTLUNMZWSYTVOZZU4RTTGQZDSODTLFSEENJYNRCUCL3FIFYDCZCBNNRWCNDEKYYDGMZYKB3W2VTMMF3EUUBUOBFHQSKJHFCDMVKGJRKWCVSQNJVVOSTUMNCDM4DBNQ3G6T3GI5XEWMT2KBFUUUTNI5EFMM3FLJ3XCRTFFNXTO2ZPOMVUCVCONBIFUZ2TF5FVMWLHF5FSW3CHKB3UYN3KIJ4ESN2HJ5QWWNSVMFUWCSDPMVVTAUSUN43TERCRHU6Q'

vault policy write enterpriselicense-policy - <<EOF
path "secret/data/consul/enterpriselicense" {
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


### Set role for Consul server and client to be able to read Encryption key and Ent license
### When Consul server boots up, it can assume these roles (set in the helm chart) which will 
### allow them to read the Encyption key and Ent license  
 
vault write auth/kubernetes/role/consul-server \
    bound_service_account_names=consul-consul-server \
    bound_service_account_namespaces=default \
    policies='gossip-policy,enterpriselicense-policy' \
    ttl=1h

vault write auth/kubernetes/role/consul-client \
    bound_service_account_names=consul-consul-client \
    bound_service_account_namespaces=default \
    policies='gossip-policy,enterpriselicense-policy'  \
    ttl=1h


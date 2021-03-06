
# What is this setup doing?
This setup is showing an example of using Vault as the Certificate Authority (CA) for the Consul Agent CA rather than using the built-in CA. Using Vault as the CA is much more secure.
The Consul Agent CA is responsible for generating Consul Server certificates. The Consul servers can then generate client agent certificates to the Consul clients, 
which is stored in the Consul client container's memory. 

When Consul boots up in K8s, it will retrieve the Server certs from Vault.

These steps will allow you to deploy Vault (in dev mode) and Consul into your K8s environment using helm and the provided yaml files without any other dependencies.

**Pre-reqs :**

- Clone this repo to your environment.
```
git clone https://github.com/vanphan24/vault-secrets-backend-for-consul.git
```

- A k8s environment. This was tested using Azure AKS but should also work in other Kubernetes platforms like EKS.

**Instructions:**

1. After you clone the repo, navigate to the vault-secrets-backend-for-consul/server-tls folder.
   Deploy Vault with the yaml file. This vault values file will set up a stand alone Vault pod in dev mode.
```
helm install vault hashicorp/vault -f vault-val.yaml 
```  

2. Once deployed, log into the Vault server pod and run the below commands to configure your Vault instance.
```
kubectl exec -it vault-0 -- sh
```  

3. From inside the Vault server pod, run the following commands below to configure Vault. You can put these commands into a script if you prefer.

```
export VAULT_TOKEN=root

vault auth enable kubernetes

vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault secrets enable -path=consul kv-v2

vault secrets enable pki

vault secrets tune -max-lease-ttl=87600h pki

vault write -field=certificate pki/root/generate/internal \
        common_name="dc1.consul" \
        ttl=87600h

vault policy write consul-server-policy - <<EOF
path "pki/issue/consul-server" {
  capabilities = ["create", "update"]
}
EOF

vault policy write consul-client-policy - <<EOF
path "pki/issue/consul-client" {
  capabilities = ["read"]
}
EOF

vault policy write consul-ca-policy - <<EOF
path "pki/cert/ca" {
  capabilities = ["read"]
}
EOF


vault write pki/roles/consul-server \
  allowed_domains="dc1.consul, consul-consul-server, consul-consul-server.default, consul-consul-server.default.svc" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_localhost=true \
  generate_lease=true \
  max_ttl="720h"

#Create Roles and map the Consul server's service account ("consul-consul-server") to the role ("consul-server") that Consul will assume when it logs onto Vault.
#This provides Consul with specific permissions to create/updates certs, as shown in the policy above

vault write auth/kubernetes/role/consul-server \
    bound_service_account_names=consul-consul-server \
    bound_service_account_namespaces=default \
    policies=consul-server-policy \
    ttl=1h

#Create Roles and map the Consul client's service account ("consul-consul-client") to the role ("consul-client") that Consul will assume when it logs onto Vault.
#This provides Consul with specific permissions to create/updates certs, as shown in the policy above

vault write auth/kubernetes/role/consul-client \
    bound_service_account_names=consul-consul-client \
    bound_service_account_namespaces=default \
    policies=consul-client-policy \
    ttl=1h


#Create Roles and map *any* service account ("*") to the role ("consul-ca") that the service account can assume when it logs onto Vault ("consul-server").
#This provides Consul with specific permissions to read certs, as shown in the policy above

vault write auth/kubernetes/role/consul-ca \
    bound_service_account_names="*" \
    bound_service_account_namespaces=default \
    policies=consul-ca-policy \
    ttl=1h

```
        
4. Optional. You can view the Vault UI to confirm the Vayult PKI engine appears. You can run ```kubectl get services``` to get the address of the Vault UI.
   Log into UI using browser: http://<vualt-ui-service-IP-address>:8200
   Token is "root" if you used the provided vault-val yaml
   
   
5. Deploy Consul using the provided consul-val.yaml file. Consul will deploy and retreive Server certs files from Vault. 
   You can log onto one of the Consul server pods and navigate to the /vault/secrets folder to confirm the 3 files appear.
```   
helm install consul hashicorp/consul -f consul-val.yaml --wait --debug
```
You should see the following pods:
```    
kubectl get pods
NAME                                  READY   STATUS    RESTARTS   AGE
consul-consul-client-9kpsz            2/2     Running   0          57s
consul-consul-client-qq84x            2/2     Running   0          57s
consul-consul-client-xch2h            2/2     Running   0          57s
consul-consul-server-0                2/2     Running   0          57s
vault-0                               1/1     Running   0          2m40s
vault-agent-injector-58b6d499-t2qbv   1/1     Running   0          2m40s
```    
    
6. Confirm the server certificates are in in the Consul server. Log into the Consul server pod.
```    
kubectl exec -it consul-consul-server-0 -- sh
```
    
7. Inside the Consul server pod, check that 3 cert files exist in the vault/secret directory.
```
ls vault/secrets/
serverca.crt    servercert.crt  servercert.key
```


?? 2022 GitHub, Inc.
Terms
Privacy

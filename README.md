# Docker image
```
podman build -t operb -f Dockerfile
podman push operb localhost:5000/operb:1.0
```

# Helm
```
kubectl create namespace operb
helm delete operb
helm upgrade --install operb helm/
```

test rbac:
```
kubectl auth can-i list pod --as=system:serviceaccount:operb:operbsa -n operb
```

# Testing with curl container
```
kubectl run my-operb-testbox --rm --tty -i \
--restart='Never' --namespace operb \
--image docker.io/curlimages/curl \
--overrides='{ "spec": { "serviceAccount": "operbsa" } }' \
--command -- /bin/sh
```

```
APISERVER=https://kubernetes.default.svc
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
TOKEN=$(cat ${SERVICEACCOUNT}/token)
CACERT=${SERVICEACCOUNT}/ca.crt
curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api

curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/operb/pods
```

# Testing Ruby container

```
kubectl run my-operb-testbox \
--restart='Never' --namespace operb \
--image docker.io/ruby:3.3 \
--overrides='{ "spec": { "serviceAccount": "operbsa" } }' \
--command -- sleep 3600
kubectl get pod -n operb
kubectl exec -i -t my-operb-testbox -n operb -- /bin/sh -c "gem install typhoeus"
kubectl cp -n operb operb/test.rb my-operb-testbox:/tmp/test.rb
kubectl exec -i -t my-operb-testbox -n operb -- /tmp/test.rb
kubectl delete pod -n operb my-operb-testbox
```

```
kubectl create namespace operb
helm upgrade --install operb operb/
kubectl auth can-i list pod --as=system:serviceaccount:operb:operbsa -n operb
```

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

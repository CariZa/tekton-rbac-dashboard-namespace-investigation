# Tekton Pipelines namespaces

Investigating namespaces

Is Tekton Pipelines Multi-tenant?

- Tekton Pipelines
- Tekton Dashboards

## Creating users via rbac

- admin users
- developers
- systems 
    - rbac sync (only needs rbac crud)
    - ingress & network policies sync (only needs ingress crud)

## Steps for rbac testing

Create private key:

    $ openssl genrsa -out tekton-rbac.key 2048 

## CSR

Create certificate signing request file. This is what we will use to define the groups we want on kubernetes.

TODO: Add info on CN = username O = group

I've created 3 csr config files in the "./csr-files" folder.

If you'd like to create your own csr files then take a look at the "./docs" folder and checkout the mini tutorial in CSR.md

Once you have your csr config files you want to create the certificate signing requests and pass it your private key:

```
$ openssl req -config csr-files/csr-admin.cnf -new -key tekton-rbac.key -nodes -out csr-admin.csr

$ openssl req -config ./csr-files/csr-developers.cnf -new -key tekton-rbac.key -nodes -out csr-developers.csr

$ openssl req -config ./csr-files/csr-rbac-only.cnf -new -key tekton-rbac.key -nodes -out csr-rbac-only.csr
```

Check the csr files:

```
$ openssl req -text -in csr-admin.csr

$ openssl req -text -in csr-developers.csr 

$ openssl req -text -in csr-rbac-only.csr
```

If you get no errors and you see the csr information then all is good.


## Prepare

Next wee need to base64 encrypt the csr and remove any line breaks, and store this output for later use:

```
$ export BASE64_CSR_ADMIN=$(cat ./csr-admin.csr | base64 | tr -d '\n')

$ export BASE64_CSR_DEVELOPERS=$(cat ./csr-developers.csr | base64 | tr -d '\n')

$ export BASE64_CSR_RBAC_AUTOMATION=$(cat ./csr-rbac-automation.csr | base64 | tr -d '\n')
```

If you want to check the variables 

```
$ echo $BASE64_CSR_ADMIN 

$ echo $BASE64_CSR_DEVELOPERS 

$ echo $BASE64_CSR_RBAC_AUTOMATION

```

Now we need to create the kubernetes certificate signing requests

Right now you should see no certificat signing requests on you kubernetes test cluster (this is assuming you're using a fresh test cluster, you might have csr's if you are using an existing preconfigured cluster)

Check csr on kubernetes:

    $ kubectl get certificatesigningrequests

Create your csr yaml template file ("template" is not an official term, just mean we will reuse this yaml file): 


```
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: ${BASE64_CSR}
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
```

You can now output these files as their own csr files:

```
export BASE64_CSR=$BASE64_CSR_ADMIN && export CSR_NAME=tekton-rbac-test-admins && cat k8s/templates/csr.yaml | envsubst > k8s/csr/csr-admin.yaml

export BASE64_CSR=$BASE64_CSR_DEVELOPERS && export CSR_NAME=tekton-rbac-test-developers && cat k8s/templates/csr.yaml | envsubst > k8s/csr/csr-developers.yaml

export BASE64_CSR=$BASE64_CSR_RBAC_AUTOMATION && export CSR_NAME=tekton-rbac-test-rbac-automation && cat k8s/templates/csr.yaml | envsubst > k8s/csr/csr-rbac-automation.yaml
```

Tip

You can also use a --dry-run to test them 

eg

    $ cat k8s/csr/csr-admin.yaml | kubectl apply --dry-run -o yaml -f -


Apply the csr files to your kubrnetes cluster (or minikube):

    $ kubectl apply -f k8s/csr

Check csr's on kubernetes:

    $ kubectl get certificatesigningrequests

Now you will see the csr's in kubernetes with CONDITION Pending

```
NAME                               AGE     SIGNERNAME                     REQUESTOR       CONDITION
tekton-rbac-test-admins            24s     kubernetes.io/legacy-unknown   minikube-user   Pending
tekton-rbac-test-developers        24s     kubernetes.io/legacy-unknown   minikube-user   Pending
tekton-rbac-test-rbac-automation   24s     kubernetes.io/legacy-unknown   minikube-user   Pending
```

# Approve the csrs

We can approve the csrs like this (this is assuming you have the permission to do this on your kubernetes cluster):

```
$ kubectl certificate approve tekton-rbac-test-admins

$ kubectl certificate approve tekton-rbac-test-developers

$ kubectl certificate approve tekton-rbac-test-rbac-automation
```

Check

    $ kubectl get csr

# RBAC

Let's create the RBAC rules we'd like to test across the trhee groups, admins, developers and the rbac-only users:

A quick way to see what rbac rules you can create it to run this:

    $ kubectl api-resources

kubectl will return a list of all the resource names along with their APIGROUP

The verbs you can set are:

    create, get, list, update, patch, delete

A common gotcha is the get & list. Get will let you retrieve a single resources, but if you want to retrieve a list (eg kubectl get pods) then you need to also give a user list permission.

For now, I've created the RBAC files already, just run:

    $ kubectl apply -f ./k8s/rbac/

# Create the kubeconfig

## Public key

So we've added the certificate signing requests to kubernetes using the private key. Now comes the other side of the authentication journey, the public key.

We first need to create a public key using the private key we already created.

The kubeconfigs you generate will then use the public key to make requests against the kubernetes api. 

The kubernetes API will validate the requests using the private key it has and compare it with the public key of your kubeconfig request.

Create the publickey:

    $ openssl rsa -in tekton-rbac.key -outform PEM -pubout -out tekton-rbac.pem


# User identifier

### Manually creating the kubeconfig files

Manually creating a kubeconfig (I've automated this in a helper script, just putting here what would normally happen manually, the helper script is below this).

You would have to do this for each user and update the CSR_NAME for each user.

```
$ export USER=admin

$ export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath={.current-context})

$ export CSR_NAME=tekton-rbac-test-admins

$ export CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')

$ export CLUSTER_CA_LOCATION=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority"')

$ export CLUSTER_CA=$(cat $CLUSTER_CA_LOCATION | base64 | tr -d '\n')

If you have ca data:

$ export CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')


$ export CLIENT_PUBLICKEY_DATA=$(cat ./tekton-rbac.key | base64 | tr -d '\n')

$ export CLUSTER_ENDPOINT=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."server"')
```

Use all those values to create a custom kubeconfig for each user:

    $ cat k8s/templates/kubeconfig.tpl | envsubst > kubeconfig_admin

^ This is all a lot of effort so I've put together a helper script to do it all for me, just run:

    $ sh scripts/kubeconfig_generator.sh 

# Useful snippet:

    $ alias pbcopy='xsel --clipboard --input'

# User kubectl with the new kubeconfigs

You can now test the RBAC we set up:

admins

    $ kubectl --kubeconfig kubeconfig_admin get pods
    $ kubectl --kubeconfig kubeconfig_admin get pods -n admins-namespace

developers

    $ kubectl --kubeconfig kubeconfig_developer get pods
    $ kubectl --kubeconfig kubeconfig_developer get pods -n developers-namespace

rbac only

    $ kubectl --kubeconfig kubeconfig_rbac-only get pods
    $ kubectl --kubeconfig kubeconfig_rbac-only get pods -n rbac-only-namespace

# References

Big props to this medium post, which I regularly revisit:


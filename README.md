### 1. Project Overview

This project demonstrates how to deploy a web application to Kubernetes using Kustomize to manage environment-specific configurations (development, staging, and production) and integrate the deployment into a CI/CD pipeline using GitHub Actions.

The goal is to:

- Avoid duplicating YAML files

- Maintain clean separation between base and environment configs

- Automate deployments via CI/CD

### 2. Prerequisites

Before starting, ensure you have the following installed:

- Git

- Docker (optional if you build images locally)

- kubectl

- kustomize

```
kustomize version
```

- Access to a Kubernetes cluster (EKS, Minikube, Kind, GKE, etc.)

- A GitHub repository

### 3. Task 1: Set Up Project Structure
3.1 Create Project Directory

```
mkdir kustomize-capstone
cd kustomize-capstone
```

**3.2 Create Kustomize Directory Structure**
```
mkdir -p base overlays/dev overlays/staging overlays/prod
```
**3.3 Create a Dockerfile**
  ```
  touch Dockerfile
  ```

**4. Task 2: Initialize Git**
**4.1 Initialize Git Repository**  

```
git init
```

**4.2 Create .gitignore**
```
cat <<EOF > .gitignore
.env
*.log
node_modules
.DS_Store
EOF
```
**4.3 First Commit**
```
git add .
git commit -m "Initial project structure"
```

## 5. Task 3: Define Base Configuration

The base contains common Kubernetes resources shared across all environments.

**5.1 Create Deployment (base/deployment.yaml)**
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: 707913648704.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
          ports:
            - containerPort: 80
```

**5.2 Create Service (base/service.yaml)**
```
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  labels:
    app: my-app
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
  ```

  **5.3 Create Base kustomization.yaml**

  ```
  resources:
  - deployment.yaml
  - service.yaml
```
**6. Task 4: Create Environment-Specific Overlays**

Each overlay customizes the base.

**6.1 Development Overlay**

overlays/dev/kustomization.yaml

```
resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: my-app
      namespace: default
    path: replica-count.yaml
```
overlays/dev/replica-count.yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 3
  
```

**6.2 Staging Overlay**

overlays/staging/kustomization.yaml
```
resources:
  - ../../base

patchesStrategicMerge:
  - replica-count.yaml
```

**6.3 Production Overlay**

overlays/prod/kustomization.yaml
```
resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: my-app
      namespace: default
    path: replica-count.yaml
```

### 7. Task 5: Deploy Using Kustomize
**7.1 Preview Manifests**
 ```
 kustomize build overlays/dev
```

**7.2 Apply to Cluster**

 Important
kustomize apply is invalid. Use kubectl apply -k.
  ```
  kubectl apply -k overlays/dev
```

**7.3 Verify Deployment**

```
kubectl get deployments
kubectl get pods
kubectl get svc
```

### 8. Task 6: Manage ConfigMaps and Secrets
**8.1 Add ConfigMap Generator (Base)**

Edit base/kustomization.yaml:

```
resources:
  - deployment.yaml
  - service.yaml

configMapGenerator:
  - name: app-config
    literals:
      - APP_NAME=web-app
      - LOG_LEVEL=info
```

### 8.2 Environment Overrides (Example: Dev)

overlays/dev/kustomization.yaml

```
resources:
  - ../../base

nameSuffix: -dev

configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - LOG_LEVEL=debug
```
### 8.3 Secrets (Example)
```
secretGenerator:
  - name: app-secret
    literals:
      - DB_PASSWORD=devpassword
```

### 9. Task 7: CI/CD Pipeline (GitHub Actions)
**9.1 Create Workflow Directory**

```
mkdir -p .github/workflows
```
**9.2 GitHub Actions Pipeline**

.github/workflows/deploy.yml
```
name: Deploy with Kustomize

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read
  packages: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Set up kubectl
        uses: azure/setup-kubectl@v4
        with:
          version: latest

      - name: Set up Kustomize
        run: |
          curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
          sudo mv kustomize /usr/local/bin/

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region ${{ secrets.AWS_REGION }} | docker login --username AWS --password-stdin ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com

      - name: Build and Push Docker image
        run: |
          docker build -t my-app:latest .
          docker tag my-app:latest ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/my-app:latest
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/my-app:latest

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ secrets.AWS_REGION }} --name my-eks-cluster

      - name: Deploy to Kubernetes
        run: |
          kubectl apply -k overlays/production/
```

**9.3 Configure Kubernetes Access**

- Store kubeconfig or token in GitHub Secrets

- Example secret name:

    - KUBECONFIG

- Load it in the pipeline before deploying

**10. Task 8: Test CI/CD Pipeline**

1 Modify replica count or image

2 Commit and push changes

```
git add .
git commit -m "Update prod replicas"
git push origin main
```

**3 Verify:**

- GitHub Actions pipeline runs

- Kubernetes resources update correctly

**11. Common Errors & Fixes**
Error: unknown command "apply" for "kustomize"

```
kubectl apply -k overlays/dev
```

- Pods Not Starting
  
  ```
  kubectl describe pod <pod-name>
  kubectl logs <pod-name>
  ```


### Task 9 Create a Dockerfile

**9.1 Create a Dockerfile**
  Create a dockerfile
  ```

FROM nginx:latest

COPY 2137_barista_cafe/* /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


```

** 9.2 Build and Test Docker Locally
 
 **Build image**
 ```
 docker build -t kustomize-web-app:1.0.0 .
 ```
 Replace web-app with the orignal web application

 **Run Locally**

 ```
 docker run -p 8080:80 kustomize-web-app:1.0.0
```

Open on Browser:
      
  ```
      http://localhost:8080
  ```


# F5 BIG-IP Next for Kubernetes 安裝指南

## 📋 前置條件

### 硬體需求
- Dell PowerEdge R760 伺服器
- NVIDIA BlueField-3 DPU (已安裝 DOCA 2.9.2)
- 標準 Kubernetes v1.29.15 (非 K3s)
- DPU 已正確配置 SF 和 OVS 橋接

### 軟體需求
- Ubuntu 22.04 LTS
- Docker 或 containerd
- Helm 3.x
- kubectl 工具

### 必要文件
- F5 授權文件 (JWT token)
- F5 映像倉庫認證 (cne_pull_64.json)

---

## 📝 安裝步驟

### Step 0: 準備配置文件
```bash
# 複製配置文件專案
git clone https://github.com/您的用戶名/f5_bnk.git
cd f5_bnk

# 此目錄將作為工作目錄，所有後續命令都在此目錄執行
pwd
# 應顯示：/path/to/f5_bnk
```

**⚠️ 重要：** 在繼續之前，請務必更新以下文件中的實際值：
- `far-secret.yaml` - 填入您的 F5 映像倉庫認證 (從myf5下載Service Account Key , 並透過第三步轉成far-secret.yaml）
- `flo_values_prod.yaml` - 填入您的 JWT 授權 token  
- `cpcl-key.yaml` - 填入您的 CPCL 密鑰

### Step 1: 節點標籤配置
```bash
# 為 DPU 節點添加 F5 TMM 標籤
kubectl label node dpu app=f5-tmm

# 驗證節點標籤
kubectl get nodes --show-labels
```

### Step 2: 創建命名空間
```bash
# 創建必要的命名空間
kubectl create ns f5-utils
kubectl create ns f5-operators
kubectl create ns f5-bnk

# 驗證命名空間
kubectl get namespaces
```

### Step 3: 配置映像倉庫認證
```bash
# 將以下內容存成sh檔案，並執行，產生far-secret.yaml
#!/bin/bash

# Read the content of pipeline.json into the SERVICE_ACCOUNT_KEY variable
SERVICE_ACCOUNT_KEY=$(cat cne_pull_64.json)

# Create the SERVICE_ACCOUNT_K8S_SECRET variable by appending "_json_key_base64:" to the base64 encoded SERVICE_ACCOUNT_KEY
SERVICE_ACCOUNT_K8S_SECRET=$(echo "_json_key_base64:${SERVICE_ACCOUNT_KEY}" | base64 -w 0)

# Create the secret.yaml file with the provided content
cat << EOF > far-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: far-secret
data:
  .dockerconfigjson: $(echo "{\"auths\": {\
\"repo.f5.com\":\
{\"auth\": \"$SERVICE_ACCOUNT_K8S_SECRET\"}}}" | base64 -w 0)
type: kubernetes.io/dockerconfigjson
EOF
```

```bash
# 確保在 f5_bnk 工作目錄中
# 創建映像拉取密鑰
kubectl create -f far-secret.yaml -n f5-utils
kubectl create -f far-secret.yaml -n f5-operators
kubectl create -f far-secret.yaml -n f5-bnk
kubectl create -f far-secret.yaml -n default

# 驗證密鑰
kubectl describe secrets far-secret -n f5-utils
```

### Step 4: 安裝 Cert Manager
```bash
# 安裝 cert-manager v1.16.1
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml

# 等待 cert-manager 就緒
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s

# 創建 ClusterIssuer
kubectl apply -f cluster-issuer.yaml

# 創建 OTEL 證書
kubectl apply -f otel-certs.yaml -n f5-utils
kubectl apply -f otel-certs.yaml -n f5-bnk
```

### Step 5: 登入 F5 Helm Repository
```bash
# 使用認證文件登入
cat cne_pull_64.json | helm registry login -u _json_key_base64 --password-stdin https://repo.f5.com

# 拉取 F5 manifest
helm pull oci://repo.f5.com/release/f5-bnk-manifest --version 2.0.0-1.7.8-0.3.37

# 拉取證書生成工具
helm pull oci://repo.f5.com/utils/f5-cert-gen --version 0.9.3
tar zxvf f5-cert-gen-0.9.3.tgz
# 在工作目錄下會生成一個目錄cert-gen
sh cert-gen/gen_cert.sh -s=api-server -a=f5-spk-cwc.f5-utils -n=1
# 注意除了生成cwc-license-certs.yaml 會在下一個步驟部署，也會生成api-server-secrets 這個目錄後續會用到
```

### Step 6: 配置 CWC 授權證書
```bash
# 應用 CWC 授權證書
kubectl apply -f cwc-license-certs.yaml -n f5-utils

# 應用 CPCL 密鑰
kubectl apply -f cpcl-key.yaml --namespace f5-utils
```

### Step 7: 配置存儲類
```bash
# 安裝NFS
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs     --namespace kube-system     --set kubeletDir=/var/lib/kubelet
kubectl apply -f storageclass.yaml

# 設置默認存儲類（如果有 NFS）
kubectl patch storageclass f5-nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 驗證存儲類
kubectl get storageclass
```

### Step 8: 安裝 F5 Lifecycle Operator (FLO)
```bash
# 安裝 FLO 到 f5-bnk namespace
# 注意這個時候 flo_values_prod.yaml 內容要把jwt 授權放進去
# 目前正式版跟測試版的yaml 寫法不太一樣，以下flo_values_prod.yaml 屬於正式版寫法
helm upgrade --install flo oci://repo.f5.com/charts/f5-lifecycle-operator \
  --version v1.7.8-0.3.37 \
  -f flo_values_prod.yaml \
  -n f5-bnk

# 等待 FLO 就緒
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=f5-lifecycle-operator -n f5-bnk --timeout=300s
```

### Step 9: 安裝 F5 SPK CRDs
```bash
# 安裝 Common CRDs (到 default namespace)
helm upgrade --install f5-spk-crds-common \
  oci://repo.f5.com/charts/f5-spk-crds-common \
  --version 8.7.4 \
  -f crd-values.yaml

# 安裝 Service Proxy CRDs (到 default namespace)
helm upgrade --install f5-spk-crds-service-proxy \
  oci://repo.f5.com/charts/f5-spk-crds-service-proxy \
  --version 8.7.4 \
  -f crd-values.yaml

# 驗證 CRDs
kubectl get crd | grep k8s.f5net.com
```

### Step 10: 安裝 Gateway API
```bash
# 安裝 Kubernetes Gateway API v1.2.0
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# 驗證 Gateway API CRDs
kubectl get crd | grep gateway.networking.k8s.io
```

### Step 11: 配置 Network Attachment Definitions
```bash
# 應用網路附加定義 (Multus CNI)
kubectl apply -f network-attachment-definitions.yaml -n f5-bnk

# 驗證網路附加定義
kubectl get network-attachment-definitions.k8s.cni.cncf.io -n f5-bnk
```

### Step 12: 創建 BNK Gateway Class
```bash
# 應用 BNK Gateway Class 配置
kubectl apply -f bnkgatewayclass-cr.yaml -n f5-bnk

# 等待所有 F5 pods 就緒
kubectl wait --for=condition=ready pod -l app=f5-tmm -n f5-bnk --timeout=600s
```

### Step 13: 配置 VF (主機端網路)
```bash
# 配置 SR-IOV VF（如果需要）
sudo echo 1 > /sys/class/infiniband/mlx5_1/device/sriov_numvfs

# 應用 netplan 配置（如果有修改）
sudo netplan apply
```

### Step 14: 驗證 CWC API 連接
```bash
# 準備證書文件，這邊要回去參考第五個步驟，把api-server-secrets 裡面的憑證拉出來
mkdir -p $HOME/cwc/cwc_api
cp api-server-secrets/ssl/client/certs/client_certificate.pem $HOME/cwc/cwc_api/
cp api-server-secrets/ssl/ca/certs/ca_certificate.pem $HOME/cwc/cwc_api/
cp api-server-secrets/ssl/client/secrets/client_key.pem $HOME/cwc/cwc_api/

# token 取得方式
kubectl get secret cwc-auth-token -n f5-utils -o jsonpath="{.data.token}" | base64 --decode; echo ""

# 測試 CWC API (記得把token換成剛剛取得的), 這邊輸入憑證的路徑為了方便寫成絕對路徑。請依照你實際放憑證的路徑來寫
curl -X GET https://f5-spk-cwc.f5-utils:30881/status \
  --cert /home/uniforce/cwc/cwc_api/client_certificate.pem \
  --key /home/uniforce/cwc/cwc_api/client_key.pem \
  --cacert /home/uniforce/cwc/cwc_api/ca_certificate.pem \
  -H "Authorization: Bearer <your-token>" | jq
```

### Step 15: 配置 F5 VLANs
```bash
# 應用外部 VLAN 配置
kubectl apply -f external_vlan.yaml

# 應用內部 VLAN 配置
kubectl apply -f internal_vlan.yaml

# 驗證 VLAN 配置
kubectl get f5-spk-vlans -n f5-bnk
```

---

## ✅ 驗證安裝

### 檢查所有 Pods 狀態
```bash
kubectl get pods -A | grep -E 'f5-|tmm|afm|cne|ipam|observer|dssm|rabbit'
```

### 檢查 Helm 部署
```bash
helm list -A
```

### 預期結果
- 所有 F5 相關 pods 應該處於 Running 狀態
- FLO 成功部署在 f5-bnk namespace
- CRDs 成功安裝在 default namespace
- TMM pod 運行在標記為 app=f5-tmm 的 DPU 節點上

---

## 🔧 故障排除

### Pod 無法啟動
```bash
# 檢查 pod 日誌
kubectl logs -n f5-bnk <pod-name>

# 檢查事件
kubectl get events -n f5-bnk --sort-by='.lastTimestamp'
```

### 映像拉取失敗
```bash
# 檢查密鑰
kubectl get secret far-secret -n f5-bnk -o yaml

# 重新創建密鑰
kubectl delete secret far-secret -n f5-bnk
kubectl create -f far-secret.yaml -n f5-bnk
```

### CWC 連接問題
```bash
# 檢查 CWC service
kubectl get svc f5-spk-cwc -n f5-utils

# 檢查 NodePort
kubectl get svc f5-spk-cwc -n f5-utils -o jsonpath='{.spec.ports[0].nodePort}'
```

---

## 📌 重要配置文件清單

所有配置文件包含在 GitHub 專案的根目錄中：

- `flo_values_prod.yaml` - FLO Helm values (需填入 JWT token)
- `bnkgatewayclass-cr.yaml` - BNK Gateway Class 定義
- `external_vlan.yaml` - 外部 VLAN 配置 (VLAN 138)
- `internal_vlan.yaml` - 內部 VLAN 配置 (VLAN 152)
- `far-secret.yaml` - 映像倉庫認證 (需填入實際認證)
- `cwc-license-certs.yaml` - CWC 授權證書
- `cpcl-key.yaml` - CPCL 密鑰 (需填入實際密鑰)
- `otel-certs.yaml` - OTEL 證書配置
- `cluster-issuer.yaml` - Cert-manager ClusterIssuer
- `net-attach-def.yaml` - Multus 網路附加定義 (SF 網路)
- `crd-values.yaml` - CRD Helm values 配置
- `storageclass.yaml` - NFS 存儲類配置

**注意：** `cne_pull_64.json` (F5 倉庫認證文件) 需要您自行準備，不包含在 GitHub 專案中

---

## 📝 注意事項

1. **嚴格按照順序執行**：每個步驟都有依賴關係
2. **等待 Pod 就緒**：在進行下一步之前確保當前步驟的 pods 都已就緒
3. **命名空間一致性**：注意不同組件部署在不同的 namespace
4. **網路配置**：確保 DPU 的 SF 和 OVS 配置正確
5. **版本匹配**：使用指定的版本號，不要隨意升級

---

## 🔗 參考資源

- [F5 BIG-IP Next Documentation](https://docs.f5.com)
- [F5 BIG-IP Next for Kubernetes](https://www.f5.com/products/big-ip-services/next-for-kubernetes)
- [NVIDIA BlueField DPU Documentation](https://docs.nvidia.com/networking/display/BlueFieldDPUOSLatest)

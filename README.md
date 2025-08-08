# F5 BIG-IP Next for Kubernetes 配置文件

這個儲存庫包含部署 F5 BIG-IP Next for Kubernetes 所需的所有配置文件。

## 📋 硬體需求

- Dell PowerEdge R760 伺服器
- NVIDIA BlueField-3 DPU (DOCA 2.9.2)
- Ubuntu 22.04 LTS
- 標準 Kubernetes v1.29.15

## 🚀 快速開始

### 1. 複製儲存庫
```bash
git clone https://github.com/您的用戶名/f5_bnk.git
cd f5_bnk
```

### 2. 檢查配置
```bash
# 檢查配置文件是否完整並已正確配置
./check_config.sh
```

### 3. 跟隨安裝指南
請參考 [F5_BINK_Installation_Guide.md](F5_BINK_Installation_Guide.md) 獲取詳細的安裝步驟。

### 4. 驗證安裝
```bash
# 安裝完成後驗證所有組件狀態
./verify_installation.sh
```

## 📁 文件結構

### 核心配置文件
- `flo_values_prod.yaml` - F5 Lifecycle Operator 生產配置
- `bnkgatewayclass-cr.yaml` - BNK Gateway Class 定義
- `external_vlan.yaml` - 外部 VLAN 配置 (VLAN 138)
- `internal_vlan.yaml` - 內部 VLAN 配置 (VLAN 152)

### 認證與證書
- `far-secret.yaml` - F5 映像倉庫認證 (需要填入實際值)
- `cwc-license-certs.yaml` - CWC 授權證書
- `cpcl-key.yaml` - CPCL 密鑰
- `otel-certs.yaml` - OTEL 證書配置
- `cluster-issuer.yaml` - Cert-manager ClusterIssuer

### 網路與存儲
- `net-attach-def.yaml` - Multus NetworkAttachmentDefinition (SF 網路)
- `storageclass.yaml` - NFS 存儲類配置
- `crd-values.yaml` - CRD Helm values 配置

### 工具腳本
- `check_config.sh` - 檢查配置文件完整性和必要設定
- `verify_installation.sh` - 驗證安裝後的系統狀態
- `init_github.sh` - 初始化 Git 儲存庫並準備推送到 GitHub

## ⚠️ 重要注意事項

### 需要自定義的文件

1. **far-secret.yaml** - 需要填入您的 F5 映像倉庫認證
2. **flo_values_prod.yaml** - 需要填入您的 JWT 授權 token
3. **cpcl-key.yaml** - 需要填入您的 CPCL 密鑰

### 依賴要求

- F5 有效授權
- F5 映像倉庫存取權限
- 正確配置的 BlueField-3 DPU
- SR-IOV 和 Multus CNI 支援

## 📦 安裝順序

1. **節點準備** - 標籤 DPU 節點
2. **命名空間** - 創建 f5-bnk, f5-utils, f5-operators
3. **認證** - 部署映像拉取密鑰
4. **基礎設施** - Cert-manager, NFS 存儲
5. **F5 組件** - FLO, CRDs, Gateway API
6. **網路** - NetworkAttachmentDefinitions, Gateway Class
7. **VLAN** - 外部和內部 VLAN 配置

## 🔧 驗證

安裝完成後，檢查所有組件：

```bash
# 檢查所有 F5 相關 pods
kubectl get pods -A | grep f5

# 檢查 BNK Gateway Class
kubectl get bnkgatewayclasses -n f5-bnk

# 檢查 VLANs
kubectl get f5-spk-vlans -n f5-bnk
```

## 📚 文檔

- [完整安裝指南](F5_BINK_Installation_Guide.md) - 詳細的步驟說明
- [F5 官方文檔](https://docs.f5.com) - F5 BIG-IP Next 官方資源

## 🤝 貢獻

如果您發現問題或有改進建議，請提交 Issue 或 Pull Request。

## 📝 授權

此專案僅供學習和內部使用。F5 軟體需要有效的商業授權。
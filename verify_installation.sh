#!/bin/bash

# F5 BIG-IP Next 安裝驗證腳本
# 檢查所有組件是否正確安裝和運行

echo "🔍 驗證 F5 BIG-IP Next 安裝狀態..."
echo "==================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl 未安裝或不在 PATH 中${NC}"
    exit 1
fi

# 檢查 Kubernetes 連接
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}❌ 無法連接到 Kubernetes 集群${NC}"
    exit 1
fi

echo -e "${BLUE}📋 檢查節點狀態...${NC}"
kubectl get nodes -o wide

echo ""
echo -e "${BLUE}📋 檢查命名空間...${NC}"
NAMESPACES=("f5-bnk" "f5-utils" "f5-operators" "cert-manager" "kube-system")
for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo -e "${GREEN}✅ $ns${NC}"
    else
        echo -e "${RED}❌ $ns (不存在)${NC}"
    fi
done

echo ""
echo -e "${BLUE}📋 檢查 F5 Pods 狀態...${NC}"
echo "f5-bnk namespace:"
kubectl get pods -n f5-bnk 2>/dev/null | grep -E "NAME|f5-|tmm|afm|cne|ipam|observer|grpc|otel" || echo "無 F5 pods"

echo ""
echo "f5-utils namespace:"
kubectl get pods -n f5-utils 2>/dev/null | grep -E "NAME|f5-|dssm|rabbit|cwc|csrc|ipam|fluentd" || echo "無 F5 utils pods"

echo ""
echo -e "${BLUE}📋 檢查 CRDs...${NC}"
echo "F5 CRDs:"
kubectl get crd | grep k8s.f5 | head -5
echo ""
echo "Gateway API CRDs:"
kubectl get crd | grep gateway.networking.k8s.io | head -3

echo ""
echo -e "${BLUE}📋 檢查 BNK Gateway Class...${NC}"
if kubectl get bnkgatewayclasses -n f5-bnk &> /dev/null; then
    kubectl get bnkgatewayclasses -n f5-bnk
else
    echo -e "${YELLOW}⚠️  BNK Gateway Class 未創建${NC}"
fi

echo ""
echo -e "${BLUE}📋 檢查 F5 VLANs...${NC}"
if kubectl get f5-spk-vlans -n f5-bnk &> /dev/null; then
    kubectl get f5-spk-vlans -n f5-bnk
else
    echo -e "${YELLOW}⚠️  F5 VLANs 未配置${NC}"
fi

echo ""
echo -e "${BLUE}📋 檢查網路附加定義...${NC}"
if kubectl get network-attachment-definitions -n f5-bnk &> /dev/null; then
    kubectl get network-attachment-definitions -n f5-bnk
else
    echo -e "${YELLOW}⚠️  網路附加定義未創建${NC}"
fi

echo ""
echo -e "${BLUE}📋 檢查 Helm 部署...${NC}"
if command -v helm &> /dev/null; then
    helm list -A | grep -E "flo|f5|csi"
else
    echo -e "${YELLOW}⚠️  Helm 未安裝${NC}"
fi

echo ""
echo -e "${BLUE}📋 檢查存儲類...${NC}"
kubectl get storageclass | head -5

echo ""
echo -e "${BLUE}📋 檢查 F5 Services...${NC}"
echo "f5-utils services:"
kubectl get svc -n f5-utils | grep f5 2>/dev/null || echo "無 F5 services"

echo ""
echo "f5-bnk services:"
kubectl get svc -n f5-bnk | grep f5 2>/dev/null || echo "無 F5 services"

echo ""
echo "=================================="
echo -e "${BLUE}📋 安裝驗證完成${NC}"

# 檢查關鍵 pods 是否運行
CRITICAL_PODS_RUNNING=0
TOTAL_CRITICAL_PODS=0

# 檢查 FLO
if kubectl get pods -n f5-bnk | grep -q "flo.*Running"; then
    ((CRITICAL_PODS_RUNNING++))
fi
((TOTAL_CRITICAL_PODS++))

# 檢查 TMM
if kubectl get pods -n f5-bnk | grep -q "tmm.*Running"; then
    ((CRITICAL_PODS_RUNNING++))
fi
((TOTAL_CRITICAL_PODS++))

# 檢查 CWC
if kubectl get pods -n f5-utils | grep -q "cwc.*Running"; then
    ((CRITICAL_PODS_RUNNING++))
fi
((TOTAL_CRITICAL_PODS++))

echo ""
if [ $CRITICAL_PODS_RUNNING -eq $TOTAL_CRITICAL_PODS ]; then
    echo -e "${GREEN}✅ 關鍵組件運行正常 ($CRITICAL_PODS_RUNNING/$TOTAL_CRITICAL_PODS)${NC}"
    echo -e "${GREEN}🎉 F5 BIG-IP Next 安裝驗證通過！${NC}"
else
    echo -e "${YELLOW}⚠️  部分關鍵組件未運行 ($CRITICAL_PODS_RUNNING/$TOTAL_CRITICAL_PODS)${NC}"
    echo -e "${YELLOW}請檢查 pods 狀態並查看日誌${NC}"
fi

echo ""
echo "💡 常用命令："
echo "   kubectl get pods -A | grep f5     # 查看所有 F5 pods"
echo "   kubectl logs -n f5-bnk <pod>      # 查看 pod 日誌"
echo "   kubectl describe -n f5-bnk <pod>  # 查看 pod 詳細信息"
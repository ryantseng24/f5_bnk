#!/bin/bash

# F5 BIG-IP Next 配置文件檢查腳本
# 在開始安裝前檢查必要的配置文件是否存在且已正確配置

echo "🔍 檢查 F5 BIG-IP Next 配置文件..."
echo "=================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 檢查結果計數
MISSING=0
NEED_CONFIG=0
OK=0

# 檢查必要文件是否存在
check_file_exists() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC} - $description"
        ((OK++))
        return 0
    else
        echo -e "${RED}❌ $file${NC} - $description (文件不存在)"
        ((MISSING++))
        return 1
    fi
}

# 檢查文件是否需要配置
check_needs_config() {
    local file=$1
    local description=$2
    local pattern=$3
    
    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  $file${NC} - $description (需要配置)"
            ((NEED_CONFIG++))
            return 1
        else
            echo -e "${GREEN}✅ $file${NC} - $description"
            ((OK++))
            return 0
        fi
    else
        echo -e "${RED}❌ $file${NC} - $description (文件不存在)"
        ((MISSING++))
        return 1
    fi
}

echo "核心配置文件："
check_file_exists "flo_values_prod.yaml" "FLO Helm values"
check_file_exists "bnkgatewayclass-cr.yaml" "BNK Gateway Class"
check_file_exists "external_vlan.yaml" "外部 VLAN (138)"
check_file_exists "internal_vlan.yaml" "內部 VLAN (152)"

echo ""
echo "認證與證書文件："
check_needs_config "far-secret.yaml" "映像倉庫認證" "PLACEHOLDER\|TODO\|FIXME\|changeme"
check_needs_config "flo_values_prod.yaml" "JWT 授權 token" "PLACEHOLDER\|TODO\|FIXME\|changeme\|your-jwt-token"
check_needs_config "cpcl-key.yaml" "CPCL 密鑰" "PLACEHOLDER\|TODO\|FIXME\|changeme"
check_file_exists "cwc-license-certs.yaml" "CWC 授權證書"
check_file_exists "otel-certs.yaml" "OTEL 證書"

echo ""
echo "基礎設施文件："
check_file_exists "cluster-issuer.yaml" "Cert-manager ClusterIssuer"
check_file_exists "storageclass.yaml" "NFS 存儲類"

echo ""
echo "網路配置文件："
check_file_exists "net-attach-def.yaml" "Multus 網路附加定義"
check_file_exists "crd-values.yaml" "CRD Helm values"

echo ""
echo "外部文件 (需自行準備)："
if [ -f "cne_pull_64.json" ]; then
    echo -e "${GREEN}✅ cne_pull_64.json${NC} - F5 倉庫認證文件"
    ((OK++))
else
    echo -e "${YELLOW}⚠️  cne_pull_64.json${NC} - F5 倉庫認證文件 (需自行準備)"
    ((NEED_CONFIG++))
fi

echo ""
echo "=================================="
echo "檢查結果摘要："
echo -e "${GREEN}✅ 正確配置: $OK${NC}"
echo -e "${YELLOW}⚠️  需要配置: $NEED_CONFIG${NC}"
echo -e "${RED}❌ 缺少文件: $MISSING${NC}"

echo ""
if [ $MISSING -gt 0 ]; then
    echo -e "${RED}❌ 發現缺少必要文件，請檢查專案完整性${NC}"
    exit 1
elif [ $NEED_CONFIG -gt 0 ]; then
    echo -e "${YELLOW}⚠️  請完成必要配置後再開始安裝${NC}"
    echo ""
    echo "需要配置的項目："
    echo "1. far-secret.yaml - 填入 F5 映像倉庫認證"
    echo "2. flo_values_prod.yaml - 填入 JWT 授權 token"
    echo "3. cpcl-key.yaml - 填入 CPCL 密鑰"
    echo "4. 準備 cne_pull_64.json 文件"
    exit 2
else
    echo -e "${GREEN}✅ 所有配置文件檢查通過，可以開始安裝！${NC}"
    exit 0
fi
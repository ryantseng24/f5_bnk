#!/bin/bash

# F5 BIG-IP Next for Kubernetes GitHub 專案初始化腳本
# 使用方法：
# 1. 在 GitHub 上創建名為 f5_bnk 的新儲存庫
# 2. 執行此腳本：chmod +x init_github.sh && ./init_github.sh
# 3. 根據提示輸入您的 GitHub 用戶名

echo "🚀 初始化 F5 BIG-IP Next for Kubernetes GitHub 專案"
echo "=================================================="

# 檢查是否在正確的目錄
if [ ! -f "README.md" ] || [ ! -f "flo_values_prod.yaml" ]; then
    echo "❌ 錯誤：請確保在包含配置文件的 f5_bnk 目錄中執行此腳本"
    exit 1
fi

# 讀取 GitHub 用戶名
read -p "請輸入您的 GitHub 用戶名: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ 錯誤：GitHub 用戶名不能為空"
    exit 1
fi

echo "📝 初始化 Git 儲存庫..."

# 初始化 Git
git init

# 添加所有文件
git add .

# 創建初始提交
git commit -m "Initial commit: F5 BIG-IP Next for Kubernetes configuration files

- Add complete configuration files for F5 BINK deployment
- Add comprehensive installation guide
- Add README with quick start instructions
- Add .gitignore for sensitive files
- Ready for deployment on R760 + BlueField-3 setup"

# 添加遠程儲存庫
echo "🔗 添加 GitHub 遠程儲存庫..."
git remote add origin https://github.com/$GITHUB_USERNAME/f5_bnk.git

# 設置主分支
git branch -M main

echo "📤 準備推送到 GitHub..."
echo ""
echo "下一步："
echo "1. 確保您已在 GitHub 上創建了 f5_bnk 儲存庫"
echo "2. 執行以下命令推送到 GitHub:"
echo ""
echo "   git push -u origin main"
echo ""
echo "3. 如果需要認證，請使用您的 GitHub token"
echo ""
echo "✅ Git 儲存庫已準備就緒！"
echo ""
echo "⚠️  重要提醒："
echo "   - 請確保在使用前填入敏感文件的實際值"
echo "   - far-secret.yaml 需要填入 F5 映像倉庫認證"
echo "   - flo_values_prod.yaml 需要填入 JWT 授權 token"
echo "   - cpcl-key.yaml 需要填入 CPCL 密鑰"
echo "   - 準備您的 cne_pull_64.json 文件"
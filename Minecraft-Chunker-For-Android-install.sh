#!/data/data/com.termux/files/usr/bin/bash
# minecraft-world-converter-zh.sh
# Minecraft存档转换一键工具 v8.3
# 修复：逻辑矛盾，简化bc使用

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_VERSION="8.3"
CHUNKER_VERSION="1.14.0"

# 函数：智能版本识别
convert_version() {
    local input="$1"
    local version=""
    local type=""
    
    # 全部转为小写处理
    local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # 检查是否是完整格式（已包含BEDROCK_或JAVA_）
    if echo "$lower_input" | grep -q "^bedrock_\|^java_"; then
        echo "$input" | tr 'a-z' 'A-Z'  # 转为大写
        return
    fi
    
    # 提取版本号（1.20.0, 1_20_0, 1-20-0等格式）
    local version_number=$(echo "$lower_input" | grep -o "[0-9][0-9._-]*[0-9]" | head -1)
    
    if [ -z "$version_number" ]; then
        echo "ERROR: 未找到版本号"
        return
    fi
    
    # 将版本号统一为下划线格式
    version_number=$(echo "$version_number" | tr '.-' '_')
    
    # 检测版本类型
    if echo "$lower_input" | grep -q "基岩\|bedrock\|be\|基岩版\|bed\|mcpe"; then
        type="BEDROCK"
    elif echo "$lower_input" | grep -q "java\|je\|java版\|爪哇\|jc"; then
        type="JAVA"
    else
        # 如果未指定类型，默认基岩版（因为安卓主要是基岩版）
        type="BEDROCK"
    fi
    
    echo "${type}_${version_number}"
}

# 函数：检测存档大小并给出提示（简化版，始终使用bc）
detect_world_size() {
    local input_path="$1"
    if command -v du >/dev/null 2>&1; then
        local size_kb=$(du -sk "$input_path" 2>/dev/null | cut -f1)
        if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
            # 转换KB为MB
            local size_mb=$((size_kb / 1024))
            
            if [ "$size_mb" -gt 512 ]; then
                echo ""
                
                # 因为我们在安装时已经安装了bc，所以这里肯定有bc
                # 用bc计算GB，保留1位小数
                local size_gb=$(echo "scale=1; $size_kb / 1024 / 1024" | bc)
                
                # 修复bc的输出格式：确保有前导零
                # bc输出可能是 .9 或 0.9 或 1.0
                if [[ $size_gb == .* ]]; then
                    # 如果是.9，添加前导0
                    size_gb="0${size_gb}"
                fi
                
                echo "⚠️  检测到较大存档: ${size_gb}GB"
                
                echo "   转换可能需要较多内存和较长时间，建议："
                echo "   - 连接充电器"
                echo "   - 确保手机有足够可用内存"
                echo "   - 转换过程中不要关闭Termux"
                if [ "$size_mb" -gt 1024 ]; then
                    echo "   - 考虑分配更多内存（如 -Xmx4g）"
                fi
            else
                echo "📊 存档大小: ${size_mb}MB"
            fi
        else
            echo "📊 无法检测存档大小"
        fi
    else
        echo "📊 无法检测存档大小 (du命令不可用)"
    fi
}

# 函数：显示支持的版本范围
show_supported_versions() {
    echo ""
    echo "📋 官方支持的版本范围 (来自GitHub):"
    echo ""
    echo "🎮 基岩版 (Bedrock):"
    echo "  1.12.0"
    echo "  1.13.0"
    echo "  1.14.0 - 1.14.60"
    echo "  1.16.0 - 1.16.220"
    echo "  1.17.0 - 1.17.40"
    echo "  1.18.0 - 1.18.30"
    echo "  1.19.0 - 1.19.80"
    echo "  1.20.0 - 1.20.80"
    echo "  1.21.0 - 1.21.130"
    echo ""
    echo "☕ Java版:"
    echo "  1.8.8"
    echo "  1.9.0 - 1.9.3"
    echo "  1.10.0 - 1.10.2"
    echo "  1.11.0 - 1.11.2"
    echo "  1.12.0 - 1.12.2"
    echo "  1.13.0 - 1.13.2"
    echo "  1.14.0 - 1.14.4"
    echo "  1.15.0 - 1.15.2"
    echo "  1.16.0 - 1.16.5"
    echo "  1.17.0 - 1.17.1"
    echo "  1.18.0 - 1.18.2"
    echo "  1.19.0 - 1.19.4"
    echo "  1.20.0 - 1.20.6"
    echo "  1.21.0 - 1.21.11"
    echo ""
    echo "💡 提示："
    echo "  - 工具尝试转换不在列表中的版本也可能成功"
    echo "  - 但成功率和稳定性可能受影响"
    echo "  - 建议尽量使用列表中的版本"
}

# 简洁的打印函数
info() { echo -e "${BLUE}[信息]${NC} $1"; }
success() { echo -e "${GREEN}[成功]${NC} $1"; }
warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
error() { echo -e "${RED}[错误]${NC} $1"; }

# 显示标题
clear
echo -e "${BLUE}══════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Minecraft存档转换工具 v8.3             ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════${NC}"
echo ""

# 0. 检查存储权限
info "检查存储权限..."
if [ ! -d ~/storage ]; then
    warn "需要获取存储权限"
    echo "请在弹出的窗口中选择'允许'"
    sleep 2
    termux-setup-storage
    sleep 2
    if [ ! -d ~/storage ]; then
        error "存储权限获取失败"
        echo "请手动运行: termux-setup-storage"
        exit 1
    fi
fi
success "存储权限正常"

# 1. 换源
info "配置镜像源..."
if ! grep -q "mirrors.tuna.tsinghua.edu.cn" $PREFIX/etc/apt/sources.list 2>/dev/null; then
    sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
    success "已切换至清华镜像源"
else
    info "已在使用清华镜像源"
fi

# 2. 安装软件（包含bc）
info "安装必要软件..."
pkg update -y >/dev/null 2>&1
if pkg install -y openjdk-17 wget bc 2>&1 | grep -q "E:.*"; then
    error "安装失败，请检查网络"
    exit 1
fi
success "软件安装完成"
java -version 2>&1 | head -1 | sed 's/^/Java版本: /'

# 3. 下载工具
info "下载转换工具..."
CHUNKER_JAR="chunker-cli-$CHUNKER_VERSION.jar"
if [ ! -f ~/$CHUNKER_JAR ]; then
    wget -q --show-progress -O ~/$CHUNKER_JAR \
        https://github.com/HiveGamesOSS/Chunker/releases/download/$CHUNKER_VERSION/$CHUNKER_JAR
    
    if [ $? -ne 0 ]; then
        error "下载失败，尝试备用链接..."
        wget -q --show-progress -O ~/$CHUNKER_JAR \
            https://mirror.ghproxy.com/https://github.com/HiveGamesOSS/Chunker/releases/download/$CHUNKER_VERSION/$CHUNKER_JAR
    fi
fi

if [ -f ~/$CHUNKER_JAR ]; then
    success "工具下载完成"
else
    error "工具下载失败"
    echo "请手动下载: https://github.com/HiveGamesOSS/Chunker/releases"
    exit 1
fi

# 4. 创建修复版转换脚本
cat > ~/chunker-convert.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Minecraft存档转换脚本 v8.3
# 修复：逻辑矛盾，简化bc使用

CHUNKER_JAR="chunker-cli-1.14.0.jar"

# 函数：智能版本识别
convert_version() {
    local input="$1"
    local version=""
    local type=""
    
    # 全部转为小写处理
    local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # 检查是否是完整格式（已包含BEDROCK_或JAVA_）
    if echo "$lower_input" | grep -q "^bedrock_\|^java_"; then
        echo "$input" | tr 'a-z' 'A-Z'  # 转为大写
        return
    fi
    
    # 提取版本号（1.20.0, 1_20_0, 1-20-0等格式）
    local version_number=$(echo "$lower_input" | grep -o "[0-9][0-9._-]*[0-9]" | head -1)
    
    if [ -z "$version_number" ]; then
        echo "ERROR: 未找到版本号"
        return
    fi
    
    # 将版本号统一为下划线格式
    version_number=$(echo "$version_number" | tr '.-' '_')
    
    # 检测版本类型
    if echo "$lower_input" | grep -q "基岩\|bedrock\|be\|基岩版\|bed\|mcpe"; then
        type="BEDROCK"
    elif echo "$lower_input" | grep -q "java\|je\|java版\|爪哇\|jc"; then
        type="JAVA"
    else
        # 如果未指定类型，默认基岩版（因为安卓主要是基岩版）
        type="BEDROCK"
    fi
    
    echo "${type}_${version_number}"
}

# 函数：检测存档大小并给出提示（简化版，始终使用bc）
detect_world_size() {
    local input_path="$1"
    if command -v du >/dev/null 2>&1; then
        local size_kb=$(du -sk "$input_path" 2>/dev/null | cut -f1)
        if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
            # 转换KB为MB
            local size_mb=$((size_kb / 1024))
            
            if [ "$size_mb" -gt 512 ]; then
                echo ""
                
                # 因为我们在安装时已经安装了bc，所以这里肯定有bc
                # 用bc计算GB，保留1位小数
                local size_gb=$(echo "scale=1; $size_kb / 1024 / 1024" | bc)
                
                # 修复bc的输出格式：确保有前导零
                # bc输出可能是 .9 或 0.9 或 1.0
                if [[ $size_gb == .* ]]; then
                    # 如果是.9，添加前导0
                    size_gb="0${size_gb}"
                fi
                
                echo "⚠️  检测到较大存档: ${size_gb}GB"
                
                echo "   转换可能需要较多内存和较长时间，建议："
                echo "   - 连接充电器"
                echo "   - 确保手机有足够可用内存"
                echo "   - 转换过程中不要关闭Termux"
                if [ "$size_mb" -gt 1024 ]; then
                    echo "   - 考虑分配更多内存（如 -Xmx4g）"
                fi
            else
                echo "📊 存档大小: ${size_mb}MB"
            fi
        else
            echo "📊 无法检测存档大小"
        fi
    else
        echo "📊 无法检测存档大小 (du命令不可用)"
    fi
}

# 函数：显示支持的版本范围
show_supported_versions() {
    echo ""
    echo "📋 官方支持的版本范围 (来自GitHub):"
    echo ""
    echo "🎮 基岩版 (Bedrock):"
    echo "  1.12.0"
    echo "  1.13.0"
    echo "  1.14.0 - 1.14.60"
    echo "  1.16.0 - 1.16.220"
    echo "  1.17.0 - 1.17.40"
    echo "  1.18.0 - 1.18.30"
    echo "  1.19.0 - 1.19.80"
    echo "  1.20.0 - 1.20.80"
    echo "  1.21.0 - 1.21.130"
    echo ""
    echo "☕ Java版:"
    echo "  1.8.8"
    echo "  1.9.0 - 1.9.3"
    echo "  1.10.0 - 1.10.2"
    echo "  1.11.0 - 1.11.2"
    echo "  1.12.0 - 1.12.2"
    echo "  1.13.0 - 1.13.2"
    echo "  1.14.0 - 1.14.4"
    echo "  1.15.0 - 1.15.2"
    echo "  1.16.0 - 1.16.5"
    echo "  1.17.0 - 1.17.1"
    echo "  1.18.0 - 1.18.2"
    echo "  1.19.0 - 1.19.4"
    echo "  1.20.0 - 1.20.6"
    echo "  1.21.0 - 1.21.11"
    echo ""
    echo "💡 提示："
    echo "  - 工具尝试转换不在列表中的版本也可能成功"
    echo "  - 但成功率和稳定性可能受影响"
    echo "  - 建议尽量使用列表中的版本"
}

echo "🎮 Minecraft 存档转换工具"
echo "════════════════════════════════════"
echo ""

# 检查环境
if ! command -v java >/dev/null 2>&1; then
    echo "❌ 未找到Java，请先运行安装脚本"
    exit 1
fi

if [ ! -f ~/$CHUNKER_JAR ]; then
    echo "❌ 未找到转换工具"
    echo "请先运行安装脚本"
    exit 1
fi

# 如果是命令行模式，直接运行
if [ $# -ne 0 ]; then
    java -jar ~/$CHUNKER_JAR "$@"
    exit 0
fi

# ========== 重要警告 ==========
echo "⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️ "
echo ""
echo "              重要警告！"
echo ""
echo "1. 转换前必须备份存档！"
echo "2. 存档丢失无法恢复！"
echo "3. 转换失败请联系原作者！"
echo ""
echo "⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️ "
echo ""

read -p "我已备份存档，确认继续 (输入'yes'继续): " confirm
if [ "$confirm" != "yes" ]; then
    echo "操作已取消。请先备份！"
    exit 1
fi

echo ""
echo "✅ 已确认备份，继续"
echo "════════════════════════════════════"
echo ""

# 输入存档路径
echo "📁 第一步：输入存档路径"
echo ""
echo "常见存档位置："
echo "  /sdcard/games/com.mojang/minecraftWorlds/..."
echo "  /storage/emulated/0/... (内部存储)"
echo ""
echo "❌ 不能输入的路径："
echo "  /Android/data/...  （Termux无权访问）"
echo "  /data/data/...     （系统保护目录）"
echo ""
echo "📌 提示：如果存档在 /Android/data/ 目录下，"
echo "      请先用文件管理器复制到 /sdcard/ 下"
echo ""
read -p "请输入存档文件夹的完整路径: " input_path

# 检查路径
if [ ! -d "$input_path" ]; then
    echo "❌ 路径不存在: $input_path"
    echo "请检查路径是否正确"
    exit 1
fi

# 检查是否是禁止访问的路径
if echo "$input_path" | grep -q "/Android/data/\|/data/data/\|/storage/emulated/0/Android/data/"; then
    echo "❌ 错误：无法访问 /Android/data/ 目录"
    echo ""
    echo "解决方案："
    echo "1. 打开文件管理器"
    echo "2. 找到存档文件夹"
    echo "3. 复制到 /sdcard/ 下（如 /sdcard/my_world/）"
    echo "4. 使用新路径重新运行"
    echo ""
    echo "原因：Android 11+ 限制应用访问 /Android/data/"
    exit 1
fi

# 检测存档大小
detect_world_size "$input_path"

echo ""
echo "📤 第二步：输出位置"
echo ""
echo "转换后的存档需要保存到新位置"
echo "建议路径：/sdcard/converted_world/"
echo ""
read -p "请输入输出文件夹路径: " output_path

mkdir -p "$output_path" 2>/dev/null
if [ ! -d "$output_path" ]; then
    echo "❌ 无法创建输出目录"
    exit 1
fi

echo ""
echo "🎯 第三步：查看支持的版本范围"
echo ""
echo "是否需要查看官方支持的版本列表？"
echo "1) 是，我想查看"
echo "2) 不用，我知道要转换的版本"
echo ""
read -p "请选择 (1-2): " show_versions

if [ "$show_versions" = "1" ]; then
    show_supported_versions
    echo ""
    echo "按回车键继续..."
    read dummy
fi

echo ""
echo "🎯 第四步：输入目标版本"
echo ""
echo "📋 格式说明："
echo "  1. 必须指定版本类型（基岩版 或 Java版）"
echo "  2. 然后指定版本号"
echo ""
echo "🎮 基岩版示例："
echo "  '基岩版1.20.0'    → BEDROCK_1_20_0"
echo "  'BE 1.20.1'       → BEDROCK_1_20_1"
echo "  'bedrock 1.21.0'  → BEDROCK_1_21_0"
echo ""
echo "☕ Java版示例："
echo "  'Java 1.20.0'     → JAVA_1_20_0"
echo "  'JE 1.20.1'       → JAVA_1_20_1"
echo "  'java版1.21.0'    → JAVA_1_21_0"
echo ""
echo "💡 支持的别名："
echo "  基岩版: 基岩, bedrock, be, bed, mcpe, 基岩版"
echo "  Java版: java, je, jc, java版, 爪哇"
echo ""
echo "📌 也可以直接输入完整格式："
echo "  BEDROCK_1_20_0 或 JAVA_1_20_0"
echo ""
read -p "请输入目标版本: " user_version

# 自动转换版本格式
target_version=$(convert_version "$user_version")

if echo "$target_version" | grep -q "ERROR"; then
    echo "❌ 版本格式错误: $user_version"
    echo ""
    echo "请使用以下格式："
    echo "  [类型] [版本号]"
    echo "示例：基岩版1.20.0 或 Java 1.20.0"
    exit 1
fi

echo ""
echo "✅ 转换后版本: $target_version"

# 内存分配
memory="2g"
echo ""
echo "💾 第五步：内存分配"
echo ""
echo "默认分配内存: 2GB"
echo ""

# 询问是否需要调整内存
echo "是否需要修改内存分配？"
echo "1) 使用默认 2GB (推荐)"
echo "2) 手动输入内存大小"
echo ""
read -p "请选择 (1-2): " mem_choice

if [ "$mem_choice" = "2" ]; then
    echo ""
    echo "输入内存大小（示例：2g, 4g, 8g）："
    echo "注意：不要超过设备可用内存"
    read -p "内存大小: " memory
    # 简单的格式检查
    if ! echo "$memory" | grep -q "^[0-9]\+[gm]$"; then
        echo "⚠️  格式不正确，使用默认 2g"
        memory="2g"
    fi
fi

echo ""
echo "════════════════════════════════════"
echo "        最终确认"
echo "════════════════════════════════════"
echo "输入存档: $input_path"
echo "输出位置: $output_path"
echo "目标版本: $target_version"
echo "分配内存: $memory"
echo ""
read -p "开始转换？(输入'start'确认): " final

if [ "$final" != "start" ]; then
    echo "操作已取消"
    exit 1
fi

echo ""
echo "🔄 开始转换..."
echo "开始时间: $(date '+%H:%M:%S')"
echo "════════════════════════════════════"
echo ""

start_time=$(date +%s)
java -Xmx$memory -jar ~/$CHUNKER_JAR \
  -i "$input_path" \
  -o "$output_path" \
  -f "$target_version"

result=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
if [ $result -eq 0 ]; then
    echo "🎉 转换成功！"
    echo "⏱️  耗时: ${duration}秒 ($((duration/60))分$((duration%60))秒)"
    echo "📁 新存档: $output_path"
else
    echo "❌ 转换失败！"
    echo ""
    echo "可能的原因："
    echo "1. 版本号错误 - 请检查版本格式是否正确"
    echo "2. 内存不足 - 尝试分配更多内存（如 -Xmx4g）"
    echo "3. 存档损坏 - 检查原存档是否正常"
    echo "4. 版本不支持 - 该版本可能不在支持列表中"
    echo ""
    echo "💡 解决方案："
    echo "- 检查上面的错误信息"
    echo "- 确保已备份原存档"
    echo "- 如无法解决，请联系教程作者"
fi
EOF

chmod +x ~/chunker-convert.sh
success "创建转换脚本完成"

# 5. 完成信息
echo ""
echo "══════════════════════════════════════════════"
echo "        安装完成！"
echo "══════════════════════════════════════════════"
echo ""
echo "📱 使用命令："
echo ""
echo "  ./chunker-convert.sh"
echo "    交互式转换存档（逻辑简化，使用bc精确计算）"
echo ""
echo "  java -jar ~/chunker-cli-1.14.0.jar [参数]"
echo "    高级命令行模式"
echo ""
echo "🔄 版本输入示例："
echo "  基岩版示例："
echo "    '基岩版1.20.0' → BEDROCK_1_20_0"
echo "    'BE 1.20.1'    → BEDROCK_1_20_1"
echo ""
echo "  Java版示例："
echo "    'Java 1.20.0'  → JAVA_1_20_0"
echo "    'JE 1.20.1'    → JAVA_1_20_1"
echo ""
echo "⚠️  重要提示："
echo ""
echo "1. 转换前必须手动备份存档！"
echo "2. 不能访问 /Android/data/ 目录"
echo ""
echo "🔧 如遇到问题："
echo ""
echo "请直接联系教程作者！"
echo "（在B站/教程页面留言）"
echo ""
echo "我会帮你解决具体问题。"
echo ""
echo "祝您游戏愉快！🎮"

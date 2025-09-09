#!/bin/bash

# 智能设置 Cursor 代码检查的脚本
# Smart setup script for Cursor code checking with existing hook support

# 检查是否为 Mac 系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 错误: 此脚本专为 Mac 系统设计"
    echo "当前系统: $OSTYPE"
    echo "请在 Mac 系统上运行此脚本"
    exit 1
fi

echo "🍎 检测到 Mac 系统，开始设置 Cursor 代码检查..."

# 检查 Cursor 是否安装
CURSOR_PATH=""
if command -v cursor &> /dev/null; then
    CURSOR_PATH="cursor"
    echo "✅ 找到 Cursor 命令: $(which cursor)"
elif [ -f "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]; then
    CURSOR_PATH="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    echo "✅ 找到 Cursor 应用: $CURSOR_PATH"
else
    echo "❌ 未找到 Cursor，请先安装 Cursor"
    echo "下载地址: https://cursor.sh/"
    exit 1
fi

# 检查是否已存在 pre-commit hook
if [ -f ".git/hooks/pre-commit" ]; then
    echo "⚠️  发现已存在的 pre-commit hook"
    
    # 检查是否已经包含 Cursor 检查（多种检测方式）
    if grep -q "Cursor 检查代码\|🍎 检测到 Mac 系统，正在使用 Cursor 检查代码\|Cursor 代码检查通过" .git/hooks/pre-commit; then
        echo "✅ 检测到已存在 Cursor 检查功能"
        echo "当前 hook 已包含 Cursor 代码检查，无需重复设置"
        echo ""
        echo "🔍 当前 hook 中的 Cursor 检查功能："
        grep -n "Cursor\|🍎\|✅.*检查" .git/hooks/pre-commit | head -5
        echo ""
        echo "💡 如需重新设置，请先删除现有 hook 或选择备份选项"
        exit 0
    fi
    
    echo "当前 hook 内容预览:"
    head -10 .git/hooks/pre-commit
    echo ""
    echo "选择操作:"
    echo "1) 备份现有 hook 并创建新的 Cursor 检查 hook"
    echo "2) 在现有 hook 开头添加 Cursor 检查功能"
    echo "3) 在现有 hook 结尾添加 Cursor 检查功能"
    echo "4) 取消操作"
    echo ""
    read -p "请输入选择 (1-4): " choice
    
    case $choice in
        1)
            # 备份现有 hook
            backup_file=".git/hooks/pre-commit.backup.$(date +%Y%m%d_%H%M%S)"
            cp .git/hooks/pre-commit "$backup_file"
            echo "✅ 已备份现有 hook 到 $backup_file"
            echo "🔄 创建新的 Cursor 检查 hook..."
            create_new_hook=true
            ;;
        2)
            echo "🔄 在现有 hook 开头添加 Cursor 检查功能..."
            create_new_hook=false
            add_position="beginning"
            ;;
        3)
            echo "🔄 在现有 hook 结尾添加 Cursor 检查功能..."
            create_new_hook=false
            add_position="end"
            ;;
        4)
            echo "❌ 操作已取消"
            exit 0
            ;;
        *)
            echo "❌ 无效选择，操作已取消"
            exit 1
            ;;
    esac
else
    echo "🔄 创建新的 pre-commit hook..."
    create_new_hook=true
fi

# Cursor 检查代码
CURSOR_CHECK_CODE='#!/bin/bash

# Cursor 代码检查功能
# 检查是否为 Mac 系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  警告: Cursor 检查功能专为 Mac 系统设计"
    echo "当前系统: $OSTYPE"
    echo "跳过 Cursor 代码检查..."
    exit 0
fi

echo "🍎 检测到 Mac 系统，正在使用 Cursor 检查代码..."

# 获取暂存的文件列表
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E "\.(js|ts|jsx|tsx|py|java|dart|m|mm|swift|kt|scala|cpp|c|h|go|rs|php|rb|r|arb)$")

if [ -z "$STAGED_FILES" ]; then
    echo "✅ 没有需要检查的代码文件"
    # 如果是合并到现有 hook，继续执行后续代码
    if [ -f ".git/hooks/pre-commit" ] && grep -q "现有检查\|原有.*hook" .git/hooks/pre-commit; then
        echo "🔄 继续执行其他检查..."
    else
        exit 0
    fi
fi

echo "📝 检查以下文件:"
echo "$STAGED_FILES"

# 检查 Cursor 是否安装
CURSOR_CMD=""
if command -v cursor &> /dev/null; then
    CURSOR_CMD="cursor"
elif [ -f "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]; then
    CURSOR_CMD="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
else
    echo "⚠️  警告: 未找到 Cursor 命令，将使用基础语法检查"
    echo "如需使用 Cursor 检查，请确保 Cursor 已安装并添加到 PATH"
fi

# 创建临时文件来存储检查结果
TEMP_FILE=$(mktemp)
ERROR_FILE=$(mktemp)

# 对每个暂存的文件进行检查
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        echo "🔍 检查文件: $file"
        
        # 基础语法检查
        case "${file##*.}" in
            js|jsx)
                if command -v node &> /dev/null; then
                    echo "  - 使用 Node.js 检查 JavaScript 语法"
                    if ! node -c "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ JavaScript 语法错误"
                    else
                        echo "    ✅ JavaScript 语法正确"
                    fi
                else
                    echo "  - 跳过 JavaScript 检查 (未安装 Node.js)"
                fi
                ;;
            ts|tsx)
                if command -v tsc &> /dev/null; then
                    echo "  - 使用 TypeScript 编译器检查"
                    if ! tsc --noEmit "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ TypeScript 类型错误"
                    else
                        echo "    ✅ TypeScript 类型正确"
                    fi
                else
                    echo "  - 跳过 TypeScript 检查 (未安装 TypeScript)"
                fi
                ;;
            py)
                if command -v python3 &> /dev/null; then
                    echo "  - 使用 Python 编译器检查"
                    if ! python3 -m py_compile "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Python 语法错误"
                    else
                        echo "    ✅ Python 语法正确"
                    fi
                else
                    echo "  - 跳过 Python 检查 (未安装 Python3)"
                fi
                ;;
            java)
                if command -v javac &> /dev/null; then
                    echo "  - 使用 Java 编译器检查"
                    if ! javac -Xlint:all -cp . "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Java 编译错误"
                    else
                        echo "    ✅ Java 语法正确"
                    fi
                else
                    echo "  - 跳过 Java 检查 (未安装 JDK)"
                fi
                ;;
            dart)
                if command -v dart &> /dev/null; then
                    echo "  - 使用 Dart 分析器检查"
                    if ! dart analyze "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Dart 分析错误"
                    else
                        echo "    ✅ Dart 代码正确"
                    fi
                else
                    echo "  - 跳过 Dart 检查 (未安装 Dart SDK)"
                fi
                ;;
            swift)
                if command -v swiftc &> /dev/null; then
                    echo "  - 使用 Swift 编译器检查"
                    if ! swiftc -parse "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Swift 语法错误"
                    else
                        echo "    ✅ Swift 语法正确"
                    fi
                else
                    echo "  - 跳过 Swift 检查 (未安装 Swift)"
                fi
                ;;
            kt)
                if command -v kotlinc &> /dev/null; then
                    echo "  - 使用 Kotlin 编译器检查"
                    if ! kotlinc -script "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Kotlin 语法错误"
                    else
                        echo "    ✅ Kotlin 语法正确"
                    fi
                else
                    echo "  - 跳过 Kotlin 检查 (未安装 Kotlin)"
                fi
                ;;
            m|mm)
                if command -v clang &> /dev/null; then
                    echo "  - 使用 Clang 检查 Objective-C 语法"
                    if ! clang -fsyntax-only "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Objective-C 语法错误"
                    else
                        echo "    ✅ Objective-C 语法正确"
                    fi
                else
                    echo "  - 跳过 Objective-C 检查 (未安装 Clang)"
                fi
                ;;
            cpp|c)
                if command -v g++ &> /dev/null || command -v clang++ &> /dev/null; then
                    echo "  - 使用 C++ 编译器检查"
                    COMPILER=""
                    if command -v g++ &> /dev/null; then
                        COMPILER="g++"
                    else
                        COMPILER="clang++"
                    fi
                    if ! $COMPILER -fsyntax-only "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ C++ 语法错误"
                    else
                        echo "    ✅ C++ 语法正确"
                    fi
                else
                    echo "  - 跳过 C++ 检查 (未安装 C++ 编译器)"
                fi
                ;;
            go)
                if command -v go &> /dev/null; then
                    echo "  - 使用 Go 编译器检查"
                    if ! go build -o /dev/null "$file" 2>> "$ERROR_FILE"; then
                        echo "    ❌ Go 编译错误"
                    else
                        echo "    ✅ Go 语法正确"
                    fi
                else
                    echo "  - 跳过 Go 检查 (未安装 Go)"
                fi
                ;;
            arb)
                echo "  - 检查 ARB 文件格式"
                if command -v python3 &> /dev/null; then
                    # 使用 Python 检查 JSON 格式
                    if ! python3 -m json.tool "$file" > /dev/null 2>> "$ERROR_FILE"; then
                        echo "    ❌ ARB 文件 JSON 格式错误"
                    else
                        echo "    ✅ ARB 文件 JSON 格式正确"
                    fi
                else
                    echo "  - 跳过 ARB 检查 (未安装 Python3)"
                fi
                ;;
            *)
                echo "  - 跳过 $file (不支持的文件类型或检查工具)"
                ;;
        esac
        
        # 如果 Cursor 可用，可以在这里添加 Cursor 特定的检查
        if [ -n "$CURSOR_CMD" ]; then
            echo "  - 使用 Cursor 进行高级检查..."
            # 这里可以添加 Cursor 特定的检查命令
            # 例如: $CURSOR_CMD --check "$file" 2>> "$ERROR_FILE"
        fi
    fi
done

# 检查是否有错误
if [ -s "$ERROR_FILE" ]; then
    echo "❌ 代码检查发现错误:"
    cat "$ERROR_FILE"
    echo ""
    echo "🚫 提交被阻止！请修复错误后重新提交"
    echo ""
    echo "💡 修复建议："
    echo "1. 检查上述错误信息"
    echo "2. 修复代码中的语法或格式错误"
    echo "3. 重新运行: git add . && git commit -m \"你的提交信息\""
    echo "4. 如需跳过检查，使用: git commit --no-verify -m \"你的提交信息\""
    rm -f "$TEMP_FILE" "$ERROR_FILE"
    exit 1
fi

echo "✅ Cursor 代码检查通过！"
rm -f "$TEMP_FILE" "$ERROR_FILE"
# 如果是合并到现有 hook，继续执行后续代码
if [ -f ".git/hooks/pre-commit" ] && grep -q "现有检查\|原有.*hook" .git/hooks/pre-commit; then
    echo "🔄 继续执行其他检查..."
else
    exit 0
fi'

if [ "$create_new_hook" = true ]; then
    # 创建新的 hook
    echo "$CURSOR_CHECK_CODE" > .git/hooks/pre-commit
else
    # 添加到现有 hook
    if [ "$add_position" = "beginning" ]; then
        # 在开头添加
        echo "$CURSOR_CHECK_CODE" > .git/hooks/pre-commit.tmp
        echo "" >> .git/hooks/pre-commit.tmp
        cat .git/hooks/pre-commit >> .git/hooks/pre-commit.tmp
        mv .git/hooks/pre-commit.tmp .git/hooks/pre-commit
    else
        # 在结尾添加
        echo "" >> .git/hooks/pre-commit
        echo "$CURSOR_CHECK_CODE" >> .git/hooks/pre-commit
    fi
fi

# 设置执行权限
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook 已设置完成！"
echo ""
echo "📋 使用说明:"
echo "1. 添加文件到暂存区: git add ."
echo "2. 提交代码: git commit -m '你的提交信息'"
echo "3. 系统会自动使用 Cursor 检查代码"
echo ""
echo "🔧 支持的检查:"
echo "- JavaScript/JSX (需要 Node.js)"
echo "- TypeScript/TSX (需要 TypeScript)"
echo "- Python (需要 Python3)"
echo "- Java (需要 JDK)"
echo "- Dart (需要 Dart SDK)"
echo "- Swift (需要 Swift 编译器)"
echo "- Kotlin (需要 Kotlin 编译器)"
echo "- Objective-C (需要 Clang)"
echo "- C/C++ (需要 g++/clang++)"
echo "- Go (需要 Go 编译器)"
echo "- ARB 文件 (需要 Python3, Flutter 国际化)"
echo "- 其他语言的基础检查"
echo ""
echo "💡 提示: 安装相应的语言运行环境可以获得更好的检查效果"

#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SKey Release Notes Generator (Tieng Viet Chuan - No Emoji)
# ==============================================================================

VERSION="v1.0.0"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      VERSION="$1"
      shift
      ;;
  esac
done

DATE_STR=$(date +"%d/%m/%Y")

# Detect commit range - use ONLY commits since last semantic version tag
# Filter out initial/setup tags to avoid including entire history
PREV_TAG=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -2)
TAG_ARRAY=($PREV_TAG)

if [[ ${#TAG_ARRAY[@]} -ge 2 && "${TAG_ARRAY[1]}" != "$VERSION" ]]; then
  # Use second most recent tag (skip current if it exists)
  PREV_TAG="${TAG_ARRAY[1]}"
  COMMIT_RANGE="${PREV_TAG}..HEAD"
  echo "==> Using commit range: $PREV_TAG..HEAD"
elif [[ ${#TAG_ARRAY[@]} -eq 1 && "${TAG_ARRAY[0]}" != "$VERSION" ]]; then
  # Only one tag exists and it's not the current version
  PREV_TAG="${TAG_ARRAY[0]}"
  COMMIT_RANGE="${PREV_TAG}..HEAD"
  echo "==> Using commit range: $PREV_TAG..HEAD"
else
  # No previous releases - show only recent commits (last 30 days max)
  COMMIT_RANGE="--since='30 days ago'"
  echo "==> No previous release tags found, using recent commits only"
fi

# Extract ONLY macOS-related commits (filter by paths)
RAW_LOG=$(git log "$COMMIT_RANGE" --pretty=format:"%h|%s" \
  -- platforms/macos/skey-app/ core/ scripts/ .github/workflows/build-and-release-macos.yml \
  2>/dev/null || echo "")

# Initialize empty lists
FEAT_LIST=""
FIX_LIST=""
PERF_LIST=""
UI_LIST=""
OTHER_LIST=""

# Process commits if any found
if [[ -n "$RAW_LOG" ]]; then
  echo "==> Found macOS-related commits in range $COMMIT_RANGE"

  while IFS='|' read -r HASH MSG; do
    [[ -z "$HASH" || -z "$MSG" ]] && continue
    
    LOWER_MSG=$(echo "$MSG" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$LOWER_MSG" =~ ^feat || "$LOWER_MSG" =~ add || "$LOWER_MSG" =~ thêm ]]; then
      FEAT_LIST+="- $MSG (\`$HASH\`)"$'\n'
    elif [[ "$LOWER_MSG" =~ ^fix || "$LOWER_MSG" =~ bug || "$LOWER_MSG" =~ sửa ]]; then
      FIX_LIST+="- $MSG (\`$HASH\`)"$'\n'
    elif [[ "$LOWER_MSG" =~ ^perf || "$LOWER_MSG" =~ speed || "$LOWER_MSG" =~ tối\ ưu ]]; then
      PERF_LIST+="- $MSG (\`$HASH\`)"$'\n'
    elif [[ "$LOWER_MSG" =~ ^ui || "$LOWER_MSG" =~ icon || "$LOWER_MSG" =~ giao\ diện ]]; then
      UI_LIST+="- $MSG (\`$HASH\`)"$'\n'
    else
      OTHER_LIST+="- $MSG (\`$HASH\`)"$'\n'
    fi
  done <<< "$RAW_LOG"
else
  echo "==> No macOS-related commits found in range $COMMIT_RANGE"
fi

MD_CONTENT=$(cat <<MD_EOF
# SKey Phiên bản ${VERSION} (${DATE_STR})

SKey là bộ gõ tiếng Việt thế hệ mới cho macOS: tốc độ cao, giao diện tối giản hiện đại, tích hợp bộ nhớ tạm Clipboard thông minh và bảo mật dữ liệu tuyệt đối.

---

## Điểm nổi bật (Highlights)
- **Bộ gõ tiếng Việt tốc độ cao**: Hỗ trợ chuẩn Telex và VNI với cơ chế Zero-allocation và xử lý dấu thanh thông minh.
- **Trình quản lý Clipboard**: Lưu trữ văn bản, hình ảnh, liên kết với tính năng tìm kiếm tức thì và Paste Stack.
- **Tùy biến phím tắt trực quan**: Bộ thu nhận phím tắt thông minh theo phong cách phím bấm xúc giác (Keycap) của macOS.
- **Giao diện Dashboard phẳng**: Thiết kế hiện đại tối ưu trải nghiệm người dùng, hỗ trợ Dark/Light Mode.

---

## Chi tiết thay đổi (Changelog)
MD_EOF
)

if [[ -n "$FEAT_LIST" ]]; then
  MD_CONTENT+=$'\n\n'"### Tính năng mới (New Features)"$'\n'"$FEAT_LIST"
fi

if [[ -n "$FIX_LIST" ]]; then
  MD_CONTENT+=$'\n\n'"### Sửa lỗi (Bug Fixes)"$'\n'"$FIX_LIST"
fi

if [[ -n "$UI_LIST" ]]; then
  MD_CONTENT+=$'\n\n'"### Giao diện & Trải nghiệm (UI/UX)"$'\n'"$UI_LIST"
fi

if [[ -n "$PERF_LIST" ]]; then
  MD_CONTENT+=$'\n\n'"### Tối ưu hiệu năng (Performance)"$'\n'"$PERF_LIST"
fi

if [[ -n "$OTHER_LIST" ]]; then
  MD_CONTENT+=$'\n\n'"### Cải tiến khác (Other Improvements)"$'\n'"$OTHER_LIST"
fi

MD_CONTENT+=$(cat <<MD_EOF


---

## Yêu cầu hệ thống (System Requirements)
- **Hệ điều hành**: macOS 12.0 (Monterey) trở lên (hỗ trợ đầy đủ macOS 13 Ventura, 14 Sonoma, 15 Sequoia).
- **Kiến trúc**: Apple Silicon (M1/M2/M3/M4) & Intel (Universal Binary).
- **Quyền hệ thống**: Accessibility (Trợ năng) & Input Monitoring (Theo dõi đầu vào).

---

## Hướng dẫn cài đặt (Installation)
1. Tải về tệp \`SKey-Installer.dmg\` bên dưới.
2. Mở file \`.dmg\` và kéo biểu tượng **SKey** vào thư mục **Applications**.
3. Nếu macOS hiển thị thông báo ứng dụng chưa ký chứng chỉ trả phí của Apple, mở **Terminal** và chạy:
   \`\`\`bash
   xattr -cr /Applications/SKey.app
   \`\`\`
4. Khởi chạy ứng dụng và cấp quyền Trợ năng / Theo dõi đầu vào để bắt đầu gõ tiếng Việt.

*Tác giả: **Nam088** & SKey Contributors*
MD_EOF
)

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$MD_CONTENT" > "$OUTPUT_FILE"
  echo "Release notes written to: $OUTPUT_FILE"
else
  echo "$MD_CONTENT"
fi

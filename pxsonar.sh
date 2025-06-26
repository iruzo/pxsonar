#!/bin/sh

show_usage() {
    echo "Usage: $0 [--summary|-s] [--concurrency|-c N] <file_or_directory>" >&2
    echo "  --summary, -s: Show URLs with their source files (for directories) and summary statistics" >&2
    echo "  --concurrency, -c N: Set number of concurrent requests (default: 20)" >&2
    exit 1
}

if [ $# -eq 0 ]; then
    show_usage
fi

max_jobs='20'
show_summary='false'
input=''

while [ $# -gt 0 ]; do
    case "$1" in
        --summary|-s)
            show_summary='true'
            ;;
        --concurrency|-c)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: --concurrency requires a number" >&2
                show_usage
            fi
            if ! echo "$1" | grep -q '^[1-9][0-9]*$'; then
                echo "Error: Concurrency must be a positive integer" >&2
                show_usage
            fi
            max_jobs="$1"
            ;;
        -*)
            echo "Error: Invalid argument '$1'" >&2
            show_usage
            ;;
        *)
            if [ -z "$input" ]; then
                input="$1"
            else
                echo "Error: Multiple file/directory arguments provided" >&2
                show_usage
            fi
            ;;
    esac
    shift
done

if [ -z "$input" ]; then
    echo "Error: No file or directory specified" >&2
    show_usage
fi

if [ ! -e "$input" ]; then
    echo "Error: '$input' not found" >&2
    exit 1
fi

extract_urls() {
    if [ -f "$input" ]; then
        # Single file
        if [ "$show_summary" = 'true' ]; then
            grep -oE 'https?://[^[:space:]]+' "$input" | while read -r url; do
                echo "$url"
            done
        else
            grep -oE 'https?://[^[:space:]]+' "$input"
        fi
    elif [ -d "$input" ]; then
        # Directory - search recursively in all files
        find "$input" -type f -exec grep -l 'https\?://' {} \; 2>/dev/null | while read -r file; do
            if [ "$show_summary" = 'true' ]; then
                grep -oE 'https?://[^[:space:]]+' "$file" 2>/dev/null | while read -r url; do
                    echo "$file: $url"
                done
            else
                grep -oE 'https?://[^[:space:]]+' "$file" 2>/dev/null
            fi
        done
    else
        echo "Error: '$input' is neither a file nor a directory" >&2
        exit 1
    fi
}

if command -v curl >/dev/null 2>&1; then
    HTTP_CLIENT='curl'
elif command -v wget >/dev/null 2>&1; then
    HTTP_CLIENT='wget'
else
    echo "Error: Neither curl nor wget is installed" >&2
    exit 1
fi

check_url() {
    url="$1"

    if [ "$HTTP_CLIENT" = 'curl' ]; then
        status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" "$url" 2>/dev/null)
        if [ $? -ne 0 ]; then
            status='ERR'
        fi
    else
        # Using wget
        wget --spider --timeout=30 --tries=1 -q -U "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" "$url" >/dev/null 2>&1
        case $? in
            0) status='200' ;;
            4) status='404' ;;
            8) status='ERR' ;;
            *) status='ERR' ;;
        esac
    fi

    printf "%s %s\n" "$status" "$url"
}

if [ "$show_summary" = 'true' ]; then
    echo 'Found URLs:'
    extract_urls
    echo

    if [ -f "$input" ]; then
        urls=$(grep -oE 'https?://[^[:space:]]+' "$input" | sort -u)
        file_count=1
    else
        urls=$(find "$input" -type f -exec grep -l 'https\?://' {} \; 2>/dev/null | while read -r file; do
            grep -oE 'https?://[^[:space:]]+' "$file" 2>/dev/null
        done | sort -u)
        file_count=$(find "$input" -type f -exec grep -l 'https\?://' {} \; 2>/dev/null | wc -l)
    fi
else
    urls=$(extract_urls | sort -u)
    if [ -d "$input" ]; then
        file_count=$(find "$input" -type f -exec grep -l 'https\?://' {} \; 2>/dev/null | wc -l)
    else
        file_count=1
    fi
fi

url_count=$(echo "$urls" | wc -l)

if [ $url_count -eq 0 ]; then
    echo 'No URLs found to check.'
    exit 0
fi

if [ "$show_summary" = 'true' ]; then
    echo
    echo 'Summary:'
    echo "- Total URLs found: $url_count"
    if [ -d "$input" ]; then
        echo "- Files processed: $file_count"
    fi
    exit 0
fi

# Create a temporary script file to avoid quoting issues
temp_script=$(mktemp)
cat > "$temp_script" << 'EOF'
#!/bin/sh
url="$1"
HTTP_CLIENT="$2"

if [ "$HTTP_CLIENT" = 'curl' ]; then
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 10 --max-time 30 -L \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Cache-Control: no-cache" \
        -H "Pragma: no-cache" \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
        "$url" 2>/dev/null)
    if [ $? -ne 0 ]; then
        status='ERR'
    fi
else
    # Using wget
    wget --spider --timeout=30 --tries=1 -q \
        --header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        --header="Accept-Language: en-US,en;q=0.5" \
        --header="Cache-Control: no-cache" \
        -U "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
        "$url" >/dev/null 2>&1
    case $? in
        0) status='200' ;;
        4) status='404' ;;
        8) status='ERR' ;;
        *) status='ERR' ;;
    esac
fi

printf "[%s] %s\n" "$status" "$url"
EOF

chmod +x "$temp_script"

echo "$urls" | tr '\n' '\0' | xargs -0 -I {} -P "$max_jobs" "$temp_script" "{}" "$HTTP_CLIENT"

rm -f "$temp_script"

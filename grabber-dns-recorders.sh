#!/usr/bin/env bash

set -u

dns_records=(
    A AAAA MX NS CNAME TXT SOA PTR SRV CAA DS DNSKEY
)

public_dns=(
    8.8.8.8          # Google Public DNS primary
    8.8.4.4          # Google Public DNS secondary
    1.1.1.1          # Cloudflare primary
    1.0.0.1          # Cloudflare secondary
    9.9.9.9          # Quad9 primary
    149.112.112.112  # Quad9 secondary
    208.67.222.222   # OpenDNS Home primary
    208.67.220.220   # OpenDNS Home secondary
    76.76.2.0        # Control D primary
    76.76.10.0       # Control D secondary
    94.140.14.14     # AdGuard DNS primary
    94.140.15.15     # AdGuard DNS secondary
    185.228.168.9    # CleanBrowsing primary
    185.228.169.9   # CleanBrowsing secondary
    8.26.56.26       # Comodo Secure DNS primary
    8.20.247.20      # Comodo Secure DNS secondary
    76.76.19.19      # Alternate DNS primary
    76.223.122.150   # Alternate DNS secondary
    64.6.64.6        # Verisign Public DNS primary
    64.6.65.6        # Verisign Public DNS secondary
    216.146.35.35    # Dyn DNS primary
    216.146.36.36    # Dyn DNS secondary
    147.93.130.20    # OpenNIC DNS primary
    66.154.118.103   # OpenNIC DNS secondary
    77.88.8.8        # Yandex DNS primary
    77.88.8.1        # Yandex DNS secondary
    94.130.180.225   # DNS for Family primary
    78.47.64.161     # DNS for Family secondary
    74.82.42.42      # Hurricane Electric DNS
    149.112.121.10   # CIRA Canadian Shield primary
    149.112.122.10   # CIRA Canadian Shield secondary
    205.171.3.65     # CenturyLink (Level3) primary
    205.171.2.65     # CenturyLink (Level3) secondary
    216.87.84.211    # OpenNIC DNS alternative primary
    23.90.4.6        # OpenNIC DNS alternative secondary
    84.200.69.80     # DNS.WATCH primary
    84.200.70.40     # DNS.WATCH secondary
    38.132.106.139   # CyberGhost DNS primary
    194.187.251.67   # CyberGhost DNS secondary
    144.76.157.242   # OpenNIC DNS alternative 2 primary
    94.247.43.254    # OpenNIC DNS alternative 2 secondary
    156.154.70.5     # Neustar UltraDNS Public primary
    156.154.71.5     # Neustar UltraDNS Public secondary
    91.239.100.100   # UncensoredDNS primary
    89.233.43.71     # UncensoredDNS secondary
    198.54.117.10    # SafeServe primary
    198.54.117.11    # SafeServe secondary
    104.197.28.121   # SafeSurfer primary
    104.155.237.225  # SafeSurfer secondary
    195.46.39.39     # Safe DNS primary
    195.46.39.40     # Safe DNS secondary
    176.103.130.130  # AdGuard DNS alternative primary
    176.103.130.131  # AdGuard DNS alternative secondary
    208.76.50.50     # SmartViper primary
    208.76.51.51      # SmartViper secondary
)

usage() {
    cat <<EOF
Usage:
  $0 [options] <domain|IP>
  $0 [options] -l TARGETS_FILE

Options:
  --public             Use built-in public DNS servers
  --custom LIST        Comma-separated custom DNS servers
  -d FILE              Read DNS servers from a file
  -l FILE              Read targets from a file
  -o FILE              Save results to a file
  -j N                 Number of parallel DNS servers (default: 10)
  -h, --help           Show help

Examples:
  $0 --public example.com
  $0 --public -j 20 example.com
  $0 --custom 8.8.8.8,1.1.1.1 example.com
  $0 -d dns.txt example.com
  $0 --public -l targets.txt -o results.txt
  $0 --public -d dns.txt -j 20 -l targets.txt -o results.txt

File format:
  One domain, IP address, or DNS server per line.
  Blank lines and lines starting with # are ignored.
EOF
}

is_ipv4() {
    local ip="$1" part
    local -a octets

    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1

    IFS='.' read -r -a octets <<< "$ip"

    for part in "${octets[@]}"; do
        (( 10#$part <= 255 )) || return 1
    done

    return 0
}

is_ipv6() {
    python3 -c '
import ipaddress, sys
try:
    ipaddress.IPv6Address(sys.argv[1])
except ValueError:
    sys.exit(1)
' "$1" >/dev/null 2>&1
}

is_hostname() {
    local host="$1"

    [[ ${#host} -le 253 ]] &&
    [[ "$host" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*\.?$ ]]
}

valid_target() {
    local value="${1%.}"

    is_ipv4 "$value" && return 0

    if [[ "$value" == *:* ]]; then
        is_ipv6 "$value" && return 0
        return 1
    fi

    is_hostname "$value"
}

read_list_file() {
    local file="$1"
    local line

    [[ -f "$file" && -r "$file" ]] || {
        echo "Error: cannot read file: $file" >&2
        return 1
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue
        printf '%s\n' "$line"
    done < "$file"
}

reverse_ip() {
    python3 -c '
import ipaddress, sys
print(ipaddress.ip_address(sys.argv[1]).reverse_pointer)
' "$1"
}

for cmd in dig python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed." >&2
        echo "Debian/Ubuntu: sudo apt install dnsutils python3" >&2
        exit 1
    fi
done

public_enabled=false
custom_enabled=false
custom_input=""
dns_file=""
targets_file=""
output_file=""
target=""
parallel_jobs=10

while [[ $# -gt 0 ]]; do
    case "$1" in
        --public)
            public_enabled=true
            shift
            ;;
        --custom)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "Error: --custom requires a comma-separated list." >&2
                exit 1
            fi
            custom_enabled=true
            custom_input="$2"
            shift 2
            ;;
        -d)
            [[ $# -ge 2 && "$2" != -* ]] || {
                echo "Error: -d requires a DNS server file." >&2
                exit 1
            }
            dns_file="$2"
            shift 2
            ;;
        -l)
            [[ $# -ge 2 && "$2" != -* ]] || {
                echo "Error: -l requires a target list file." >&2
                exit 1
            }
            targets_file="$2"
            shift 2
            ;;
        -o)
            [[ $# -ge 2 && "$2" != -* ]] || {
                echo "Error: -o requires an output filename." >&2
                exit 1
            }
            output_file="$2"
            shift 2
            ;;
        -j)
            [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || {
                echo "Error: -j requires a positive integer." >&2
                exit 1
            }
            parallel_jobs="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            if [[ -n "$target" ]]; then
                echo "Error: specify one target or use -l." >&2
                exit 1
            fi
            target="${1%.}"
            shift
            ;;
    esac
done

if [[ -n "$targets_file" && -n "$target" ]]; then
    echo "Error: use either -l FILE or a positional target." >&2
    exit 1
fi

if [[ -z "$targets_file" && -z "$target" ]]; then
    echo "Error: specify a domain/IP or -l FILE." >&2
    usage
    exit 1
fi

if [[ "$public_enabled" == false &&
      "$custom_enabled" == false &&
      -z "$dns_file" ]]; then
    echo "Error: select --public, --custom, or -d FILE." >&2
    exit 1
fi

targets=()

if [[ -n "$targets_file" ]]; then
    if ! mapfile -t targets < <(read_list_file "$targets_file"); then
        echo "Error: failed to read target file." >&2
        exit 1
    fi

    if [[ ${#targets[@]} -eq 0 ]]; then
        echo "Error: target file is empty." >&2
        exit 1
    fi
else
    targets=("$target")
fi

for item in "${targets[@]}"; do
    if ! valid_target "$item"; then
        echo "Error: invalid target: $item" >&2
        exit 1
    fi
done

selected_dns=()

if [[ "$public_enabled" == true ]]; then
    selected_dns+=("${public_dns[@]}")
fi

if [[ "$custom_enabled" == true ]]; then
    IFS=',' read -r -a custom_dns <<< "$custom_input"

    for server in "${custom_dns[@]}"; do
        server="${server//[[:space:]]/}"

        if [[ -z "$server" ]] ||
           { ! is_ipv4 "$server" &&
             ! is_ipv6 "$server" &&
             ! is_hostname "$server"; }; then
            echo "Error: invalid DNS server: $server" >&2
            exit 1
        fi

        selected_dns+=("$server")
    done
fi

if [[ -n "$dns_file" ]]; then
    file_dns=()

    if ! mapfile -t file_dns < <(read_list_file "$dns_file"); then
        echo "Error: failed to read DNS file." >&2
        exit 1
    fi

    for server in "${file_dns[@]}"; do
        if ! is_ipv4 "$server" &&
           ! is_ipv6 "$server" &&
           ! is_hostname "$server"; then
            echo "Error: invalid DNS server in $dns_file: $server" >&2
            exit 1
        fi

        selected_dns+=("$server")
    done
fi

dns_servers=()
declare -A seen_dns=()

for server in "${selected_dns[@]}"; do
    server="${server%.}"
    key="${server,,}"

    if [[ -z "${seen_dns[$key]+yes}" ]]; then
        dns_servers+=("$server")
        seen_dns["$key"]=1
    fi
done

if [[ ${#dns_servers[@]} -eq 0 ]]; then
    echo "Error: no DNS servers selected." >&2
    exit 1
fi

if [[ -n "$output_file" ]]; then
    if ! touch "$output_file"; then
        echo "Error: cannot write output file: $output_file" >&2
        exit 1
    fi

    exec > >(tee "$output_file") 2>&1
fi

scan_server() {
    local server="$1"
    local query_target="$2"
    shift 2
    local record result status answers

    printf '######## DNS SERVER: %s ########\n' "$server"

    for record in "$@"; do
        printf '\n--- %s %s ---\n' "$record" "$query_target"

        result=$(dig @"$server" "$query_target" "$record" \
            +time=2 +tries=1 +noall +comments +answer 2>&1)
        status=$?

        if [[ $status -ne 0 ]] ||
           grep -qiE 'communications error|timed out|no servers could be reached' <<< "$result"; then
            echo "[ERROR] Query failed or timed out"
        elif grep -q 'status: NXDOMAIN' <<< "$result"; then
            echo "[NXDOMAIN] Name does not exist"
        elif grep -qE 'status: (SERVFAIL|REFUSED|FORMERR)' <<< "$result"; then
            grep -oE 'status: [A-Z]+' <<< "$result" | head -n 1
        elif grep -q 'status: NOERROR' <<< "$result"; then
            answers=$(sed -n '/;; ANSWER SECTION:/,$p' <<< "$result" |
                grep -v '^;;' || true)

            if [[ -n "$answers" ]]; then
                printf '%s\n' "$answers"
            else
                echo "[NO ANSWER]"
            fi
        else
            echo "[ERROR] Unexpected DNS response"
        fi
    done
}

tmpdir=$(mktemp -d) || {
    echo "Error: cannot create temporary directory." >&2
    exit 1
}
trap 'rm -rf "$tmpdir"' EXIT

echo "=================================================="
echo "Targets:       ${#targets[@]}"
echo "DNS servers:   ${#dns_servers[@]}"
echo "Parallel jobs: $parallel_jobs"
echo "Mode:          public=$public_enabled custom=$custom_enabled"
echo "Output:        ${output_file:-terminal}"
echo "=================================================="

for target in "${targets[@]}"; do
    echo
    echo "=================================================="
    echo "TARGET: $target"
    echo "=================================================="

    is_ip=false

    if is_ipv4 "$target" || [[ "$target" == *:* ]]; then
        is_ip=true
    fi

    if [[ "$is_ip" == true ]]; then
        query_target=$(reverse_ip "$target") || {
            echo "[ERROR] Could not convert IP: $target"
            continue
        }
        query_records=(PTR)
    else
        query_target="$target"
        query_records=("${dns_records[@]}")
    fi

    server_count=${#dns_servers[@]}

    for ((start = 0; start < server_count; start += parallel_jobs)); do
        batch_pids=()
        batch_indices=()

        for ((offset = start; offset < start + parallel_jobs && offset < server_count; offset++)); do
            server="${dns_servers[$offset]}"
            result_file="$tmpdir/result_$offset"

            scan_server "$server" "$query_target" "${query_records[@]}" \
                > "$result_file" 2>&1 &

            batch_pids+=("$!")
            batch_indices+=("$offset")
        done

        for pid in "${batch_pids[@]}"; do
            wait "$pid" || true
        done

        for offset in "${batch_indices[@]}"; do
            cat "$tmpdir/result_$offset"
        done
    done
done

echo
echo "=============== SCAN COMPLETE ==============="

if [[ -n "$output_file" ]]; then
    echo "Results saved to: $output_file"
fi

# grabber-dns-recorders

Multi-server DNS lookup tool written in Bash. Query DNS records across public and custom DNS resolvers, scan multiple domains and IP addresses, and export results to a file.

## Features

- Query 12 DNS record types: `A`, `AAAA`, `MX`, `NS`, `CNAME`, `TXT`, `SOA`, `PTR`, `SRV`, `CAA`, `DS`, `DNSKEY`.
- Use built-in public DNS servers or specify custom servers.
- Load DNS servers and targets from files.
- Scan multiple domains and IP addresses.
- Save results to an output file.
- Detect DNS errors and missing records.

## Requirements

- Bash
- `dig` (`dnsutils`)
- Python 3

## Installation

```bash
sudo apt install dnsutils python3
chmod +x grabber-dns-recorders.sh
```

## Usage

```bash
# Use public DNS servers
./grabber-dns-recorders.sh --public example.com

# Use custom DNS servers
./grabber-dns-recorders.sh --custom 8.8.8.8,1.1.1.1 example.com

# Load DNS servers from a file
./grabber-dns-recorders.sh -d dns.txt example.com

# Scan targets from a file and save results
./grabber-dns-recorders.sh --public -l targets.txt -o results.txt

# Combine public and file-based DNS servers
./grabber-dns-recorders.sh --public -d dns.txt -l targets.txt -o results.txt

# Display help
./grabber-dns-recorders.sh --help
```

## File Formats

- `targets.txt` — one domain or IP address per line.
- `dns.txt` — one DNS server IP address or hostname per line.

Blank lines and lines starting with `#` are ignored.

## License

MIT

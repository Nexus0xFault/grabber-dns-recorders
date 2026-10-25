# grabber-dns-recorders

A parallel multi-server DNS lookup tool written in Bash. Query DNS records using public and custom DNS resolvers, scan multiple domains and IP addresses, and save results to a file.

## Features

- Query 12 DNS record types: `A`, `AAAA`, `MX`, `NS`, `CNAME`, `TXT`, `SOA`, `PTR`, `SRV`, `CAA`, `DS`, `DNSKEY`.
- Execute DNS queries concurrently for faster scanning.
- Use built-in public DNS servers or custom resolvers.
- Load DNS servers and targets from files.
- Scan multiple domains and IP addresses.
- Export results to a file.
- Detect DNS errors, timeouts, and missing records.

## Requirements

- Bash
- `dig` (`dnsutils`)
- Python 3

## Installation

    sudo apt install dnsutils python3
    chmod +x grabber-dns-recorders.sh

## Usage

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

## File Formats

- `targets.txt` — one domain or IP address per line.
- `dns.txt` — one DNS server IP address or hostname per line.

Blank lines and lines starting with `#` are ignored.

## License

MIT

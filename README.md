# pxsonar

A POSIX-compliant shell script that extracts HTTP/HTTPS URLs from files or directories and checks their accessibility.

## Requirements

- POSIX-compliant shell (sh, bash, dash, etc.)
- Either `curl` or `wget` (curl preferred)
- Standard Unix utilities: `grep`, `find`, `xargs`

## Quick Start

```bash
sh <(curl -L https://raw.githubusercontent.com/iruzo/pxsonar/main/pxsonar.sh) <params> <path>
```

## Usage

```bash
./pxsonar.sh [--summary|-s] [--concurrency|-c N] <file_or_directory>
```

### Options

- `--summary`, `-s`: Show URLs with their source files and summary statistics (no accessibility checking)
- `--concurrency`, `-c N`: Set number of concurrent requests (default: 20)

### Examples

Check URLs in a single file:
```bash
./pxsonar.sh document.txt
```

Check URLs in a directory recursively:
```bash
./pxsonar.sh ./src/
```

Show summary without checking URLs:
```bash
./pxsonar.sh --summary ./docs/
```

Set custom concurrency:
```bash
./pxsonar.sh --concurrency 10 ./src/
./pxsonar.sh -c 50 document.txt
```

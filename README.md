# Nuclei Scanner for Northflank

Production-ready Docker container for running [Nuclei](https://github.com/projectdiscovery/nuclei) security scans with [Notify](https://github.com/projectdiscovery/notify) integration.

## 🚀 Features

- **Nuclei v3**: Latest version installed as binary
- **Notify**: ProjectDiscovery notify for alerting
- **Auto-download templates**: Automatically downloads nuclei-templates if missing
- **Configurable paths**: Environment variable overrides for all paths
- **Structured output**: JSON results saved to file and stdout
- **Severity filtering**: Scans only high and critical findings
- **Production-ready**: Robust error handling and logging

## 📋 Prerequisites

- GitHub account (for repository)
- Northflank account
- Northflank CLI (optional, for file uploads)

## 🛠️ Setup Instructions

### 1. Clone and Prepare Repository

```bash
git clone <your-repo-url>
cd <repo-name>
```

### 2. Configure Provider (Secrets)

Create your `provider.yaml` file based on the template:

```bash
cp provider.template.yaml provider.yaml
# Edit provider.yaml with your actual credentials
```

**Important**: Never commit `provider.yaml` to version control. It's already in `.gitignore`.

### 3. Prepare Targets File

Create your targets file:

```bash
# Create targets file with your subdomains/URLs
cat > targets.txt << EOF
https://example.com
https://test.example.com
https://api.example.com
EOF
```

Or use the example file as a reference:

```bash
cat targets.example.txt
```

### 4. Deploy to Northflank

#### Step 1: Create a Secret File in Northflank

1. Go to your Northflank project
2. Navigate to **Secrets** → **Files**
3. Click **Add Secret File**
4. Name: `provider.yaml`
5. Upload your `provider.yaml` file
6. Note the mount path (usually `/secrets/provider.yaml`)

#### Step 2: Create a Volume for Data

1. Go to **Volumes** in your project
2. Click **Add Volume**
3. Name: `scanner-data`
4. Note the mount path (e.g., `/data`)

#### Step 3: Create a Job

1. Go to **Jobs** → **Add Job**
2. **Source**: Select **Version Control**
3. **Repository**: Connect your GitHub repository
4. **Branch**: `main` (or your default branch)
5. **Dockerfile Path**: `Dockerfile`
6. **Context**: `.` (root directory)

#### Step 4: Configure Job Settings

**Container Settings:**
- **Image**: Auto-built from Dockerfile
- **Command**: Leave empty (uses Dockerfile ENTRYPOINT)

**Environment Variables:**
```
TARGETS_PATH=/data/5subdomains.txt
PROVIDER_PATH=/secrets/provider.yaml
TEMPLATES_PATH=/nuclei-templates
RESULTS_PATH=/data/results.json
```

**Volume Mounts:**
- **Volume**: `scanner-data`
- **Mount Path**: `/data`
- **Read/Write**: Yes

**Secret File Mounts:**
- **Secret File**: `provider.yaml`
- **Mount Path**: `/secrets/provider.yaml`
- **Read Only**: Yes

#### Step 5: Upload Targets File

**Option A: Using Northflank CLI**

```bash
# Install Northflank CLI if not already installed
npm install -g @northflank/cli

# Login to Northflank
northflank login

# Upload targets file to the volume
northflank volumes upload scanner-data 5subdomains.txt < /path/to/your/targets.txt
```

**Option B: Using Northflank Web UI**

1. Go to **Volumes** → `scanner-data`
2. Click **Upload File**
3. Upload your targets file as `5subdomains.txt`

**Option C: Using Docker Exec (if job is running)**

```bash
# Get job container name
northflank jobs exec <job-name> -- sh

# Inside container, create targets file
echo "https://example.com" > /data/5subdomains.txt
echo "https://test.example.com" >> /data/5subdomains.txt
```

### 5. Run the Job

1. Go to your Job in Northflank
2. Click **Run** or **Start**
3. Monitor logs in real-time
4. Results will be saved to `/data/results.json` in the volume

## 🔧 Environment Variables

| Variable | Default | Description |
|-----------|----------|-------------|
| `TARGETS_PATH` | `/data/5subdomains.txt` | Path to targets file |
| `PROVIDER_PATH` | `/secrets/provider.yaml` | Path to notify provider config |
| `TEMPLATES_PATH` | `/nuclei-templates` | Path to nuclei templates directory |
| `RESULTS_PATH` | `/data/results.json` | Path to save scan results |

## 📊 Running a Test Scan

### Single Test Run (One-time Execution)

```bash
# Using Northflank CLI
northflank jobs run <job-name>

# Or trigger via API
curl -X POST \
  https://api.northflank.com/v1/projects/<project-id>/jobs/<job-id>/runs \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### View Results

**Option 1: Download from Volume**

```bash
# Using Northflank CLI
northflank volumes download scanner-data results.json > results.json

# View results
cat results.json | jq .
```

**Option 2: View in Logs**

Results are also printed to stdout, so you can view them in the job logs:

```bash
northflank jobs logs <job-name> --tail
```

**Option 3: Access via Exec**

```bash
northflank jobs exec <job-name> -- cat /data/results.json
```

## 🔄 Scheduled Runs

To run scans on a schedule:

1. Go to your Job in Northflank
2. Navigate to **Schedules**
3. Click **Add Schedule**
4. Configure cron expression (e.g., `0 2 * * *` for daily at 2 AM)
5. Save schedule

## 📝 Example Workflow

```bash
# 1. Prepare targets file locally
cat > my-targets.txt << EOF
https://example.com
https://api.example.com
https://staging.example.com
EOF

# 2. Upload to Northflank volume
northflank volumes upload scanner-data 5subdomains.txt < my-targets.txt

# 3. Run the job
northflank jobs run nuclei-scanner

# 4. Wait for completion and download results
sleep 60  # Wait for scan to complete
northflank volumes download scanner-data results.json > scan-results.json

# 5. Analyze results
cat scan-results.json | jq '.[] | select(.info.severity == "critical")'
```

## 🐳 Local Testing

Test the Docker image locally before deploying:

```bash
# Build the image
docker build -t nuclei-scanner:latest .

# Create directories
mkdir -p ./data ./secrets ./templates

# Copy your files
cp provider.yaml ./secrets/
cp targets.txt ./data/5subdomains.txt

# Run container
docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/secrets:/secrets" \
  -v "$(pwd)/templates:/nuclei-templates" \
  nuclei-scanner:latest

# Check results
cat ./data/results.json | jq .
```

## 🔒 Security Best Practices

1. **Never commit secrets**: `provider.yaml` is in `.gitignore`
2. **Use secret files**: Store `provider.yaml` as a Northflank secret file
3. **Limit permissions**: Mount secrets as read-only
4. **Rotate credentials**: Regularly update API keys and tokens
5. **Monitor access**: Review job execution logs regularly

## 📚 Additional Resources

- [Nuclei Documentation](https://docs.nuclei.sh/)
- [Notify Documentation](https://github.com/projectdiscovery/notify)
- [Northflank Documentation](https://docs.northflank.com/)
- [Nuclei Templates](https://github.com/projectdiscovery/nuclei-templates)

## 🐛 Troubleshooting

### Templates Not Downloading

If templates fail to download:
- Check internet connectivity in the container
- Verify GitHub is accessible
- Check container logs for curl errors

### Provider Config Not Found

- Verify secret file is mounted at `/secrets/provider.yaml`
- Check file permissions (should be readable)
- Verify `PROVIDER_PATH` environment variable matches mount path

### No Results Found

- Verify targets file exists and is not empty
- Check that targets are valid URLs
- Ensure nuclei templates are present
- Review logs for scan errors

### Binary Not Found

- Rebuild Docker image (binaries are compiled during build)
- Verify Dockerfile build stage completed successfully
- Check `/usr/local/bin` contains `nuclei` and `notify`

## 📄 License

This project uses open-source tools:
- Nuclei: [MIT License](https://github.com/projectdiscovery/nuclei/blob/master/LICENSE.md)
- Notify: [MIT License](https://github.com/projectdiscovery/notify/blob/master/LICENSE.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with Docker
5. Submit a pull request

## 📧 Support

For issues related to:
- **Nuclei**: [Nuclei GitHub Issues](https://github.com/projectdiscovery/nuclei/issues)
- **Notify**: [Notify GitHub Issues](https://github.com/projectdiscovery/notify/issues)
- **Northflank**: [Northflank Support](https://docs.northflank.com/)


#!/bin/bash
dnf update -y
dnf install -y httpd awscli

mkdir -p /var/www/html/images
aws s3 cp s3://${bucket_name}/images/ /var/www/html/images/ --recursive

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/instance-id)

HOSTNAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/local-hostname)

AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

IMAGE_FILE=$(ls /var/www/html/images/ 2>/dev/null | head -1)

if [ "${environment}" = "Prod" ]; then
  BADGE_COLOR="#c0392b"
  BANNER_COLOR="#922b21"
elif [ "${environment}" = "Staging" ]; then
  BADGE_COLOR="#d68910"
  BANNER_COLOR="#b7770d"
else
  BADGE_COLOR="#1e8449"
  BANNER_COLOR="#196f3d"
fi

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ACS730 - Group 2 | ${environment}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f0f2f5; min-height: 100vh; }

    .banner {
      background: $BANNER_COLOR;
      color: white;
      padding: 14px 40px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .banner-left { font-size: 15px; font-weight: 600; letter-spacing: 0.5px; }
    .banner-right { font-size: 13px; opacity: 0.85; }

    .main { max-width: 860px; margin: 36px auto; padding: 0 20px; }

    .hero {
      background: white;
      border-radius: 12px;
      padding: 36px 40px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
      margin-bottom: 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 30px;
    }
    .hero-text h1 { font-size: 28px; color: #1a1a2e; font-weight: 700; margin-bottom: 8px; }
    .hero-text p  { font-size: 15px; color: #555; }
    .env-badge {
      display: inline-block;
      background: $BADGE_COLOR;
      color: white;
      padding: 8px 24px;
      border-radius: 30px;
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 1px;
      white-space: nowrap;
    }

    .cards { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 24px; }

    .card {
      background: white;
      border-radius: 12px;
      padding: 24px 28px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }
    .card h3 {
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #888;
      margin-bottom: 16px;
      border-bottom: 2px solid $BADGE_COLOR;
      padding-bottom: 8px;
    }
    .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
    .info-row:last-child { border-bottom: none; }
    .info-label { color: #888; }
    .info-value { color: #222; font-weight: 500; text-align: right; max-width: 60%; word-break: break-all; }

    .member-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .member {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 0;
      font-size: 14px;
      color: #333;
    }
    .avatar {
      width: 32px; height: 32px; border-radius: 50%;
      background: $BADGE_COLOR;
      color: white;
      display: flex; align-items: center; justify-content: center;
      font-size: 13px; font-weight: 700; flex-shrink: 0;
    }

    .image-card {
      background: white;
      border-radius: 12px;
      padding: 24px 28px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
      margin-bottom: 24px;
    }
    .image-card h3 {
      font-size: 12px; font-weight: 600; text-transform: uppercase;
      letter-spacing: 1px; color: #888; margin-bottom: 16px;
      border-bottom: 2px solid $BADGE_COLOR; padding-bottom: 8px;
    }
    .image-card img { width: 100%; max-width: 480px; border-radius: 8px; display: block; }

    .footer {
      text-align: center; font-size: 13px; color: #aaa; padding: 20px 0 36px;
    }
  </style>
</head>
<body>

  <div class="banner">
    <div class="banner-left">ACS730 — Two-Tier Web Application with Terraform</div>
    <div class="banner-right">Seneca College &nbsp;|&nbsp; Winter 2026</div>
  </div>

  <div class="main">

    <div class="hero">
      <div class="hero-text">
        <h1>Welcome to Group 2</h1>
        <p>Automated infrastructure deployed using Terraform on AWS</p>
      </div>
      <div class="env-badge">${environment}</div>
    </div>

    <div class="cards">

      <div class="card">
        <h3>Instance Info</h3>
        <div class="info-row">
          <span class="info-label">Instance ID</span>
          <span class="info-value">$INSTANCE_ID</span>
        </div>
        <div class="info-row">
          <span class="info-label">Hostname</span>
          <span class="info-value">$HOSTNAME</span>
        </div>
        <div class="info-row">
          <span class="info-label">Availability Zone</span>
          <span class="info-value">$AZ</span>
        </div>
        <div class="info-row">
          <span class="info-label">Environment</span>
          <span class="info-value">${environment}</span>
        </div>
      </div>

      <div class="card">
        <h3>Group Members</h3>
        <div class="member-grid">
          <div class="member"><div class="avatar">FR</div>Faizan Sheikh</div>
          <div class="member"><div class="avatar">AP</div>Ayush Patel</div>
          <div class="member"><div class="avatar">NR</div>Nrupad Raval</div>
          <div class="member"><div class="avatar">MH</div>Marjan Haghighi</div>
          <div class="member"><div class="avatar">SM</div>Sharun Manakkara</div>
        </div>
      </div>

    </div>

    <div class="image-card">
      <h3>Image loaded from S3 Bucket</h3>
      $([ -n "$IMAGE_FILE" ] && echo "<img src=\"/images/$IMAGE_FILE\" alt=\"S3 Image\">" || echo "<p style='color:#aaa'>No image found in S3 bucket.</p>")
    </div>

  </div>

  <div class="footer">
    Group 2 &nbsp;&middot;&nbsp; ACS730 &nbsp;&middot;&nbsp; Seneca College &nbsp;&middot;&nbsp; Powered by Terraform + AWS
  </div>

</body>
</html>
EOF

systemctl enable httpd
systemctl start httpd
#!/bin/bash
# auto_pair.sh
# Run this on both Macs to automatically discover each other

MY_IP=$(ipconfig getifaddr en0)
PAIR_PORT=4561

echo "==================================="
echo "Sonic Pi Auto-Pairing"
echo "==================================="
echo "My IP: $MY_IP"
echo "Broadcasting presence and listening..."

# Listen for partner in background
nc -ul $PAIR_PORT | head -1 > /tmp/partner_ip.txt &
LISTEN_PID=$!

# Broadcast our IP
SUBNET=$(echo $MY_IP | cut -d. -f1-3)
for i in {1..10}; do
  echo "$MY_IP" | nc -u -w 1 $SUBNET.255 $PAIR_PORT 2>/dev/null
  sleep 1

  # Check if we found partner
  if [ -s /tmp/partner_ip.txt ]; then
    PARTNER=$(cat /tmp/partner_ip.txt)
    if [ "$PARTNER" != "$MY_IP" ]; then
      echo "✓ Found partner: $PARTNER"
      kill $LISTEN_PID 2>/dev/null

      # Save config for Sonic Pi
      echo "{\"partner_ip\": \"$PARTNER\"}" > /tmp/sonic_pi_network.json
      echo "✓ Config saved to /tmp/sonic_pi_network.json"

      # Test connection
      echo "Testing OSC port 4560..."
      nc -z -w 2 $PARTNER 4560 && echo "✓ Partner's Sonic Pi is reachable" || echo "⚠ Port 4560 not open yet (start Sonic Pi on partner)"

      exit 0
    fi
  fi
done

echo "✗ No partner found after 10 seconds."
echo "Make sure both computers run this script at the same time."
kill $LISTEN_PID 2>/dev/null
exit 1

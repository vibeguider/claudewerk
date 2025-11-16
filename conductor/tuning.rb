# ==============================================
# TUNING - Network Configuration
# ==============================================

# Auto-load from pairing script if available
if File.exist?("/tmp/sonic_pi_network.json")
  config = JSON.parse(File.read("/tmp/sonic_pi_network.json"))
  PARTNER_IP = config["partner_ip"]
  puts "Loaded partner IP from auto_pair: #{PARTNER_IP}"
else
  PARTNER_IP = "127.0.0.1"  # Fallback for local testing
  puts "No auto_pair config found, using localhost"
end

# For backwards compatibility - each computer sees the other as partner
COMPUTER_A_IP = PARTNER_IP
COMPUTER_B_IP = PARTNER_IP

# Port (standard for both)
OSC_PORT = 4560

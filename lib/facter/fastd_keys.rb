Dir.glob(["/etc/fastd/*/fastd.conf"]).each do |glob|
  # Extract tunnel name and fetch public key.
  tunnel = glob.split("/")[3]
  pubkey = Facter::Util::Resolution.exec("fastd --show-key --machine-readable --config #{glob}").lines.to_a.first.strip

  # Attach the key.
  Facter.add("fastd_#{tunnel}_pubkey") do
    setcode do
      pubkey
    end
  end
end

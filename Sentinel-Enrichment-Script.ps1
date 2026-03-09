# API Key and Log File configuration
$apiKey = "PLACEHOLDER_REDACTED_FOR_SECURITY"  # Get your own key at https://ipgeolocation.io
$logFile = "C:\failed_rdp_geo.log"

# Infinite loop to monitor for failed RDP login attempts
while ($true) {
    Start-Sleep -Seconds 30
    
    # Query the Security Event Log for Event ID 4625 (Failed Logon) from the last 5 minutes
    $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 100 -ErrorAction SilentlyContinue | 
              Where-Object {$_.TimeCreated -gt (Get-Date).AddMinutes(-5)}

    foreach ($event in $events) {
        $ip = $event.Properties[19].Value  # Extracting the Source IP address field
        
        # Filter out local loopback addresses
        if ($ip -and $ip -notmatch '127.0.0.1|::1') {
            $url = "https://api.ipgeolocation.io/ipgeo?apiKey=$apiKey&ip=$ip"
            
            try {
                # Query Geolocation API for attacker origin details
                $geo = Invoke-RestMethod -Uri $url
                
                # Format entry for Sentinel ingestion: Time|IP|Country|Latitude|Longitude
                $entry = "$($event.TimeCreated)|$ip|$($geo.country_name)|$($geo.latitude)|$($geo.longitude)"
                
                # Append data to the local log file for the Azure Monitor Agent to collect
                Add-Content -Path $logFile -Value $entry
                Write-Host "Captured Failed Login from $ip ($($geo.country_name))" -ForegroundColor Yellow
            } catch {
                Write-Host "API Error or Rate Limit reached." -ForegroundColor Red
            }
        }
    }
}

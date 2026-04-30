# Tekijä: Jesse Karnavaara
# Vuosi: 2026
# Tarkoitus: HashiCorp Vault -palvelimen pääkonfiguraatio. Määrittelee 
#            tallennustilan, verkkoliikenteen kuuntelijan ja turvallisuusasetukset.
#            Toimii yhdessä NGINX-välityspalvelimen ja CIS-kovennetun isäntäkoneen kanssa.
#
# Huomiot konfiguraatiosta ja arkkitehtuurista:
# - Tallennustila (Storage): Käyttää Vaultin sisäänrakennettua tiedostotallennusta 
#   (file). Polku on ohjattu "/data" -hakemistoon, joka mapataan Dockerissa 
#   pysyvään volyymiin.
# - TLS Terminointi: "tls_disable = 1", koska tämä Vault-instanssi elää suojatussa 
#   Docker-sisäverkossa. NGINX hoitaa ulkoisen liikenteen TLS-terminoinnin (Tailscale).
# - IP-osoitteiden luottamus: "x_forwarded_for_authorized_addrs" sallii Vaultin 
#   lukea todellisen asiakas-IP:n NGINX-kontin (172.16.0.0/27) välittämistä 
#   HTTP-otsakkeista. Tämä on kriittistä tarkan audit-lokituksen kannalta.
# - Muistin lukitus: "disable_mlock = 'true'" on sallittu, koska isäntäkoneen 
#   swap-osio on poistettu (CIS Level 1 -kovennus).
#

"storage" "file" {
  # HUOM! Tämän pitää täsmätä docker-compose.yml:n volyymimääritykseen (/data)
  "path" = "/data"
}

"listener" "tcp" {
  "address" = "0.0.0.0:8200"
  "cluster_address" = "127.0.0.1:8201"
  "tls_disable" = 1
  
  # Luotetaan NGINX-välityspalvelimen (Reverse Proxy) IP-avaruuteen, 
  # jotta saadaan kiinni todelliset Client IP -osoitteet audit-lokeihin.
  "x_forwarded_for_authorized_addrs" = "172.16.0.0/27" 
}

"ui" = true
"log_level" = "Debug"

# Poistetaan mlock käytöstä, koska isäntäkoneella ei ole swappia CIS Level 1 -kovennusten ansiosta.
"disable_mlock" = "true"

# Avainten elinkaariasetukset (Lease Time-To-Live)
"default_lease_ttl" = "7d"
"max_lease_ttl" = "14d"

# Tämä asetus kertoo muille palveluille (ja clienteille), mistä Vault löytyy
"api_addr" = "http://127.0.0.1:8200"